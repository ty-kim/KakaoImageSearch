//
//  SearchFlowControllerTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/31/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

@MainActor
@Suite("SearchFlowController")
struct SearchFlowControllerTests {

    private func makeSUT() -> (sut: SearchFlowController, searchRepo: MockImageSearchRepository, networkMonitor: MockNetworkMonitor) {
        let searchRepo = MockImageSearchRepository()
        let networkMonitor = MockNetworkMonitor()
        let sut = SearchFlowController(
            searchImageUseCase: SearchImageUseCase(imageSearchRepository: searchRepo),
            networkMonitor: networkMonitor
        )
        return (sut, searchRepo, networkMonitor)
    }

    // MARK: - beginSearch

    @Test("beginSearch — 고유한 searchID 반환")
    func beginSearch_returnsUniqueID() {
        let (sut, _, _) = makeSUT()
        let id1 = sut.beginSearch(query: "cat")
        let id2 = sut.beginSearch(query: "dog")
        #expect(id1 != id2)
    }

    @Test("beginSearch — isActive가 최신 searchID에 대해 true")
    func beginSearch_activatesLatestID() {
        let (sut, _, _) = makeSUT()
        let id1 = sut.beginSearch(query: "cat")
        let id2 = sut.beginSearch(query: "dog")
        #expect(!sut.isActive(searchID: id1))
        #expect(sut.isActive(searchID: id2))
    }

    // MARK: - executeSearch

    @Test("executeSearch — 오프라인이면 에러 상태 반환")
    func executeSearch_offline_returnsError() async throws {
        let (sut, _, networkMonitor) = makeSUT()
        networkMonitor.isConnected = false
        let searchID = sut.beginSearch(query: "cat")

        let result = try await sut.executeSearch(query: "cat", searchID: searchID)

        #expect(result != nil)
        #expect(result?.searchState == .error(message: L10n.Search.offline))
        #expect(result?.items.isEmpty == true)
    }

    @Test("executeSearch — 결과 있으면 loaded 상태 반환")
    func executeSearch_withResults_returnsLoaded() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1"), .fixture(id: "2")]
        let searchID = sut.beginSearch(query: "cat")

        let result = try await sut.executeSearch(query: "cat", searchID: searchID)

        #expect(result?.items.count == 2)
        #expect(result?.searchState == .loaded(.idle))
    }

    @Test("executeSearch — 결과 비면 empty 상태 반환")
    func executeSearch_emptyResults_returnsEmpty() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = []
        let searchID = sut.beginSearch(query: "cat")

        let result = try await sut.executeSearch(query: "cat", searchID: searchID)

        #expect(result?.items.isEmpty == true)
        #expect(result?.searchState == .empty)
    }

    @Test("executeSearch — searchID 불일치 시 nil 반환")
    func executeSearch_staleID_returnsNil() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1")]
        let staleID = sut.beginSearch(query: "cat")
        _ = sut.beginSearch(query: "dog")

        let result = try await sut.executeSearch(query: "cat", searchID: staleID)

        #expect(result == nil)
    }

    @Test("executeSearch — isEnd이면 exhausted 반환")
    func executeSearch_isEnd_returnsExhausted() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1")]
        searchRepo.stubbedIsEnd = true
        let searchID = sut.beginSearch(query: "cat")

        let result = try await sut.executeSearch(query: "cat", searchID: searchID)

        #expect(result?.searchState == .loaded(.exhausted))
    }

    @Test("executeSearch — prefetchItems에 검색 결과 포함")
    func executeSearch_returnsPrefetchItems() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1"), .fixture(id: "2")]
        let searchID = sut.beginSearch(query: "cat")

        let result = try await sut.executeSearch(query: "cat", searchID: searchID)

        #expect(result?.prefetchItems.count == 2)
    }

    // MARK: - makeLoadMoreRequest

    @Test("makeLoadMoreRequest — loaded(.idle)이면 요청 생성")
    func makeLoadMoreRequest_idleLoaded_returnsRequest() {
        let (sut, _, _) = makeSUT()
        _ = sut.beginSearch(query: "cat")

        let request = sut.makeLoadMoreRequest(for: .loaded(.idle))

        #expect(request != nil)
        #expect(request?.query == "cat")
        #expect(request?.page == 2)
    }

    @Test("makeLoadMoreRequest — loading 상태에서는 nil")
    func makeLoadMoreRequest_loading_returnsNil() {
        let (sut, _, _) = makeSUT()
        _ = sut.beginSearch(query: "cat")

        let request = sut.makeLoadMoreRequest(for: .loading)

        #expect(request == nil)
    }

    @Test("makeLoadMoreRequest — exhausted 상태에서는 nil")
    func makeLoadMoreRequest_exhausted_returnsNil() {
        let (sut, _, _) = makeSUT()
        _ = sut.beginSearch(query: "cat")

        let request = sut.makeLoadMoreRequest(for: .loaded(.exhausted))

        #expect(request == nil)
    }

    // MARK: - executeLoadMore

    @Test("executeLoadMore — 오프라인이면 에러 상태 반환")
    func executeLoadMore_offline_returnsError() async throws {
        let (sut, searchRepo, networkMonitor) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1")]
        let searchID = sut.beginSearch(query: "cat")
        _ = try await sut.executeSearch(query: "cat", searchID: searchID)

        networkMonitor.isConnected = false
        let request = LoadMoreRequest(query: "cat", searchID: searchID, page: 2)
        let result = try await sut.executeLoadMore(request)

        #expect(result?.searchState == .error(message: L10n.Search.offline))
        #expect(result?.items.isEmpty == true)
    }

    @Test("executeLoadMore — 성공 시 items와 상태 반환")
    func executeLoadMore_success_returnsResult() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1")]
        let searchID = sut.beginSearch(query: "cat")
        // page 1 실행해서 currentPage 설정
        _ = try await sut.executeSearch(query: "cat", searchID: searchID)

        searchRepo.stubbedResult = [.fixture(id: "2"), .fixture(id: "3")]
        let request = LoadMoreRequest(query: "cat", searchID: searchID, page: 2)
        let result = try await sut.executeLoadMore(request)

        #expect(result?.items.count == 2)
        #expect(result?.searchState == .loaded(.idle))
    }

    @Test("executeLoadMore — searchID 불일치 시 nil")
    func executeLoadMore_staleID_returnsNil() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1")]
        let staleID = sut.beginSearch(query: "cat")
        _ = sut.beginSearch(query: "dog")

        let request = LoadMoreRequest(query: "cat", searchID: staleID, page: 2)
        let result = try await sut.executeLoadMore(request)

        #expect(result == nil)
    }

    @Test("executeLoadMore — page 15이고 isEnd=false이면 apiLimitReached")
    func executeLoadMore_page15_apiLimitReached() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1")]
        searchRepo.stubbedIsEnd = false
        let searchID = sut.beginSearch(query: "cat")

        let request = LoadMoreRequest(query: "cat", searchID: searchID, page: 15)
        let result = try await sut.executeLoadMore(request)

        #expect(result?.searchState == .loaded(.apiLimitReached))
    }

    @Test("executeLoadMore — isEnd이면 exhausted")
    func executeLoadMore_isEnd_exhausted() async throws {
        let (sut, searchRepo, _) = makeSUT()
        searchRepo.stubbedResult = [.fixture(id: "1")]
        searchRepo.stubbedIsEnd = true
        let searchID = sut.beginSearch(query: "cat")

        let request = LoadMoreRequest(query: "cat", searchID: searchID, page: 5)
        let result = try await sut.executeLoadMore(request)

        #expect(result?.searchState == .loaded(.exhausted))
    }

    // MARK: - retryQuery

    @Test("retryQuery — 쿼리 있으면 반환")
    func retryQuery_withQuery_returnsQuery() {
        let (sut, _, _) = makeSUT()
        _ = sut.beginSearch(query: "cat")

        #expect(sut.retryQuery() == "cat")
    }

    @Test("retryQuery — 쿼리 없으면 nil")
    func retryQuery_empty_returnsNil() {
        let (sut, _, _) = makeSUT()

        #expect(sut.retryQuery() == nil)
    }

    // MARK: - reset

    @Test("reset — 상태 초기화")
    func reset_clearsState() {
        let (sut, _, _) = makeSUT()
        let searchID = sut.beginSearch(query: "cat")

        sut.reset()

        #expect(!sut.isActive(searchID: searchID))
        #expect(sut.retryQuery() == nil)
        #expect(sut.makeLoadMoreRequest(for: .loaded(.idle))?.query == "")
    }

    // MARK: - matchesCurrent

    @Test("matchesCurrent — 일치하면 true")
    func matchesCurrent_matching_returnsTrue() {
        let (sut, _, _) = makeSUT()
        let searchID = sut.beginSearch(query: "cat")
        let request = LoadMoreRequest(query: "cat", searchID: searchID, page: 2)

        #expect(sut.matchesCurrent(request: request))
    }

    @Test("matchesCurrent — 쿼리 다르면 false")
    func matchesCurrent_differentQuery_returnsFalse() {
        let (sut, _, _) = makeSUT()
        let searchID = sut.beginSearch(query: "cat")
        let request = LoadMoreRequest(query: "dog", searchID: searchID, page: 2)

        #expect(!sut.matchesCurrent(request: request))
    }
}
