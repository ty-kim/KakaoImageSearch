//
//  SearchViewModel.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import Observation
import OSLog

enum SearchState: Equatable {
    case idle
    case loading
    case loaded(PaginationState)
    case empty
    case error(message: String)
}

enum PaginationState: Equatable {
    case idle
    case loadingMore
    case loadMoreError
    case exhausted
    case apiLimitReached
}

@Observable
@MainActor
final class SearchViewModel {

    var items: [ImageItem] { resultsStore.items }
    private(set) var searchState: SearchState = .idle
    private(set) var toastMessage: String? = nil
    private(set) var inFlightBookmarkIDs: Set<String> = []

    private var searchTask: Task<Void, Never>? = nil
    private var loadMoreTask: Task<Void, Never>? = nil
    private var toastTask: Task<Void, Never>? = nil
    private let toastDuration: Duration

    private let flow: SearchFlowController
    private let resultsStore: SearchResultsStore
    private let bookmarkHandler: SearchBookmarkHandler
    private let prefetchCoordinator: SearchPrefetchCoordinator

    init(
        searchImageUseCase: SearchImageUseCase,
        bookmarkStore: BookmarkStore,
        imagePrefetcher: any ImagePrefetcher,
        networkMonitor: any NetworkMonitoring,
        toastDuration: Duration = ToastView.defaultDuration
    ) {
        self.toastDuration = toastDuration
        self.flow = SearchFlowController(searchImageUseCase: searchImageUseCase, networkMonitor: networkMonitor)
        self.resultsStore = SearchResultsStore(bookmarkStore: bookmarkStore)
        self.bookmarkHandler = SearchBookmarkHandler(bookmarkStore: bookmarkStore)
        self.prefetchCoordinator = SearchPrefetchCoordinator(imagePrefetcher: imagePrefetcher, networkMonitor: networkMonitor)
    }

    // MainViewModel에서 debounce 후 호출. retry()도 이 경로를 사용
    // @discardableResult로 반환된 Task를 무시하거나, 테스트에서 .value로 await 가능
    @discardableResult
    func submitSearch(query: String) -> Task<Void, Never> {
        searchTask?.cancel()
        loadMoreTask?.cancel()
        prefetchCoordinator.cancel()

        let searchID = flow.beginSearch(query: query)
        searchState = .loading

        let task = Task { [weak self] in
            guard let self else { return }

            defer {
                if self.flow.isActive(searchID: searchID) {
                    self.searchTask = nil
                }
            }

            do {
                let result = try await self.flow.executeSearch(query: query, searchID: searchID)
                guard let result else { return }

                switch result.searchState {
                case .error:
                    self.searchState = result.searchState
                    Logger.presentation.debugPrint("Search skipped (offline): \"\(query)\"")

                case .empty, .loaded:
                    self.resultsStore.replace(with: result.items)
                    self.searchState = result.searchState

                    if !result.prefetchItems.isEmpty {
                        self.prefetchCoordinator.start(with: result.prefetchItems)
                    }

                    Logger.presentation.debugPrint(
                        "Search completed: \(result.items.count) results"
                    )

                case .idle, .loading:
                    break
                }
            } catch is CancellationError {
                Logger.presentation.debugPrint("Search cancelled: \"\(query)\"")
            } catch {
                guard self.flow.isActive(searchID: searchID) else { return }

                self.resultsStore.clear()
                self.searchState = .error(message: L10n.Search.error(self.serverMessage(from: error)))
                Logger.presentation.errorPrint("Search failed: \(error)")
            }
        }
        searchTask = task
        return task
    }

    @discardableResult
    func retry() -> Task<Void, Never>? {
        guard let query = flow.retryQuery() else { return nil }
        return submitSearch(query: query)
    }

    // @discardableResult로 반환된 Task를 무시하거나, 테스트에서 .value로 await 가능 (submitSearch와 동일 패턴)
    @discardableResult
    func loadMore() -> Task<Void, Never>? {
        guard let request = flow.makeLoadMoreRequest(for: searchState) else { return nil }

        searchState = .loaded(.loadingMore)
        Logger.presentation.debugPrint("Loading more: page \(request.page)")

        let task = Task { [weak self] in
            guard let self else { return }

            defer {
                self.loadMoreTask = nil
            }

            do {
                let result = try await self.flow.executeLoadMore(request)
                guard let result else { return }

                if case .error = result.searchState {
                    self.searchState = .loaded(.loadMoreError)
                    Logger.presentation.debugPrint("Load more skipped (offline)")
                    return
                }

                self.resultsStore.append(result.items)
                self.searchState = result.searchState

                if !result.prefetchItems.isEmpty {
                    self.prefetchCoordinator.start(with: result.prefetchItems)
                }

                Logger.presentation.debugPrint("Loaded \(result.items.count) more, page: \(request.page)")
            } catch is CancellationError {
                Logger.presentation.debugPrint("Load more cancelled: \(request.query), page \(request.page)")
            } catch {
                guard self.flow.matchesCurrent(request: request) else { return }

                self.searchState = .loaded(.loadMoreError)
                Logger.presentation.errorPrint("Load more failed: \(error)")
            }
        }
        loadMoreTask = task
        return task
    }

    @discardableResult
    func retryLoadMore() -> Task<Void, Never>? {
        searchState = .loaded(.idle)
        return loadMore()
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message

        toastTask = Task {
            try? await Task.sleep(for: toastDuration)
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    private func serverMessage(from error: Error) -> String {
        if let searchError = error as? ImageSearchError {
            return searchError.userMessage
        }
        return error.localizedDescription
    }

    func cancelSearchAndClear() {
        searchTask?.cancel()
        searchTask = nil
        loadMoreTask?.cancel()
        loadMoreTask = nil
        prefetchCoordinator.cancel()
        flow.reset()
        resultsStore.clear()
        searchState = .idle

        Logger.presentation.debugPrint("Search cancelled and cleared")
    }
    
    func toggleBookmark(for item: ImageItem) async {
        let outcome = await bookmarkHandler.toggle(item)
        inFlightBookmarkIDs = outcome.inFlightBookmarkIDs

        switch outcome.effect {
        case .updated:
            resultsStore.refresh()
        case .ignored:
            break
        case .failed(let message):
            resultsStore.refresh()
            showToast(message)
            Logger.presentation.errorPrint("Bookmark toggle failed: \(item.id)")
        }
    }
}
