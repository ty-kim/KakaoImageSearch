//
//  BookmarkStore.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 4/2/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

// MARK: - BookmarkStore

@MainActor
@Suite("BookmarkStore")
struct BookmarkStoreTests {

    private func makeSUT(
        initialItems: [ImageItem] = [],
        fetchError: Error? = nil
    ) -> (sut: BookmarkStore, repo: MockBookmarkRepository) {
        let repo = MockBookmarkRepository()
        repo.items = initialItems
        repo.stubbedFetchError = fetchError
        let sut = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: repo)
        )
        return (sut, repo)
    }

    @Test("load 성공 시 bookmarkedItems, bookmarkedIDs 설정")
    func load_success_setsItemsAndIDs() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _) = makeSUT(initialItems: items)

        try await sut.load()

        #expect(sut.bookmarkedItems.count == 2)
        #expect(sut.bookmarkedIDs == ["a", "b"])
    }

    @Test("load 실패 시 에러 throw")
    func load_failure_throws() async {
        let (sut, _) = makeSUT(fetchError: TestError.stub)

        await #expect(throws: TestError.stub) {
            try await sut.load()
        }
    }

    @Test("toggle 북마크 추가 시 bookmarkedItems, bookmarkedIDs에 반영")
    func toggle_add_updatesItemsAndIDs() async throws {
        let item = ImageItem.fixture(id: "a")
        let (sut, _) = makeSUT()

        let result = await sut.toggle(item)

        #expect(try result.get() == true)
        #expect(sut.bookmarkedIDs.contains("a"))
        #expect(sut.bookmarkedItems.contains { $0.id == "a" })
    }

    @Test("toggle 북마크 제거 시 bookmarkedItems, bookmarkedIDs에서 삭제")
    func toggle_remove_updatesItemsAndIDs() async throws {
        let item = ImageItem.fixture(id: "a", isBookmarked: true)
        let (sut, _) = makeSUT(initialItems: [item])
        try await sut.load()

        let result = await sut.toggle(item)

        #expect(try result.get() == false)
        #expect(!sut.bookmarkedIDs.contains("a"))
        #expect(!sut.bookmarkedItems.contains { $0.id == "a" })
    }

    @Test("isBookmarked: bookmarkedIDs 기반으로 판별")
    func isBookmarked_returnsCorrectState() async throws {
        let item = ImageItem.fixture(id: "a", isBookmarked: true)
        let (sut, _) = makeSUT(initialItems: [item])
        try await sut.load()

        #expect(sut.isBookmarked("a") == true)
        #expect(sut.isBookmarked("z") == false)
    }

    @Test("같은 아이템을 연속 toggle 시 add→remove로 최종 상태 일관")
    func toggle_sameTwice_addsAndRemoves() async throws {
        let item = ImageItem.fixture(id: "a")
        let (sut, _) = makeSUT()

        let first = try await sut.toggle(item).get()
        #expect(first == true)
        #expect(sut.bookmarkedIDs.contains("a"))

        let second = try await sut.toggle(item).get()
        #expect(second == false)
        #expect(!sut.bookmarkedIDs.contains("a"))
        #expect(sut.bookmarkedItems.isEmpty)
    }

    @Test("동일 아이템 동시 toggle 시 한 번만 처리 (inFlight dedup)")
    func toggle_concurrent_deduplicates() async {
        let item = ImageItem.fixture(id: "a")
        let (sut, repo) = makeSUT()

        async let t1 = sut.toggle(item)
        async let t2 = sut.toggle(item)
        _ = await (t1, t2)

        #expect(repo.saveCallCount == 1)
    }

    @Test("toggle 실패 시 optimistic 업데이트 롤백")
    func toggle_failure_rollsBackOptimisticUpdate() async {
        let item = ImageItem.fixture(id: "a")
        let (sut, repo) = makeSUT()
        repo.stubbedSaveError = TestError.stub

        let result = await sut.toggle(item)

        guard case .failure = result else {
            Issue.record("Expected .failure")
            return
        }
        #expect(!sut.bookmarkedIDs.contains("a"))
        #expect(sut.bookmarkedItems.isEmpty)
    }

    @Test("toggle 완료 후 inFlightBookmarkIDs에서 제거")
    func toggle_completion_removesFromInFlight() async {
        let item = ImageItem.fixture(id: "a")
        let (sut, _) = makeSUT()

        _ = await sut.toggle(item)

        #expect(!sut.inFlightBookmarkIDs.contains("a"))
    }

    // MARK: - load() 동시 호출 테스트

    @Test("동시 load() 호출 시 둘 다 같은 완료를 기다린다")
    func load_concurrent_bothWaitForSameCompletion() async throws {
        let items = [ImageItem.fixture(id: "a")]
        let (sut, repo) = makeSUT(initialItems: items)

        // fetchAll()이 suspend되도록 설정
        repo.fetchSuspender = {
            await Task.yield()
        }

        async let load1: () = sut.load()
        async let load2: () = sut.load()
        _ = try await (load1, load2)

        // fetchAll()은 한 번만 호출되어야 함
        #expect(repo.fetchCallCount == 1)
        #expect(sut.bookmarkedItems.count == 1)
    }

    @Test("첫 load() 실패 시 대기 중인 호출도 같은 에러를 받는다")
    func load_concurrentFailure_bothReceiveError() async {
        let (sut, repo) = makeSUT(fetchError: TestError.stub)

        repo.fetchSuspender = {
            await Task.yield()
        }

        async let r1: Result<Void, Error> = {
            do { try await sut.load(); return .success(()) }
            catch { return .failure(error) }
        }()
        async let r2: Result<Void, Error> = {
            do { try await sut.load(); return .success(()) }
            catch { return .failure(error) }
        }()

        let results = await [r1, r2]

        #expect(results.allSatisfy { if case .failure = $0 { true } else { false } })
        #expect(repo.fetchCallCount == 1)
    }

    @Test("이미 loaded 상태면 재fetch하지 않는다")
    func load_alreadyLoaded_skipsRefetch() async throws {
        let (sut, repo) = makeSUT(initialItems: [ImageItem.fixture(id: "a")])

        try await sut.load()
        #expect(repo.fetchCallCount == 1)

        // 두 번째 호출은 fetch 없이 즉시 return
        try await sut.load()
        #expect(repo.fetchCallCount == 1)
    }

    @Test("refresh()는 loaded 상태에서도 다시 fetch한다")
    func refresh_refetchesAfterLoaded() async throws {
        let (sut, repo) = makeSUT(initialItems: [ImageItem.fixture(id: "a")])

        try await sut.load()
        #expect(repo.fetchCallCount == 1)

        repo.items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        try await sut.refresh()

        #expect(repo.fetchCallCount == 2)
        #expect(sut.bookmarkedItems.count == 2)
    }
}
