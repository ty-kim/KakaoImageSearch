//
//  SearchPrefetchCoordinatorTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/31/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

@MainActor
@Suite("SearchPrefetchCoordinator")
struct SearchPrefetchCoordinatorTests {

    private func makeSUT() -> (sut: SearchPrefetchCoordinator, prefetcher: MockImagePrefetcher, networkMonitor: MockNetworkMonitor) {
        let prefetcher = MockImagePrefetcher()
        let networkMonitor = MockNetworkMonitor()
        let sut = SearchPrefetchCoordinator(imagePrefetcher: prefetcher, networkMonitor: networkMonitor)
        return (sut, prefetcher, networkMonitor)
    }

    // MARK: - start

    @Test("start — 정상 네트워크에서 프리패치 실행")
    func start_normalNetwork_prefetches() async throws {
        let (sut, prefetcher, _) = makeSUT()
        let items = [ImageItem.fixture(id: "1"), ImageItem.fixture(id: "2")]

        sut.start(with: items)

        // 프리패치 완료 대기
        for await _ in prefetcher.prefetchCalled { break }

        #expect(prefetcher.prefetchCallCount == 1)
        #expect(prefetcher.prefetchedURLs.count == 2)
    }

    @Test("start — expensive 네트워크에서 프리패치 안 함")
    func start_expensiveNetwork_skips() async throws {
        let (sut, prefetcher, networkMonitor) = makeSUT()
        networkMonitor.isExpensive = true
        let items = [ImageItem.fixture(id: "1")]

        sut.start(with: items)

        // 약간 대기 후 확인
        try await Task.sleep(for: .milliseconds(100))

        #expect(prefetcher.prefetchCallCount == 0)
    }

    @Test("start — displayURL이 nil인 아이템은 제외")
    func start_nilURL_excluded() async throws {
        let (sut, prefetcher, _) = makeSUT()
        let items = [
            ImageItem.fixture(id: "1", imageURL: nil, thumbnailURL: nil),
            ImageItem.fixture(id: "2")
        ]

        sut.start(with: items)

        for await _ in prefetcher.prefetchCalled { break }

        #expect(prefetcher.prefetchedURLs.count == 1)
    }

    @Test("start — 두 번 호출 시 이전 Task 취소")
    func start_twice_cancelsPrevious() async throws {
        let (sut, prefetcher, _) = makeSUT()

        sut.start(with: [ImageItem.fixture(id: "1")])
        sut.start(with: [ImageItem.fixture(id: "2")])

        // 마지막 호출 완료 대기
        for await _ in prefetcher.prefetchCalled { break }

        // 두 번째 호출의 URL이 포함되어야 함
        #expect(prefetcher.prefetchedURLs.contains(URL(string: "https://example.com/image.jpg")!))
    }

    // MARK: - cancel

    @Test("cancel — Task 취소")
    func cancel_stopsTask() async throws {
        let blockingPrefetcher = BlockingMockImagePrefetcher()
        let networkMonitor = MockNetworkMonitor()
        let sut = SearchPrefetchCoordinator(imagePrefetcher: blockingPrefetcher, networkMonitor: networkMonitor)

        sut.start(with: [ImageItem.fixture(id: "1")])

        // 시작 대기
        for await _ in blockingPrefetcher.started { break }

        sut.cancel()

        // 취소 전파 확인
        for await _ in blockingPrefetcher.cancelled { break }

        // 여기 도달하면 취소 성공
    }
}
