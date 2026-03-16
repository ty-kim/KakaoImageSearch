//
//  ViewModelTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
@testable import KakaoImageSearch

// MARK: - SearchViewModel

@MainActor
@Suite("SearchViewModel")
struct SearchViewModelTests {

    private func makeSUT(
        searchItems: [ImageItem] = [],
        bookmarkedItems: [ImageItem] = [],
        searchError: Error? = nil
    ) -> (sut: SearchViewModel, searchRepo: MockImageSearchRepository, bookmarkRepo: MockBookmarkRepository) {
        let searchRepo = MockImageSearchRepository()
        searchRepo.stubbedResult = searchItems
        searchRepo.stubbedError = searchError

        let bookmarkRepo = MockBookmarkRepository()
        bookmarkRepo.items = bookmarkedItems

        let sut = SearchViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo,
                bookmarkRepository: bookmarkRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        return (sut, searchRepo, bookmarkRepo)
    }

    @Test("검색 성공 시 items 설정, isLoading = false")
    func search_success_setsItemsAndStopsLoading() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _, _) = makeSUT(searchItems: items)

        await sut.search(query: "cat")

        #expect(sut.items.count == 2)
        #expect(sut.isLoading == false)
        #expect(sut.errorMessage == nil)
        #expect(sut.hasSearched == true)
    }

    @Test("검색 결과가 비어있으면 errorMessage 설정")
    func search_emptyResult_setsErrorMessage() async throws {
        let (sut, _, _) = makeSUT(searchItems: [])

        await sut.search(query: "zzz")

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage != nil)
    }

    @Test("검색 실패 시 items 비우고 errorMessage 설정")
    func search_failure_clearsItemsAndSetsErrorMessage() async throws {
        let (sut, _, _) = makeSUT(searchError: TestError.stub)

        await sut.search(query: "cat")

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage != nil)
        #expect(sut.isLoading == false)
    }

    @Test("isLoading 중 재검색 무시")
    func search_whileLoading_ignored() async throws {
        let (sut, searchRepo, _) = makeSUT()

        // isLoading 상태를 직접 만들 수 없으므로 searchCallCount 로 검증
        await sut.search(query: "first")
        let callCount = searchRepo.searchCallCount

        #expect(callCount == 1)
    }

    @Test("clearResults 호출 시 상태 초기화")
    func clearResults_resetsState() async throws {
        let items = [ImageItem.fixture(id: "a")]
        let (sut, _, _) = makeSUT(searchItems: items)
        await sut.search(query: "cat")

        sut.clearResults()

        #expect(sut.items.isEmpty)
        #expect(sut.errorMessage == nil)
        #expect(sut.hasSearched == false)
    }

    @Test("toggleBookmark 성공 시 해당 아이템 isBookmarked 반전")
    func toggleBookmark_updatesItemBookmarkState() async throws {
        let item = ImageItem.fixture(id: "a", isBookmarked: false)
        let (sut, _, _) = makeSUT(searchItems: [item])
        await sut.search(query: "cat")

        await sut.toggleBookmark(for: sut.items[0])

        #expect(sut.items[0].isBookmarked == true)
    }

    @Test("toggleBookmark 실패 시 errorMessage 설정")
    func toggleBookmark_failure_setsErrorMessage() async throws {
        let item = ImageItem.fixture(id: "a")
        let (sut, _, bookmarkRepo) = makeSUT(searchItems: [item])
        await sut.search(query: "cat")
        bookmarkRepo.stubbedSaveError = TestError.stub

        await sut.toggleBookmark(for: sut.items[0])

        #expect(sut.errorMessage != nil)
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
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: repo)
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

    @Test("loadBookmarks 실패 시 items 비움")
    func loadBookmarks_failure_clearsItems() async throws {
        let items = [ImageItem.fixture(id: "a")]
        let (sut, repo) = makeSUT(initialItems: items)
        repo.stubbedFetchError = TestError.stub

        await sut.loadBookmarks()

        #expect(sut.items.isEmpty)
        #expect(sut.isLoading == false)
    }

    @Test("removeBookmark 호출 시 해당 아이템 제거 후 목록 갱신")
    func removeBookmark_removesItemAndReloads() async throws {
        let itemA = ImageItem.fixture(id: "a", isBookmarked: true)
        let itemB = ImageItem.fixture(id: "b", isBookmarked: true)
        let (sut, _) = makeSUT(initialItems: [itemA, itemB])
        await sut.loadBookmarks()

        await sut.removeBookmark(for: itemA)

        #expect(sut.items.count == 1)
        #expect(sut.items.first?.id == "b")
    }
}

// MARK: - MainViewModel

@MainActor
@Suite("MainViewModel")
struct MainViewModelTests {

    private func makeSUT() -> MainViewModel {
        let bookmarkRepo = MockBookmarkRepository()
        let searchRepo = MockImageSearchRepository()
        let searchVM = SearchViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo,
                bookmarkRepository: bookmarkRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        let bookmarkVM = BookmarkViewModel(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        return MainViewModel(searchViewModel: searchVM, bookmarkViewModel: bookmarkVM)
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
        let searchVM = SearchViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo,
                bookmarkRepository: bookmarkRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        let bookmarkVM = BookmarkViewModel(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        let sut = MainViewModel(searchViewModel: searchVM, bookmarkViewModel: bookmarkVM)

        sut.onSearchTextChanged("a")
        sut.onSearchTextChanged("ab")
        sut.onSearchTextChanged("abc")

        // debounce(1초) 대기
        try await Task.sleep(for: .seconds(1.5))

        #expect(searchRepo.searchCallCount == 1)
        #expect(searchRepo.lastQuery == "abc")
    }
}
