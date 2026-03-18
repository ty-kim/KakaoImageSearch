//
//  SearchViewModel.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class SearchViewModel {

    private(set) var rawItems: [ImageItem] = []
    private(set) var isLoading: Bool = false
    private(set) var isLoadingMore: Bool = false
    private(set) var isEnd: Bool = false
    private(set) var hasError: Bool = false
    private(set) var hasLoadMoreError: Bool = false
    private(set) var errorMessage: String? = nil
    private(set) var hasSearched: Bool = false
    private(set) var toastMessage: String? = nil

    private var currentQuery: String = ""
    private var currentPage: Int = 1
    private var toastTask: Task<Void, Never>? = nil

    // 추가
    private var searchTask: Task<Void, Never>? = nil
    private var activeSearchID: UUID? = nil

    private let searchImageUseCase: SearchImageUseCase
    private let bookmarkStore: BookmarkStore
    private let imagePrefetcher: any ImagePrefetcher

    var items: [ImageItem] {
        let bookmarkedIDs = bookmarkStore.bookmarkedIDs

        return rawItems.map { item in
            var updated = item
            updated.isBookmarked = bookmarkedIDs.contains(item.id)
            return updated
        }
    }
    
    init(
        searchImageUseCase: SearchImageUseCase,
        bookmarkStore: BookmarkStore,
        imagePrefetcher: any ImagePrefetcher = ImageDownloader.shared
    ) {
        self.searchImageUseCase = searchImageUseCase
        self.bookmarkStore = bookmarkStore
        self.imagePrefetcher = imagePrefetcher
    }

    // MainViewModel에서 debounce 후 호출. retry()도 이 경로를 사용
    func submitSearch(query: String) {
        let searchID = beginSearch(query: query)
        searchTask = Task { [weak self] in
            await self?.performSearch(query: query, searchID: searchID)
        }
    }

    // 테스트에서 직접 await 가능하도록 internal 유지
    func search(query: String) async {
        let searchID = beginSearch(query: query)
        await performSearch(query: query, searchID: searchID)
    }

    private func beginSearch(query: String) -> UUID {
        searchTask?.cancel()

        let searchID = UUID()
        activeSearchID = searchID

        currentQuery = query
        currentPage = 1
        isEnd = false

        isLoading = true
        errorMessage = nil
        hasError = false
        hasLoadMoreError = false
        hasSearched = true

        return searchID
    }

    private func performSearch(query: String, searchID: UUID) async {
        Logger.presentation.debugPrint("Search started: \"\(query)\"")

        defer {
            if activeSearchID == searchID {
                isLoading = false
                searchTask = nil
            }
        }

        do {
            let result = try await searchImageUseCase.execute(query: query, page: 1)

            guard !Task.isCancelled, activeSearchID == searchID else { return }

            rawItems = result.items
            isEnd = result.isEnd

            Logger.presentation.debugPrint("Search completed: \(result.items.count) results, isEnd: \(isEnd)")

            if result.items.isEmpty {
                errorMessage = L10n.Search.emptyNoResults
            } else {
                prefetch(result.items)
            }
        } catch is CancellationError {
            Logger.presentation.debugPrint("Search cancelled: \"\(query)\"")
        } catch {
            guard activeSearchID == searchID else { return }

            rawItems = []
            errorMessage = L10n.Search.error(error.localizedDescription)
            hasError = true

            Logger.presentation.errorPrint("Search failed: \(error)")
        }
    }

    func retry() {
        guard !currentQuery.isEmpty else { return }
        submitSearch(query: currentQuery)
    }

    func loadMore() async {
        // loadMore 실패 후에는 자동 재시도 루프를 막고 버튼으로만 재시도
        guard !isEnd, !isLoading, !isLoadingMore, !hasLoadMoreError else { return }

        let queryAtRequestTime = currentQuery
        let searchIDAtRequestTime = activeSearchID
        let nextPage = currentPage + 1

        hasLoadMoreError = false
        isLoadingMore = true

        Logger.presentation.debugPrint("Loading more: page \(nextPage)")

        defer {
            if searchIDAtRequestTime == activeSearchID,
               queryAtRequestTime == currentQuery {
                isLoadingMore = false
            }
        }

        do {
            let result = try await searchImageUseCase.execute(
                query: queryAtRequestTime,
                page: nextPage
            )

            // 검색어가 이미 바뀌었으면 이전 loadMore 결과 무시
            guard !Task.isCancelled,
                  searchIDAtRequestTime == activeSearchID,
                  queryAtRequestTime == currentQuery else { return }

            rawItems += result.items
            isEnd = result.isEnd
            currentPage = nextPage

            Logger.presentation.debugPrint("Loaded \(result.items.count) more, isEnd: \(isEnd)")

            prefetch(result.items)
        } catch is CancellationError {
            Logger.presentation.debugPrint("Load more cancelled: \(queryAtRequestTime), page \(nextPage)")
        } catch {
            guard searchIDAtRequestTime == activeSearchID,
                  queryAtRequestTime == currentQuery else { return }

            hasLoadMoreError = true
            Logger.presentation.errorPrint("Load more failed: \(error)")
        }
    }

    func retryLoadMore() async {
        hasLoadMoreError = false
        await loadMore()
    }

    func toggleBookmark(for item: ImageItem) async {
        do {
            _ = try await bookmarkStore.toggle(item)
        } catch {
            showToast(L10n.Bookmark.toggleError)
            Logger.presentation.errorPrint("Bookmark toggle failed: \(error)")
        }
    }

    private func prefetch(_ items: [ImageItem]) {
        let urls = items.compactMap(\.thumbnailURL)
        Task(priority: .background) {
            await imagePrefetcher.prefetch(urls: urls)
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message

        toastTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    func cancelSearchAndClear() {
        searchTask?.cancel()
        searchTask = nil
        activeSearchID = nil

        rawItems = []
        errorMessage = nil
        hasError = false
        hasLoadMoreError = false
        hasSearched = false
        isLoading = false
        isLoadingMore = false
        isEnd = false

        currentQuery = ""
        currentPage = 1

        Logger.presentation.debugPrint("Search cancelled and cleared")
    }

}
