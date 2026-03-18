//
//  ImageDownloaderIntegrationTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/18/26.
//

import Testing
import UIKit
@testable import KakaoImageSearch

// MARK: - ImageDownloader 전용 URLProtocol Stub
// NetworkServiceIntegrationTests의 MockURLProtocol과 static handler를 공유하지 않기 위해 분리

final class MockImageURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockImageURLProtocol.requestHandler else {
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
@Suite("ImageDownloader 통합 테스트", .serialized)
struct ImageDownloaderIntegrationTests {

    init() {
        // 각 테스트 전 디스크 캐시 초기화 — 테스트 간 캐시 오염 방지
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let cacheDir = caches.appendingPathComponent("ImageCache")
        try? FileManager.default.removeItem(at: cacheDir)
    }

    // MARK: - Helpers

    private func makeDownloader() -> ImageDownloader {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockImageURLProtocol.self]
        return ImageDownloader(session: URLSession(configuration: config))
    }

    private func makePNGData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).pngData { _ in }
    }

    private let imageURL = URL(string: "https://example.com/image.png")!

    // MARK: - 성공

    @Test("200 응답과 유효한 이미지 데이터는 UIImage를 반환한다")
    func download_200_validImage_returnsUIImage() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, png)
        }

        let image = try await sut.download(from: imageURL)

        #expect(image.size.width > 0)
    }

    // MARK: - 오류

    @Test("200이지만 이미지로 변환 불가한 데이터는 invalidData를 던진다")
    func download_200_invalidImageData_throwsInvalidData() async throws {
        let sut = makeDownloader()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("not an image".utf8))
        }

        await #expect(throws: ImageDownloadError.invalidData) {
            _ = try await sut.download(from: imageURL)
        }
    }

    @Test("4xx 응답은 invalidResponse를 던진다")
    func download_4xx_throwsInvalidResponse() async throws {
        let sut = makeDownloader()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        await #expect(throws: ImageDownloadError.invalidResponse) {
            _ = try await sut.download(from: imageURL)
        }
    }

    @Test("5xx 응답은 invalidResponse를 던진다")
    func download_5xx_throwsInvalidResponse() async throws {
        let sut = makeDownloader()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }

        await #expect(throws: ImageDownloadError.invalidResponse) {
            _ = try await sut.download(from: imageURL)
        }
    }

    // MARK: - 캐시

    @Test("같은 URL 두 번째 요청은 캐시에서 반환되어 URLSession을 호출하지 않는다")
    func download_secondRequest_returnsCachedImage() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        defer { MockImageURLProtocol.requestHandler = nil }

        var requestCount = 0
        MockImageURLProtocol.requestHandler = { req in
            requestCount += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, png)
        }

        _ = try await sut.download(from: imageURL)
        _ = try await sut.download(from: imageURL)

        #expect(requestCount == 1)
    }

    // MARK: - prefetch 실패

    @Test("prefetch 중 일부 URL 실패해도 성공한 URL은 캐시에 저장된다")
    func prefetch_partialFailure_cachesSuccessfulDownloads() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        let successURL = URL(string: "https://example.com/success.png")!
        let failURL = URL(string: "https://example.com/fail.png")!
        defer { MockImageURLProtocol.requestHandler = nil }

        MockImageURLProtocol.requestHandler = { req in
            if req.url == successURL {
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, png)
            } else {
                return (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        await sut.prefetch(urls: [successURL, failURL])

        // 성공한 URL은 캐시에 저장되어 두 번째 다운로드 시 URLSession을 호출하지 않는다
        var requestCount = 0
        MockImageURLProtocol.requestHandler = { req in
            requestCount += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, png)
        }
        _ = try await sut.download(from: successURL)

        #expect(requestCount == 0)
    }

    // MARK: - in-flight dedup

    @Test("동일 URL 동시 요청은 URLSession을 한 번만 호출한다 (in-flight dedup)")
    func download_concurrentSameURL_deduplicatesNetworkRequest() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        defer { MockImageURLProtocol.requestHandler = nil }

        var requestCount = 0
        MockImageURLProtocol.requestHandler = { req in
            requestCount += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, png)
        }

        async let image1 = sut.download(from: imageURL)
        async let image2 = sut.download(from: imageURL)

        let (result1, result2) = try await (image1, image2)

        #expect(requestCount == 1)
        #expect(result1.size.width > 0)
        #expect(result2.size.width > 0)
    }

    // MARK: - http → https 변환

    @Test("http URL은 https로 변환되어 요청된다")
    func download_httpURL_isUpgradedToHTTPS() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        defer { MockImageURLProtocol.requestHandler = nil }

        var capturedURL: URL?
        MockImageURLProtocol.requestHandler = { req in
            capturedURL = req.url
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, png)
        }

        let httpURL = URL(string: "http://example.com/image.png")!
        _ = try await sut.download(from: httpURL)

        #expect(capturedURL?.scheme == "https")
    }
}
