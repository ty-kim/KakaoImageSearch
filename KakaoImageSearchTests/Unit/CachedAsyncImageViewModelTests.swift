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
        CachedAsyncImageViewModel(downloader: downloader, analyzer: ImageAnalyzer(), backoffBase: 0)
    }

    // MARK: - Phase Equatable

    @Test("같은 case끼리 동등하다 (idle, loading, failure, permanentFailure)")
    func phaseEquatable_sameCases() {
        #expect(CachedAsyncImageViewModel.Phase.idle == .idle)
        #expect(CachedAsyncImageViewModel.Phase.loading == .loading)
        #expect(CachedAsyncImageViewModel.Phase.failure == .failure)
        #expect(CachedAsyncImageViewModel.Phase.permanentFailure == .permanentFailure)
    }

    @Test("같은 UIImage 인스턴스의 success는 동등하다")
    func phaseEquatable_sameImageInstance() {
        let image = UIImage()
        #expect(CachedAsyncImageViewModel.Phase.success(image) == .success(image))
    }

    @Test("다른 UIImage 인스턴스의 success는 동등하지 않다")
    func phaseEquatable_differentImageInstances() {
        let imageA = UIImage()
        let imageB = UIImage()
        #expect(CachedAsyncImageViewModel.Phase.success(imageA) != .success(imageB))
    }

    @Test("다른 case끼리는 동등하지 않다")
    func phaseEquatable_differentCases() {
        #expect(CachedAsyncImageViewModel.Phase.idle != .loading)
        #expect(CachedAsyncImageViewModel.Phase.failure != .permanentFailure)
        #expect(CachedAsyncImageViewModel.Phase.idle != .success(UIImage()))
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

    // MARK: - Exponential Backoff

    @Test("재시도 시 backoff 대기 후 failure 상태가 된다")
    func retryableError_backsOffBeforeFailure() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .failure(ImageDownloadError.invalidResponse)
        let vm = CachedAsyncImageViewModel(downloader: mock, analyzer: ImageAnalyzer(), backoffBase: 0)

        await vm.load(url: testURL)
        #expect(vm.phase.label == "failure")
        #expect(vm.retryCount == 1)
    }

    @Test("backoff 대기 중 Task 취소 시 idle로 복귀한다")
    func retryableError_cancelDuringBackoff_becomesIdle() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .failure(ImageDownloadError.invalidResponse)
        // backoffBase를 크게 설정해서 sleep 중 취소를 보장
        let vm = CachedAsyncImageViewModel(downloader: mock, analyzer: ImageAnalyzer(), backoffBase: 100)

        let task = Task {
            await vm.load(url: testURL)
        }
        // 다운로드 실패 후 sleep에 진입할 시간을 줌
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        #expect(vm.phase.label == "idle")
    }

    @Test("maxRetryCount 초과 시 대기 없이 즉시 permanentFailure")
    func retryExhausted_noBackoff_permanentFailure() async {
        let mock = MockImageDownloader()
        mock.stubbedResult = .failure(ImageDownloadError.invalidResponse)
        let vm = CachedAsyncImageViewModel(downloader: mock, analyzer: ImageAnalyzer(), backoffBase: 0)

        for _ in 0...CachedAsyncImageViewModel.maxRetryCount {
            await vm.load(url: testURL)
        }
        #expect(vm.phase.label == "permanentFailure")
    }

    // MARK: - 낡은 결과 덮어쓰기 방지

    @Test("URL 변경으로 취소된 이전 다운로드가 늦게 끝나도 새 이미지를 덮지 않는다")
    func lateCancelledDownloadDoesNotOverwrite() async {
        let urlA = URL(string: "https://example.com/a.jpg")!
        let urlB = URL(string: "https://example.com/b.jpg")!
        let imageA = UIImage()
        let imageB = UIImage()

        let downloader = GatedImageDownloader()
        let viewModel = CachedAsyncImageViewModel(downloader: downloader, analyzer: ImageAnalyzer(), backoffBase: 0)
        var starts = downloader.started.makeAsyncIterator()

        // A 로드 시작 (SwiftUI .task 에 해당)
        let taskA = Task { await viewModel.load(url: urlA) }
        _ = await starts.next()

        // URL 이 B 로 바뀌며 바깥 task 취소 → 같은 ViewModel 에 B 로드
        taskA.cancel()
        let taskB = Task { await viewModel.load(url: urlB) }
        _ = await starts.next()

        downloader.complete(urlB, with: imageB)
        await taskB.value
        #expect(viewModel.phase == .success(imageB))

        // A 가 뒤늦게 완료 — 취소됐으므로 반영되면 안 된다
        downloader.complete(urlA, with: imageA)
        await taskA.value
        #expect(viewModel.phase == .success(imageB))
    }

    @Test("취소 없이 URL 이 바뀐 경우에도 늦게 끝난 이전 다운로드는 반영되지 않는다")
    func lateDownloadOfPreviousURLIsIgnored() async {
        let urlA = URL(string: "https://example.com/a.jpg")!
        let urlB = URL(string: "https://example.com/b.jpg")!
        let imageA = UIImage()
        let imageB = UIImage()

        let downloader = GatedImageDownloader()
        let viewModel = CachedAsyncImageViewModel(downloader: downloader, analyzer: ImageAnalyzer(), backoffBase: 0)
        var starts = downloader.started.makeAsyncIterator()

        let taskA = Task { await viewModel.load(url: urlA) }
        _ = await starts.next()

        let taskB = Task { await viewModel.load(url: urlB) }
        _ = await starts.next()

        downloader.complete(urlB, with: imageB)
        await taskB.value
        #expect(viewModel.phase == .success(imageB))

        downloader.complete(urlA, with: imageA)
        await taskA.value
        #expect(viewModel.phase == .success(imageB))
    }
}
