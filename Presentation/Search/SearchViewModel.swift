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

    private let searchImageUseCase: SearchImageUseCase
    private let bookmarkStore: BookmarkStore

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
        bookmarkStore: BookmarkStore
    ) {
        self.searchImageUseCase = searchImageUseCase
        self.bookmarkStore = bookmarkStore
    }

    func search(query: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        hasError = false
        hasLoadMoreError = false
        hasSearched = true
        currentQuery = query
        currentPage = 1
        isEnd = false
        Logger.presentation.debugPrint("Search started: \"\(query)\"")

        do {
            let result = try await searchImageUseCase.execute(query: query, page: 1)
            rawItems = result.items
            isEnd = result.isEnd
            Logger.presentation.debugPrint("Search completed: \(items.count) results, isEnd: \(isEnd)")
            if items.isEmpty {
                errorMessage = L10n.Search.emptyNoResults
            }
        } catch {
            rawItems = []
            errorMessage = L10n.Search.error(error.localizedDescription)
            hasError = true
            Logger.presentation.errorPrint("Search failed: \(error)")
        }

        isLoading = false
    }

    func retry() async {
        await search(query: currentQuery)
    }

    func loadMore() async {
        guard !isEnd, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1
        Logger.presentation.debugPrint("Loading more: page \(nextPage)")

        do {
            let result = try await searchImageUseCase.execute(query: currentQuery, page: nextPage)
            rawItems += result.items
            isEnd = result.isEnd
            currentPage = nextPage
            Logger.presentation.debugPrint("Loaded \(result.items.count) more, isEnd: \(isEnd)")
        } catch {
            hasLoadMoreError = true
            Logger.presentation.errorPrint("Load more failed: \(error)")
        }

        isLoadingMore = false
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

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    func clearResults() {
        rawItems = []
        errorMessage = nil
        hasSearched = false
        Logger.presentation.debugPrint("Search results cleared")
    }
}
