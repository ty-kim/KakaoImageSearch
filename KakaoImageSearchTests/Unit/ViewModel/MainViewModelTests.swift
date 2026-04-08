//
//  MainViewModelTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 4/2/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

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

    @Test("loadInitialData 성공 시 bookmarkState가 .loaded")
    func loadInitialData_success_setsBookmarkStateLoaded() async {
        let sut = makeSUT()

        await sut.loadInitialData()

        guard case .loaded = sut.bookmarkViewModel.bookmarkState else {
            Issue.record("Expected .loaded but got \(sut.bookmarkViewModel.bookmarkState)")
            return
        }
    }

    @Test("loadInitialData 실패 시 bookmarkState가 .error")
    func loadInitialData_failure_setsBookmarkStateError() async {
        let bookmarkRepo = MockBookmarkRepository()
        bookmarkRepo.stubbedFetchError = TestError.stub
        let sut = MainViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: MockImageSearchRepository()
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo),
            imagePrefetcher: MockImagePrefetcher(),
            networkMonitor: MockNetworkMonitor()
        )

        await sut.loadInitialData()

        guard case .error = sut.bookmarkViewModel.bookmarkState else {
            Issue.record("Expected .error but got \(sut.bookmarkViewModel.bookmarkState)")
            return
        }
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

        // 디바운스 + 검색 완료까지 대기
        let deadline = Date().addingTimeInterval(10)
        while searchRepo.searchCallCount == 0 && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(searchRepo.searchCallCount == 1)
        #expect(searchRepo.lastQuery == "abc")
    }
    
    @Test("검색어 입력 후 바로 리턴을 누르면 검색결과 노출")
    func onSearchSubmit_immediatelySearchesWithoutDebounce() async {
        let searchRepo = MockImageSearchRepository()
        let sut = MainViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: MockBookmarkRepository()),
            imagePrefetcher: MockImagePrefetcher(),
            networkMonitor: MockNetworkMonitor()
        )
        
        sut.searchText = "cat"
        await sut.onSearchSubmit().value
        #expect(searchRepo.lastQuery == "cat")
        #expect(searchRepo.searchCallCount == 1)
    }
    
    @Test("디바운스 대기 중 리턴 누르면 디바운스 취소되고 즉시 검색")
    func onSearchSubmit_cancelsPendingDebounce() async throws {
        let searchRepo = MockImageSearchRepository()
        let sut = MainViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: searchRepo
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: MockBookmarkRepository()),
            imagePrefetcher: MockImagePrefetcher(),
            networkMonitor: MockNetworkMonitor()
        )
        
        sut.onSearchTextChanged("cat")
        sut.searchText = "cat"
        await sut.onSearchSubmit().value
        #expect(searchRepo.lastQuery == "cat")
        try await Task.sleep(for: .seconds(1.5))
        #expect(searchRepo.searchCallCount == 1)
    }
}
