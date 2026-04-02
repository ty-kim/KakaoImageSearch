//
//  BookmarkViewModelTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 4/2/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

// MARK: - BookmarkViewModel

@MainActor
@Suite("BookmarkViewModel")
struct BookmarkViewModelTests {

    private func makeSUT(
        initialItems: [ImageItem] = [],
        fetchError: Error? = nil
    ) -> (sut: BookmarkViewModel, repo: MockBookmarkRepository) {
        let repo = MockBookmarkRepository()
        repo.items = initialItems
        repo.stubbedFetchError = fetchError
        let sut = BookmarkViewModel(
            bookmarkStore: BookmarkCoordinator(
                manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: repo)
            ),
            toastDuration: .zero
        )
        return (sut, repo)
    }

    @Test("loadBookmarks 성공 시 items 설정, loaded 상태")
    func loadBookmarks_success_setsItems() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _) = makeSUT(initialItems: items)

        await sut.loadBookmarks()

        #expect(sut.items.count == 2)
        guard case .loaded = sut.bookmarkState else {
            Issue.record("Expected .loaded state")
            return
        }
    }

    @Test("loadBookmarks 실패 시 error 상태")
    func loadBookmarks_failure_setsErrorState() async throws {
        let (sut, repo) = makeSUT()
        repo.stubbedFetchError = TestError.stub

        await sut.loadBookmarks()

        guard case .error = sut.bookmarkState else {
            Issue.record("Expected .error state")
            return
        }
    }

    @Test("loadBookmarks 재시도 성공 시 loaded 상태로 복구")
    func loadBookmarks_retrySuccess_clearsError() async throws {
        let items = [ImageItem.fixture(id: "a")]
        let (sut, repo) = makeSUT(initialItems: items)
        repo.stubbedFetchError = TestError.stub

        await sut.loadBookmarks()
        guard case .error = sut.bookmarkState else {
            Issue.record("Expected .error state")
            return
        }

        repo.stubbedFetchError = nil
        await sut.loadBookmarks()

        guard case .loaded = sut.bookmarkState else {
            Issue.record("Expected .loaded state")
            return
        }
        #expect(sut.items.count == 1)
    }

    @Test("toggleBookmark 실패 시 toastMessage 설정")
    func toggleBookmark_failure_setsToastMessage() async throws {
        let item = ImageItem.fixture(id: "a", isBookmarked: true)
        let (sut, repo) = makeSUT(initialItems: [item])
        await sut.loadBookmarks()
        repo.stubbedDeleteError = TestError.stub

        await sut.toggleBookmark(for: item)

        #expect(sut.toastMessage != nil)
    }

    @Test("toggleBookmark 호출 시 해당 아이템 제거 후 목록 갱신")
    func toggleBookmark_removesItemAndReloads() async throws {
        let itemA = ImageItem.fixture(id: "a", isBookmarked: true)
        let itemB = ImageItem.fixture(id: "b", isBookmarked: true)
        let (sut, _) = makeSUT(initialItems: [itemA, itemB])
        await sut.loadBookmarks()

        await sut.toggleBookmark(for: itemA)

        #expect(sut.items.count == 1)
        #expect(sut.items.first?.id == "b")
    }

    @Test("동일 아이템 연속 toggleBookmark 시 한 번만 처리")
    func toggleBookmark_concurrent_deduplicates() async {
        let item = ImageItem.fixture(id: "a", isBookmarked: true)
        let (sut, repo) = makeSUT(initialItems: [item])
        await sut.loadBookmarks()

        async let t1: Void = sut.toggleBookmark(for: item)
        async let t2: Void = sut.toggleBookmark(for: item)
        _ = await (t1, t2)

        #expect(repo.deleteCallCount == 1)
    }

    @Test("toggleBookmark 실패 후 inFlightBookmarkIDs 복구")
    func toggleBookmark_failure_restoresInFlightState() async {
        let item = ImageItem.fixture(id: "a", isBookmarked: true)
        let (sut, repo) = makeSUT(initialItems: [item])
        await sut.loadBookmarks()
        repo.stubbedDeleteError = TestError.stub

        await sut.toggleBookmark(for: item)

        #expect(!sut.inFlightBookmarkIDs.contains(item.id))
    }
}
