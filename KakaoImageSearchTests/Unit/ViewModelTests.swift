//
//  ViewModelTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

// MARK: - SearchViewModel

@MainActor
@Suite("SearchViewModel")
struct SearchViewModelTests {

    private func makeSUT(
        searchItems: [ImageItem] = [],
        bookmarkedItems: [ImageItem] = [],
        searchError: Error? = nil,
        imagePrefetcher: any ImagePrefetcher = MockImagePrefetcher(),
        networkMonitor: MockNetworkMonitor = MockNetworkMonitor()
    ) -> (sut: SearchViewModel, searchRepo: MockImageSearchRepository, bookmarkRepo: MockBookmarkRepository, prefetcher: any ImagePrefetcher) {
        let searchRepo = MockImageSearchRepository()
        searchRepo.stubbedResult = searchItems
        searchRepo.stubbedError = searchError

        let bookmarkRepo = MockBookmarkRepository()
        bookmarkRepo.items = bookmarkedItems

        let bookmarkStore = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        let sut = SearchViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo
            ),
            bookmarkStore: bookmarkStore,
            imagePrefetcher: imagePrefetcher,
            networkMonitor: networkMonitor,
            toastDuration: .zero
        )
        return (sut, searchRepo, bookmarkRepo, imagePrefetcher)
    }

    @Test("검색 성공 시 items 설정, loaded 상태")
    func search_success_setsItemsAndLoaded() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _, _, _) = makeSUT(searchItems: items)

        await sut.submitSearch(query: "cat").value

        #expect(sut.items.count == 2)
        #expect(sut.searchState == .loaded(.idle))
    }

    @Test("검색 결과가 비어있으면 empty 상태")
    func search_emptyResult_setsEmpty() async throws {
        let (sut, _, _, _) = makeSUT(searchItems: [])

        await sut.submitSearch(query: "zzz").value

        #expect(sut.items.isEmpty)
        #expect(sut.searchState == .empty)
    }

    @Test("검색 실패 시 items 비우고 error 상태")
    func search_failure_clearsItemsAndSetsError() async throws {
        let (sut, _, _, _) = makeSUT(searchError: TestError.stub)

        await sut.submitSearch(query: "cat").value

        #expect(sut.items.isEmpty)
        if case .error = sut.searchState {} else { Issue.record("expected .error") }
    }

    @Test("검색 실패 시 error 상태")
    func search_failure_setsError() async {
        let (sut, _, _, _) = makeSUT(searchError: TestError.stub)

        await sut.submitSearch(query: "cat").value

        if case .error = sut.searchState {} else { Issue.record("expected .error") }
    }

    @Test("검색 성공 시 error 상태 해제")
    func search_success_clearsError() async {
        let (sut, searchRepo, _, _) = makeSUT(searchError: TestError.stub)
        await sut.submitSearch(query: "cat").value

        searchRepo.stubbedError = nil
        searchRepo.stubbedResult = [ImageItem.fixture()]
        await sut.submitSearch(query: "cat").value

        #expect(sut.searchState == .loaded(.idle))
    }

    @Test("결과 없음은 empty 상태 (error 아님)")
    func search_emptyResult_setsEmptyNotError() async {
        let (sut, _, _, _) = makeSUT(searchItems: [])

        await sut.submitSearch(query: "zzz").value

        #expect(sut.searchState == .empty)
    }

    @Test("retry 호출 시 동일 쿼리로 재검색")
    func retry_searchesWithSameQuery() async {
        let (sut, searchRepo, _, _) = makeSUT(searchError: TestError.stub)
        await sut.submitSearch(query: "고양이").value

        searchRepo.stubbedError = nil
        searchRepo.stubbedResult = [ImageItem.fixture()]
        await sut.retry()?.value

        #expect(searchRepo.lastQuery == "고양이")
        #expect(searchRepo.searchCallCount == 2)
        #expect(sut.searchState == .loaded(.idle))
    }

    @Test("loadMore 실패 시 loadMoreError 상태, 기존 결과 유지")
    func loadMore_failure_setsLoadMoreError() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        searchRepo.stubbedError = TestError.stub
        await sut.loadMore()?.value

        #expect(sut.searchState == .loaded(.loadMoreError))
        #expect(sut.items.count == 1)
    }

    @Test("retryLoadMore 호출 시 loadMoreError 해제 후 추가 로드")
    func retryLoadMore_resetsErrorAndAppendsItems() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        searchRepo.stubbedError = TestError.stub
        await sut.loadMore()?.value
        #expect(sut.searchState == .loaded(.loadMoreError))

        searchRepo.stubbedError = nil
        searchRepo.stubbedResult = [ImageItem.fixture(id: "b")]
        await sut.retryLoadMore()?.value

        #expect(sut.searchState == .loaded(.idle))
        #expect(sut.items.count == 2)
    }

    @Test("재검색 시 loadMoreError 초기화")
    func search_clearsLoadMoreError() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture()])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value
        searchRepo.stubbedError = TestError.stub
        await sut.loadMore()?.value
        #expect(sut.searchState == .loaded(.loadMoreError))

        searchRepo.stubbedError = nil
        await sut.submitSearch(query: "cat").value

        #expect(sut.searchState == .loaded(.idle))
    }

    @Test("currentQuery 없을 때 retry 호출 시 검색 미실행")
    func retry_withEmptyQuery_doesNotSearch() {
        let (sut, searchRepo, _, _) = makeSUT()

        sut.retry()

        #expect(searchRepo.searchCallCount == 0)
    }

    @Test("cancelSearchAndClear 호출 시 상태 초기화")
    func cancelSearchAndClear_resetsState() async throws {
        let items = [ImageItem.fixture(id: "a")]
        let (sut, _, _, _) = makeSUT(searchItems: items)
        await sut.submitSearch(query: "cat").value

        sut.cancelSearchAndClear()

        #expect(sut.items.isEmpty)
        #expect(sut.searchState == .idle)
    }

    @Test("새 검색 시작 시 진행 중인 loadMore 상태를 loading으로 전환")
    func newSearch_whileLoadMoreInProgress_setsLoading() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        let loadMoreTask = sut.loadMore()
        sut.submitSearch(query: "dog")

        #expect(sut.searchState == .loading)
        _ = await loadMoreTask?.value
    }

    @Test("cancelSearchAndClear 시 진행 중인 loadMore 상태를 idle로 전환")
    func cancelSearchAndClear_whileLoadMoreInProgress_setsIdle() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        let loadMoreTask = sut.loadMore()
        sut.cancelSearchAndClear()

        #expect(sut.searchState == .idle)
        _ = await loadMoreTask?.value
    }

    @Test("toggleBookmark 성공 시 해당 아이템 isBookmarked 반전")
    func toggleBookmark_updatesItemBookmarkState() async throws {
        let item = ImageItem.fixture(id: "a", isBookmarked: false)
        let (sut, _, _, _) = makeSUT(searchItems: [item])
        await sut.submitSearch(query: "cat").value

        await sut.toggleBookmark(for: sut.items[0])

        #expect(sut.items[0].isBookmarked == true)
    }

    @Test("toggleBookmark 실패 시 toastMessage 설정")
    func toggleBookmark_failure_setsToastMessage() async throws {
        let item = ImageItem.fixture(id: "a")
        let (sut, _, bookmarkRepo, _) = makeSUT(searchItems: [item])
        await sut.submitSearch(query: "cat").value
        bookmarkRepo.stubbedSaveError = TestError.stub

        await sut.toggleBookmark(for: sut.items[0])

        #expect(sut.toastMessage != nil)
    }

    @Test("toggleBookmark 실패해도 searchState 변경 없음")
    func toggleBookmark_failure_doesNotChangeSearchState() async throws {
        let item = ImageItem.fixture(id: "a")
        let (sut, _, bookmarkRepo, _) = makeSUT(searchItems: [item])
        await sut.submitSearch(query: "cat").value
        bookmarkRepo.stubbedSaveError = TestError.stub

        await sut.toggleBookmark(for: sut.items[0])

        #expect(sut.searchState == .loaded(.idle))
    }

    @Test("toggleBookmark 실패해도 기존 검색 결과 유지")
    func toggleBookmark_failure_doesNotClearSearchResults() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _, bookmarkRepo, _) = makeSUT(searchItems: items)
        await sut.submitSearch(query: "cat").value
        bookmarkRepo.stubbedSaveError = TestError.stub

        await sut.toggleBookmark(for: sut.items[0])

        #expect(sut.items.count == 2)
    }

    @Test("검색 성공 시 썸네일 URL 프리패치 요청")
    func search_success_prefetchesThumbnailURLs() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let prefetcher = MockImagePrefetcher()
        let (sut, _, _, _) = makeSUT(searchItems: items, imagePrefetcher: prefetcher)

        await sut.submitSearch(query: "cat").value
        _ = await prefetcher.prefetchCalled.first(where: { @Sendable _ in true })

        #expect(prefetcher.prefetchCallCount == 1)
        #expect(prefetcher.prefetchedURLs.count == 2)
    }

    @Test("loadMore 성공 시 추가 썸네일 프리패치 요청")
    func loadMore_success_prefetchesThumbnailURLs() async throws {
        let prefetcher = MockImagePrefetcher()
        let (sut, searchRepo, _, _) = makeSUT(
            searchItems: [ImageItem.fixture(id: "a")],
            imagePrefetcher: prefetcher
        )
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value
        _ = await prefetcher.prefetchCalled.first(where: { @Sendable _ in true })

        searchRepo.stubbedResult = [ImageItem.fixture(id: "b")]
        await sut.loadMore()?.value
        _ = await prefetcher.prefetchCalled.first(where: { @Sendable _ in true })

        #expect(prefetcher.prefetchCallCount == 2)
    }

    @Test("imageURL·thumbnailURL 모두 nil인 아이템은 프리패치에서 제외")
    func search_success_nilDisplayURLsExcludedFromPrefetch() async throws {
        let items = [
            ImageItem.fixture(id: "a"),
            ImageItem.fixture(id: "b", imageURL: nil, thumbnailURL: nil)
        ]
        let prefetcher = MockImagePrefetcher()
        let (sut, _, _, _) = makeSUT(searchItems: items, imagePrefetcher: prefetcher)

        await sut.submitSearch(query: "cat").value
        _ = await prefetcher.prefetchCalled.first(where: { @Sendable _ in true })

        #expect(prefetcher.prefetchedURLs.count == 1)
    }

    @Test("검색 실패 시 프리패치 미요청")
    func search_failure_doesNotPrefetch() async throws {
        let prefetcher = MockImagePrefetcher()
        let (sut, _, _, _) = makeSUT(searchError: TestError.stub, imagePrefetcher: prefetcher)

        await sut.submitSearch(query: "cat").value

        #expect(prefetcher.prefetchCallCount == 0)
    }

    @Test("동일 아이템 연속 토글 시 한 번만 처리")
    func toggleBookmark_concurrent_deduplicates() async {
        let item = ImageItem.fixture(id: "a")
        let (sut, _, repo, _) = makeSUT()

        async let t1: Void = sut.toggleBookmark(for: item)
        async let t2: Void = sut.toggleBookmark(for: item)
        _ = await (t1, t2)

        #expect(repo.saveCallCount == 1)
    }

    @Test("toggleBookmark 실패 후 inFlightBookmarkIDs 복구")
    func toggleBookmark_failure_restoresInFlightState() async {
        let item = ImageItem.fixture(id: "a")
        let (sut, _, repo, _) = makeSUT()
        repo.stubbedSaveError = TestError.stub

        await sut.toggleBookmark(for: item)

        #expect(!sut.inFlightBookmarkIDs.contains(item.id))
    }

    @Test("새 검색 시작 시 진행 중인 prefetch Task가 취소된다")
    func newSearch_cancelsPreviousPrefetchTask() async {
        let blockingPrefetcher = BlockingMockImagePrefetcher()
        let (sut, _, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")], imagePrefetcher: blockingPrefetcher)

        sut.submitSearch(query: "cat")
        _ = await blockingPrefetcher.started.first(where: { @Sendable _ in true })

        sut.submitSearch(query: "dog")
        _ = await blockingPrefetcher.cancelled.first(where: { @Sendable _ in true })
        // cancelled stream에서 yield됐으면 취소 전파 확인
    }

    @Test("exhausted 상태이면 loadMore가 실행되지 않는다")
    func loadMore_whenExhausted_doesNotExecute() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = true
        await sut.submitSearch(query: "cat").value

        let task = sut.loadMore()

        #expect(task == nil)
        #expect(searchRepo.searchCallCount == 1)
        #expect(sut.searchState == .loaded(.exhausted))
    }

    @Test("page 15 도달 시 isEnd = false여도 apiLimitReached 상태")
    func loadMore_page15_setsApiLimitReached() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        for i in 2...15 {
            searchRepo.stubbedResult = [ImageItem.fixture(id: "p\(i)")]
            await sut.loadMore()?.value
        }

        #expect(sut.searchState == .loaded(.apiLimitReached))
        #expect(sut.loadMore() == nil)
    }

    @Test("API가 isEnd = true 반환 시 exhausted 상태 (apiLimitReached 아님)")
    func loadMore_apiReturnsIsEnd_setsExhausted() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        searchRepo.stubbedResult = [ImageItem.fixture(id: "b")]
        searchRepo.stubbedIsEnd = true
        await sut.loadMore()?.value

        #expect(sut.searchState == .loaded(.exhausted))
    }

    @Test("재검색 시 apiLimitReached 초기화")
    func newSearch_clearsApiLimitReached() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        for i in 2...15 {
            searchRepo.stubbedResult = [ImageItem.fixture(id: "p\(i)")]
            await sut.loadMore()?.value
        }
        #expect(sut.searchState == .loaded(.apiLimitReached))

        searchRepo.stubbedResult = [ImageItem.fixture(id: "new")]
        await sut.submitSearch(query: "dog").value

        #expect(sut.searchState == .loaded(.idle))
    }

    @Test("cancelSearchAndClear 시 진행 중인 prefetch Task가 취소된다")
    func cancelSearchAndClear_cancelsPrefetchTask() async {
        let blockingPrefetcher = BlockingMockImagePrefetcher()
        let (sut, _, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")], imagePrefetcher: blockingPrefetcher)

        sut.submitSearch(query: "cat")
        _ = await blockingPrefetcher.started.first(where: { @Sendable _ in true })

        sut.cancelSearchAndClear()
        _ = await blockingPrefetcher.cancelled.first(where: { @Sendable _ in true })
    }

    @Test("오프라인 상태에서 검색 시 error 상태로 전환")
    func search_offline_setsErrorState() async {
        let offlineMonitor = MockNetworkMonitor()
        offlineMonitor.isConnected = false
        let (sut, _, _, _) = makeSUT(
            searchItems: [ImageItem.fixture(id: "a")],
            networkMonitor: offlineMonitor
        )

        await sut.submitSearch(query: "cat").value

        guard case .error = sut.searchState else {
            Issue.record("Expected .error state but got \(sut.searchState)")
            return
        }
    }
}

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
            bookmarkStore: BookmarkStore(
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

        _ = try await sut.toggle(item)

        #expect(sut.bookmarkedIDs.contains("a"))
        #expect(sut.bookmarkedItems.contains { $0.id == "a" })
    }

    @Test("toggle 북마크 제거 시 bookmarkedItems, bookmarkedIDs에서 삭제")
    func toggle_remove_updatesItemsAndIDs() async throws {
        let item = ImageItem.fixture(id: "a", isBookmarked: true)
        let (sut, _) = makeSUT(initialItems: [item])
        try await sut.load()

        _ = try await sut.toggle(item)

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

        let first = try await sut.toggle(item)
        #expect(first == true)
        #expect(sut.bookmarkedIDs.contains("a"))

        let second = try await sut.toggle(item)
        #expect(second == false)
        #expect(!sut.bookmarkedIDs.contains("a"))
        #expect(sut.bookmarkedItems.isEmpty)
    }
}

// MARK: - MainViewModel

@MainActor
@Suite("MainViewModel")
struct MainViewModelTests {

    private func makeSUT() -> MainViewModel {
        let bookmarkRepo = MockBookmarkRepository()
        let searchRepo = MockImageSearchRepository()
        return MainViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo),
            imagePrefetcher: MockImagePrefetcher(),
            networkMonitor: MockNetworkMonitor()
        )
    }

    @Test("빈 문자열 입력 시 검색 결과 초기화")
    func onSearchTextChanged_empty_clearsResults() {
        let sut = makeSUT()

        sut.onSearchTextChanged("")

        #expect(sut.searchViewModel.items.isEmpty)
        #expect(sut.searchViewModel.searchState == .idle)
    }

    @Test("공백만 입력 시 검색 결과 초기화")
    func onSearchTextChanged_whitespace_clearsResults() {
        let sut = makeSUT()

        sut.onSearchTextChanged("   ")

        #expect(sut.searchViewModel.items.isEmpty)
        #expect(sut.searchViewModel.searchState == .idle)
    }

    @Test("유효한 쿼리 입력 시 debounce 대기 중 hasSearched = false")
    func onSearchTextChanged_validQuery_debounceNotFiredImmediately() {
        let sut = makeSUT()

        sut.onSearchTextChanged("cat")

        #expect(sut.searchViewModel.searchState == .idle)
    }

    @Test("연속 입력 시 이전 debounce 취소 후 마지막 쿼리만 검색")
    func onSearchTextChanged_rapidInput_onlyLastQuerySearched() async throws {
        let searchRepo = MockImageSearchRepository()
        let bookmarkRepo = MockBookmarkRepository()
        let sut = MainViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo),
            imagePrefetcher: MockImagePrefetcher(),
            networkMonitor: MockNetworkMonitor()
        )

        sut.onSearchTextChanged("a")
        sut.onSearchTextChanged("ab")
        sut.onSearchTextChanged("abc")

        // debounce(1초) 대기
        try await Task.sleep(for: .seconds(1.5))

        #expect(searchRepo.searchCallCount == 1)
        #expect(searchRepo.lastQuery == "abc")
    }
}
