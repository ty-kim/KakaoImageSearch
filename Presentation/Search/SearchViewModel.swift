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
    private(set) var errorMessage: String? = nil
    private(set) var hasSearched: Bool = false

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
        hasSearched = true
        Logger.presentation.debugPrint("Search started: \"\(query)\"")

        do {
            rawItems = try await searchImageUseCase.execute(query: query)
            Logger.presentation.debugPrint("Search completed: \(items.count) results")
            if items.isEmpty {
                errorMessage = L10n.Search.emptyNoResults
            }
        } catch {
            rawItems = []
            errorMessage = L10n.Search.error(error.localizedDescription)
            Logger.presentation.errorPrint("Search failed: \(error)")
        }

        isLoading = false
    }

    func toggleBookmark(for item: ImageItem) async {
        do {
            _ = try await bookmarkStore.toggle(item)
        } catch {
            errorMessage = L10n.Search.error(error.localizedDescription)
            Logger.presentation.errorPrint("Bookmark toggle failed: \(error)")
        }
    }

    func clearResults() {
        rawItems = []
        errorMessage = nil
        hasSearched = false
        Logger.presentation.debugPrint("Search results cleared")
    }
}
