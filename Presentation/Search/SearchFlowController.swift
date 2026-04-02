//
//  SearchFlowController.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/31/26.
//

import Foundation

struct SearchFlowResult {
    let items: [ImageItem]
    let searchState: SearchState
    let prefetchItems: [ImageItem]
}

struct LoadMoreRequest {
    let query: String
    let searchID: UUID?
    let page: Int
}

@MainActor
final class SearchFlowController {
    private let searchImageUseCase: SearchImageUseCase
    private let networkMonitor: any NetworkMonitoring
    private let maxPage = 15

    private var currentQuery: String = ""
    private var currentPage: Int = 1
    private var activeSearchID: UUID? = nil

    init(
        searchImageUseCase: SearchImageUseCase,
        networkMonitor: any NetworkMonitoring
    ) {
        self.searchImageUseCase = searchImageUseCase
        self.networkMonitor = networkMonitor
    }

    func beginSearch(query: String) -> UUID {
        let searchID = UUID()
        activeSearchID = searchID
        currentQuery = query
        currentPage = 1
        return searchID
    }

    func executeSearch(query: String, searchID: UUID) async throws -> SearchFlowResult? {
        guard networkMonitor.isConnected else {
            return SearchFlowResult(
                items: [],
                searchState: .error(message: L10n.Search.offline),
                prefetchItems: []
            )
        }

        let result = try await searchImageUseCase.execute(query: query, page: 1)

        guard !Task.isCancelled, activeSearchID == searchID else { return nil }

        if result.items.isEmpty {
            return SearchFlowResult(
                items: result.items,
                searchState: .empty,
                prefetchItems: []
            )
        }

        return SearchFlowResult(
            items: result.items,
            searchState: .loaded(paginationState(isEnd: result.isEnd, page: 1)),
            prefetchItems: result.items
        )
    }

    func makeLoadMoreRequest(for currentState: SearchState) -> LoadMoreRequest? {
        guard case .loaded(.idle) = currentState else { return nil }

        return LoadMoreRequest(
            query: currentQuery,
            searchID: activeSearchID,
            page: currentPage + 1
        )
    }

    func executeLoadMore(_ request: LoadMoreRequest) async throws -> SearchFlowResult? {
          guard networkMonitor.isConnected else {
              return SearchFlowResult(
                  items: [],
                  searchState: .error(message: L10n.Search.offline),
                  prefetchItems: []
              )
          }

          let result = try await searchImageUseCase.execute(
              query: request.query,
              page: request.page
          )

          guard !Task.isCancelled,
                request.searchID == activeSearchID,
                request.query == currentQuery else {
              return nil
          }

          currentPage = request.page

          return SearchFlowResult(
              items: result.items,
              searchState: .loaded(
                  paginationState(isEnd: result.isEnd, page: request.page)
              ),
              prefetchItems: result.items
          )
      }

    func retryQuery() -> String? {
        currentQuery.isEmpty ? nil : currentQuery
    }

    func isActive(searchID: UUID) -> Bool {
        activeSearchID == searchID
    }

    func matchesCurrent(request: LoadMoreRequest) -> Bool {
        request.searchID == activeSearchID && request.query == currentQuery
    }

    func reset() {
        currentQuery = ""
        currentPage = 1
        activeSearchID = nil
    }

    private func paginationState(isEnd: Bool, page: Int) -> PaginationState {
        if !isEnd && page >= maxPage { return .apiLimitReached }
        if isEnd || page >= maxPage { return .exhausted }
        return .idle
    }
}
