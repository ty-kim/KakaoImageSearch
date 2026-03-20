//
//  CachedAsyncImageViewModelTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/19/26.
//

import Testing
import UIKit
@testable import KakaoImageSearch

// MARK: - 테스트용 Phase 비교 헬퍼

extension CachedAsyncImageViewModel.Phase {
    /// success는 이미지 데이터가 아닌 case만 비교합니다.
    var label: String {
        switch self {
        case .idle:              return "idle"
        case .loading:           return "loading"
        case .success:           return "success"
        case .failure:           return "failure"
        case .permanentFailure:  return "permanentFailure"
        }
    }
}

@MainActor
@Suite("CachedAsyncImageViewModel")
struct CachedAsyncImageViewModelTests {

    private let testURL = URL(string: "https://example.com/image.jpg")!

    private func makeViewModel(downloader: MockImageDownloader = MockImageDownloader()) -> CachedAsyncImageViewModel {
        CachedAsyncImageViewModel(downloader: downloader)
    }

    // MARK: - Phase 상태 전이

    @Test("URL nil이면 idle 상태 유지")
    func loadNilURL() async {
        let vm = makeViewModel()
        await vm.load(url: nil)
        #expect(vm.phase.label == "idle")
    }

    @Test("다운로드 성공 시 success 상태")
    func loadSuccess() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .success(UIImage())
        let vm = makeViewModel(downloader: mock)

        await vm.load(url: testURL)
        #expect(vm.phase.label == "success")
    }

    @Test("재시도 불가 에러(notImageContentType) 시 즉시 permanentFailure")
    func nonRetryableError_contentType() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .failure(ImageDownloadError.notImageContentType)
        let vm = makeViewModel(downloader: mock)

        await vm.load(url: testURL)
        #expect(vm.phase.label == "permanentFailure")
        #expect(vm.retryCount == 0)
    }

    @Test("재시도 불가 에러(contentLengthExceeded) 시 즉시 permanentFailure")
    func nonRetryableError_contentLength() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .failure(ImageDownloadError.contentLengthExceeded)
        let vm = makeViewModel(downloader: mock)

        await vm.load(url: testURL)
        #expect(vm.phase.label == "permanentFailure")
    }

    @Test("재시도 가능 에러 시 failure 상태, retryCount 증가")
    func retryableError() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .failure(ImageDownloadError.invalidResponse)
        let vm = makeViewModel(downloader: mock)

        await vm.load(url: testURL)
        #expect(vm.phase.label == "failure")
        #expect(vm.retryCount == 1)
    }

    @Test("재시도 가능 에러 3회 초과 시 permanentFailure")
    func retryExhausted() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .failure(ImageDownloadError.invalidResponse)
        let vm = makeViewModel(downloader: mock)

        for _ in 0...CachedAsyncImageViewModel.maxRetryCount {
            await vm.load(url: testURL)
        }
        #expect(vm.phase.label == "permanentFailure")
        #expect(vm.retryCount == CachedAsyncImageViewModel.maxRetryCount + 1)
    }

    @Test("resetRetry 호출 시 retryCount 초기화")
    func resetRetry() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .failure(ImageDownloadError.invalidResponse)
        let vm = makeViewModel(downloader: mock)

        await vm.load(url: testURL)
        #expect(vm.retryCount == 1)

        vm.resetRetry()
        #expect(vm.retryCount == 0)
    }
}
