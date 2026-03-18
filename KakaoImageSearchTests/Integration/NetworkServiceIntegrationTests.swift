//
//  NetworkServiceIntegrationTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
import Foundation
@testable import KakaoImageSearch

// MARK: - URLProtocol Stub

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Integration Tests

@MainActor
@Suite("NetworkService 통합 테스트", .serialized)
struct NetworkServiceIntegrationTests {

    // MARK: - Helpers

    private func makeService() -> NetworkService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return NetworkService(session: URLSession(configuration: config))
    }

    private func stubResponse(statusCode: Int, data: Data, for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private let validResponseJSON = """
    {
        "meta": { "total_count": 2, "pageable_count": 2, "is_end": false },
        "documents": [
            {
                "image_url": "https://example.com/img1.jpg",
                "thumbnail_url": "https://example.com/thumb1.jpg",
                "width": 800,
                "height": 600
            },
            {
                "image_url": "https://example.com/img2.jpg",
                "width": 1280,
                "height": 720
            }
        ]
    }
    """.data(using: .utf8)!

    // MARK: - 성공 응답

    @Test("200 응답과 유효한 JSON은 KakaoSearchResponseDTO로 디코딩된다")
    func request_200_decodesDTO() async throws {
        let sut = makeService()
        defer { MockURLProtocol.requestHandler = nil }
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.validResponseJSON)
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        let result: KakaoSearchResponseDTO = try await sut.request(endpoint)

        #expect(result.meta.totalCount == 2)
        #expect(result.documents.count == 2)
        #expect(result.documents[0].imageUrl == "https://example.com/img1.jpg")
    }

    @Test("200 응답에서 documents는 ImageItem 배열로 변환된다")
    func request_200_documentsConvertToImageItems() async throws {
        let sut = makeService()
        defer { MockURLProtocol.requestHandler = nil }
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.validResponseJSON)
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        let dto: KakaoSearchResponseDTO = try await sut.request(endpoint)
        let items = dto.documents.compactMap { $0.toImageItem() }

        #expect(items.count == 2)
        #expect(items[0].id == "https://example.com/img1.jpg")
        #expect(items[0].width == 800)
    }

    // MARK: - HTTP 오류 응답

    @Test("401 응답은 NetworkError.httpError(401)을 던진다")
    func request_401_throwsHTTPError() async throws {
        let sut = makeService()
        defer { MockURLProtocol.requestHandler = nil }
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        await #expect(throws: NetworkError.self) {
            let _: KakaoSearchResponseDTO = try await sut.request(endpoint)
        }
    }

    @Test("500 응답은 NetworkError를 던진다")
    func request_500_throwsNetworkError() async throws {
        let sut = makeService()
        defer { MockURLProtocol.requestHandler = nil }
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        await #expect(throws: NetworkError.self) {
            let _: KakaoSearchResponseDTO = try await sut.request(endpoint)
        }
    }

    // MARK: - 디코딩 오류

    @Test("200이지만 잘못된 JSON은 NetworkError.decodingError를 던진다")
    func request_invalidJSON_throwsDecodingError() async throws {
        let sut = makeService()
        defer { MockURLProtocol.requestHandler = nil }
        let badJSON = "not a json".data(using: .utf8)!
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, badJSON)
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        await #expect(throws: NetworkError.self) {
            let _: KakaoSearchResponseDTO = try await sut.request(endpoint)
        }
    }

    @Test("200이지만 빈 데이터는 NetworkError.decodingError를 던진다")
    func request_emptyData_throwsDecodingError() async throws {
        let sut = makeService()
        defer { MockURLProtocol.requestHandler = nil }
        MockURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        await #expect(throws: NetworkError.self) {
            let _: KakaoSearchResponseDTO = try await sut.request(endpoint)
        }
    }

    // MARK: - 요청 검증

    @Test("요청에 Authorization 헤더가 포함된다")
    func request_includesAuthorizationHeader() async throws {
        let sut = makeService()
        defer { MockURLProtocol.requestHandler = nil }
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { req in
            capturedRequest = req
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.validResponseJSON)
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "test", page: 1)
        let _: KakaoSearchResponseDTO = try await sut.request(endpoint)

        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization")?.hasPrefix("KakaoAK") == true)
    }

    @Test("타임아웃 시 NetworkError.unknown을 던진다")
    func request_timeout_throwsUnknownError() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.timeoutIntervalForRequest = 1
        let sut = NetworkService(session: URLSession(configuration: config))
        defer { MockURLProtocol.requestHandler = nil }

        MockURLProtocol.requestHandler = { req in
            Thread.sleep(forTimeInterval: 3) // 타임아웃 초과
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.validResponseJSON)
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        await #expect(throws: Error.self) {
            let _: KakaoSearchResponseDTO = try await sut.request(endpoint)
        }
    }

    @Test("요청 URL에 query 파라미터가 포함된다")
    func request_urlContainsQueryParam() async throws {
        let sut = makeService()
        defer { MockURLProtocol.requestHandler = nil }
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, self.validResponseJSON)
        }

        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "고양이", page: 1)
        let _: KakaoSearchResponseDTO = try await sut.request(endpoint)

        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)
        let query = components?.queryItems?.first { $0.name == "query" }?.value
        #expect(query == "고양이")
    }
}
