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
        imagePrefetcher: any ImagePrefetcher = MockImagePrefetcher()
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
                imageSearchRepository: searchRepo,
                bookmarkRepository: bookmarkRepo
            ),
            bookmarkStore: bookmarkStore,
            imagePrefetcher: imagePrefetcher,
            toastDuration: .zero
        )
        return (sut, searchRepo, bookmarkRepo, imagePrefetcher)
    }

    @Test("검색 성공 시 items 설정, isLoading = false")
    func search_success_setsItemsAndStopsLoading() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _, _, _) = makeSUT(searchItems: items)

        await sut.submitSearch(query: "cat").value

        #expect(sut.items.count == 2)
        #expect(sut.isLoading == false)
        #expect(sut.errorMessage == nil)
        #expect(sut.hasSearched == true)
    }

    @Test("검색 결과가 비어있으면 errorMessage 설정")
    func search_emptyResult_setsErrorMessage() async throws {
        let (sut, _, _, _) = makeSUT(searchItems: [])

        await sut.submitSearch(query: "zzz").value

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage != nil)
    }

    @Test("검색 실패 시 items 비우고 errorMessage 설정")
    func search_failure_clearsItemsAndSetsErrorMessage() async throws {
        let (sut, _, _, _) = makeSUT(searchError: TestError.stub)

        await sut.submitSearch(query: "cat").value

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage != nil)
        #expect(sut.isLoading == false)
    }

    @Test("검색 실패 시 hasError = true")
    func search_failure_setsHasError() async {
        let (sut, _, _, _) = makeSUT(searchError: TestError.stub)

        await sut.submitSearch(query: "cat").value

        #expect(sut.hasError == true)
    }

    @Test("검색 성공 시 hasError 초기화")
    func search_success_clearsHasError() async {
        let (sut, searchRepo, _, _) = makeSUT(searchError: TestError.stub)
        await sut.submitSearch(query: "cat").value

        searchRepo.stubbedError = nil
        searchRepo.stubbedResult = [ImageItem.fixture()]
        await sut.submitSearch(query: "cat").value

        #expect(sut.hasError == false)
    }

    @Test("결과 없음은 hasError = false 유지")
    func search_emptyResult_doesNotSetHasError() async {
        let (sut, _, _, _) = makeSUT(searchItems: [])

        await sut.submitSearch(query: "zzz").value

        #expect(sut.hasError == false)
        #expect(sut.errorMessage != nil)
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
        #expect(sut.hasError == false)
    }

    @Test("loadMore 실패 시 hasLoadMoreError = true, 기존 결과 유지")
    func loadMore_failure_setsHasLoadMoreError() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        searchRepo.stubbedError = TestError.stub
        await sut.loadMore()?.value

        #expect(sut.hasLoadMoreError == true)
        #expect(sut.items.count == 1)
    }

    @Test("retryLoadMore 호출 시 hasLoadMoreError 초기화 후 추가 로드")
    func retryLoadMore_resetsErrorAndAppendsItems() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        searchRepo.stubbedError = TestError.stub
        await sut.loadMore()?.value
        #expect(sut.hasLoadMoreError == true)

        searchRepo.stubbedError = nil
        searchRepo.stubbedResult = [ImageItem.fixture(id: "b")]
        await sut.retryLoadMore()?.value

        #expect(sut.hasLoadMoreError == false)
        #expect(sut.items.count == 2)
    }

    @Test("재검색 시 hasLoadMoreError 초기화")
    func search_clearsHasLoadMoreError() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture()])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value
        searchRepo.stubbedError = TestError.stub
        await sut.loadMore()?.value
        #expect(sut.hasLoadMoreError == true)

        searchRepo.stubbedError = nil
        await sut.submitSearch(query: "cat").value

        #expect(sut.hasLoadMoreError == false)
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
        #expect(sut.errorMessage == nil)
        #expect(sut.hasSearched == false)
    }

    @Test("새 검색 시작 시 진행 중인 loadMore의 isLoadingMore 즉시 리셋")
    func newSearch_whileLoadMoreInProgress_resetsIsLoadingMore() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        // loadMore Task를 시작하되 완료 전에 새 검색 진행
        let loadMoreTask = sut.loadMore()
        sut.submitSearch(query: "dog")  // beginSearch에서 loadMoreTask.cancel() + isLoadingMore = false

        #expect(sut.isLoadingMore == false)
        _ = await loadMoreTask?.value  // task 정리
    }

    @Test("cancelSearchAndClear 시 진행 중인 loadMore의 isLoadingMore 리셋")
    func cancelSearchAndClear_whileLoadMoreInProgress_resetsIsLoadingMore() async {
        let (sut, searchRepo, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")])
        searchRepo.stubbedIsEnd = false
        await sut.submitSearch(query: "cat").value

        let loadMoreTask = sut.loadMore()
        sut.cancelSearchAndClear()

        #expect(sut.isLoadingMore == false)
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

    @Test("toggleBookmark 실패해도 errorMessage 변경 없음")
    func toggleBookmark_failure_doesNotSetErrorMessage() async throws {
        let item = ImageItem.fixture(id: "a")
        let (sut, _, bookmarkRepo, _) = makeSUT(searchItems: [item])
        await sut.submitSearch(query: "cat").value
        bookmarkRepo.stubbedSaveError = TestError.stub

        await sut.toggleBookmark(for: sut.items[0])

        #expect(sut.errorMessage == nil)
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

    @Test("cancelSearchAndClear 시 진행 중인 prefetch Task가 취소된다")
    func cancelSearchAndClear_cancelsPrefetchTask() async {
        let blockingPrefetcher = BlockingMockImagePrefetcher()
        let (sut, _, _, _) = makeSUT(searchItems: [ImageItem.fixture(id: "a")], imagePrefetcher: blockingPrefetcher)

        sut.submitSearch(query: "cat")
        _ = await blockingPrefetcher.started.first(where: { @Sendable _ in true })

        sut.cancelSearchAndClear()
        _ = await blockingPrefetcher.cancelled.first(where: { @Sendable _ in true })
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

    @Test("loadBookmarks 성공 시 items 설정")
    func loadBookmarks_success_setsItems() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _) = makeSUT(initialItems: items)

        await sut.loadBookmarks()

        #expect(sut.items.count == 2)
        #expect(sut.isLoading == false)
    }

    @Test("loadBookmarks 실패 시 hasLoadError 설정")
    func loadBookmarks_failure_setsHasLoadError() async throws {
        let (sut, repo) = makeSUT()
        repo.stubbedFetchError = TestError.stub

        await sut.loadBookmarks()

        #expect(sut.hasLoadError == true)
        #expect(sut.isLoading == false)
    }

    @Test("loadBookmarks 재시도 성공 시 hasLoadError 해제")
    func loadBookmarks_retrySuccess_clearsError() async throws {
        let items = [ImageItem.fixture(id: "a")]
        let (sut, repo) = makeSUT(initialItems: items)
        repo.stubbedFetchError = TestError.stub

        await sut.loadBookmarks()
        #expect(sut.hasLoadError == true)

        repo.stubbedFetchError = nil
        await sut.loadBookmarks()

        #expect(sut.hasLoadError == false)
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
        #expect(sut.isLoading == false)
    }

    @Test("load 실패 시 에러 throw")
    func load_failure_throws() async {
        let (sut, _) = makeSUT(fetchError: TestError.stub)

        await #expect(throws: TestError.stub) {
            try await sut.load()
        }
        #expect(sut.isLoading == false)
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
                imageSearchRepository: searchRepo,
                bookmarkRepository: bookmarkRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
    }

    @Test("빈 문자열 입력 시 검색 결과 초기화")
    func onSearchTextChanged_empty_clearsResults() {
        let sut = makeSUT()

        sut.onSearchTextChanged("")

        #expect(sut.searchViewModel.items.isEmpty)
        #expect(sut.searchViewModel.hasSearched == false)
    }

    @Test("공백만 입력 시 검색 결과 초기화")
    func onSearchTextChanged_whitespace_clearsResults() {
        let sut = makeSUT()

        sut.onSearchTextChanged("   ")

        #expect(sut.searchViewModel.items.isEmpty)
        #expect(sut.searchViewModel.hasSearched == false)
    }

    @Test("유효한 쿼리 입력 시 debounce 대기 중 hasSearched = false")
    func onSearchTextChanged_validQuery_debounceNotFiredImmediately() {
        let sut = makeSUT()

        sut.onSearchTextChanged("cat")

        #expect(sut.searchViewModel.hasSearched == false)
    }

    @Test("연속 입력 시 이전 debounce 취소 후 마지막 쿼리만 검색")
    func onSearchTextChanged_rapidInput_onlyLastQuerySearched() async throws {
        let searchRepo = MockImageSearchRepository()
        let bookmarkRepo = MockBookmarkRepository()
        let sut = MainViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo,
                bookmarkRepository: bookmarkRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
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
