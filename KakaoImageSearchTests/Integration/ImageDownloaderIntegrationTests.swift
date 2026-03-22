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

    private let imageHeaders = ["Content-Type": "image/png"]

    // MARK: - 성공

    @Test("200 응답과 유효한 이미지 데이터는 UIImage를 반환한다")
    func download_200_validImage_returnsUIImage() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
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
            let response = HTTPURLResponse(
                url: req.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "image/png"])!
            return (response, Data("not an image".utf8))
        }

        await #expect(throws: ImageDownloadError.invalidData) {
            _ = try await sut.download(from: imageURL)
        }
    }

    @Test("404 응답은 notFound를 던진다")
    func download_404_throwsNotFound() async throws {
        let sut = makeDownloader()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        await #expect(throws: ImageDownloadError.notFound) {
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
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
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
                return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
            } else {
                return (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        await sut.prefetch(urls: [successURL, failURL])

        // 성공한 URL은 캐시에 저장되어 두 번째 다운로드 시 URLSession을 호출하지 않는다
        var requestCount = 0
        MockImageURLProtocol.requestHandler = { req in
            requestCount += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
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
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
        }

        async let image1 = sut.download(from: imageURL)
        async let image2 = sut.download(from: imageURL)

        let (result1, result2) = try await (image1, image2)

        #expect(requestCount == 1)
        #expect(result1.size.width > 0)
        #expect(result2.size.width > 0)
    }

    // MARK: - prefetch 병렬도 제한

    @Test("prefetch 동시 요청 수가 maxConcurrentPrefetches를 초과하지 않는다")
    func prefetch_concurrencyIsLimited() async {
        let sut = makeDownloader()
        let png = makePNGData()
        let totalURLs = 20
        let urls = (0..<totalURLs).map { URL(string: "https://example.com/img\($0).png")! }

        let counter = MaxConcurrencyCounter()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            counter.increment()
            // 약간의 지연으로 동시성 측정
            Thread.sleep(forTimeInterval: 0.05)
            counter.decrement()
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
        }

        await sut.prefetch(urls: urls)

        #expect(counter.maxConcurrent <= 6)
    }

    @Test("prefetch 중 일부 실패해도 나머지는 계속 처리된다")
    func prefetch_partialFailure_doesNotBlockOthers() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        let urls = (0..<10).map { URL(string: "https://example.com/img\($0).png")! }
        defer { MockImageURLProtocol.requestHandler = nil }

        var downloadedCount = 0
        MockImageURLProtocol.requestHandler = { req in
            // 짝수 인덱스만 실패
            let index = Int(req.url!.lastPathComponent.replacingOccurrences(of: "img", with: "").replacingOccurrences(of: ".png", with: ""))!
            if index % 2 == 0 {
                return (HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
            downloadedCount += 1
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
        }

        await sut.prefetch(urls: urls)

        #expect(downloadedCount == 5) // 홀수 5개 성공
    }

    // MARK: - Content-Type 검증

    @Test("200 OK인데 Content-Type이 text/html이면 notImageContentType을 던진다")
    func download_200_textHtml_throwsNotImageContentType() async throws {
        let sut = makeDownloader()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            let response = HTTPURLResponse(
                url: req.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "text/html"])!
            return (response, Data("<html></html>".utf8))
        }

        await #expect(throws: ImageDownloadError.notImageContentType) {
            _ = try await sut.download(from: imageURL)
        }
    }

    @Test("Content-Type이 image/jpeg이면 정상 다운로드된다")
    func download_200_imageJpeg_succeeds() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            let response = HTTPURLResponse(
                url: req.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "image/jpeg"])!
            return (response, png)
        }

        let image = try await sut.download(from: imageURL)
        #expect(image.size.width > 0)
    }

    @Test("Content-Type이 application/octet-stream이면 notImageContentType을 던진다")
    func download_200_octetStream_throwsNotImageContentType() async throws {
        let sut = makeDownloader()
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            let response = HTTPURLResponse(
                url: req.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/octet-stream"])!
            return (response, Data("binary blob".utf8))
        }

        await #expect(throws: ImageDownloadError.notImageContentType) {
            _ = try await sut.download(from: imageURL)
        }
    }

    // MARK: - Content-Length 제한

    @Test("Content-Length 헤더가 상한 초과이면 본문 수신 전에 contentLengthExceeded를 던진다")
    func download_contentLengthHeader_exceeds_throwsEarly() async throws {
        let sut = makeDownloader()
        let smallData = Data("tiny".utf8)
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            let response = HTTPURLResponse(
                url: req.url!, statusCode: 200, httpVersion: nil,
                headerFields: [
                    "Content-Type": "image/png",
                    "Content-Length": "99999999"
                ])!
            return (response, smallData)
        }

        await #expect(throws: ImageDownloadError.contentLengthExceeded) {
            _ = try await sut.download(from: imageURL)
        }
    }

    @Test("Content-Length 헤더 없이 실제 데이터가 상한을 초과하면 스트리밍 중 contentLengthExceeded를 던진다")
    func download_oversizedData_throwsContentLengthExceeded() async throws {
        let sut = makeDownloader()
        let oversizedData = Data(repeating: 0xFF, count: Int(ImageDownloader.maxContentLength) + 1)
        defer { MockImageURLProtocol.requestHandler = nil }
        MockImageURLProtocol.requestHandler = { req in
            let response = HTTPURLResponse(
                url: req.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "image/png"])!
            return (response, oversizedData)
        }

        await #expect(throws: ImageDownloadError.contentLengthExceeded) {
            _ = try await sut.download(from: imageURL)
        }
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
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
        }

        let httpURL = URL(string: "http://example.com/image.png")!
        _ = try await sut.download(from: httpURL)

        #expect(capturedURL?.scheme == "https")
    }
    // MARK: - in-flight dedup 취소 내성

    @Test("첫 호출자가 취소돼도 동일 URL 재요청 시 in-flight task를 재사용한다")
    func download_firstCallerCancelled_secondCallerReusesInFlight() async throws {
        let sut = makeDownloader()
        let png = makePNGData()
        defer { MockImageURLProtocol.requestHandler = nil }

        var networkCallCount = 0

        MockImageURLProtocol.requestHandler = { req in
            networkCallCount += 1
            // 응답 지연 — 취소 타이밍을 만들기 위해
            Thread.sleep(forTimeInterval: 0.15)
            return (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: self.imageHeaders)!, png)
        }

        // 1. 첫 번째 호출 시작 후 취소
        let firstTask = Task {
            try await sut.download(from: imageURL)
        }
        try await Task.sleep(for: .milliseconds(50))
        firstTask.cancel()

        // 2. 첫 번째 task가 아직 진행 중일 때 동일 URL 재요청
        let image = try await sut.download(from: imageURL)

        #expect(image.size.width > 0)
        #expect(networkCallCount == 1) // 네트워크 호출은 1회만
    }
}

// MARK: - 동시성 측정 헬퍼

private final class MaxConcurrencyCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0
    private(set) var maxConcurrent = 0

    func increment() {
        lock.lock()
        current += 1
        if current > maxConcurrent { maxConcurrent = current }
        lock.unlock()
    }

    func decrement() {
        lock.lock()
        current -= 1
        lock.unlock()
    }
}
