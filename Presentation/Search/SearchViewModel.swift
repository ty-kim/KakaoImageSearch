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

    private(set) var items: [ImageItem] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String? = nil
    private(set) var hasSearched: Bool = false

    private let searchImageUseCase: SearchImageUseCase
    private let manageBookmarkUseCase: ManageBookmarkUseCase

    init(
        searchImageUseCase: SearchImageUseCase,
        manageBookmarkUseCase: ManageBookmarkUseCase
    ) {
        self.searchImageUseCase = searchImageUseCase
        self.manageBookmarkUseCase = manageBookmarkUseCase
    }

    func search(query: String) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        hasSearched = true
        Logger.presentation.debugPrint("Search started: \"\(query)\"")

        do {
            items = try await searchImageUseCase.execute(query: query)
            Logger.presentation.debugPrint("Search completed: \(items.count) results")
            if items.isEmpty {
                errorMessage = L10n.Search.emptyNoResults
            }
        } catch {
            items = []
            errorMessage = L10n.Search.error(error.localizedDescription)
            Logger.presentation.errorPrint("Search failed: \(error)")
        }

        isLoading = false
    }

    func toggleBookmark(for item: ImageItem) async {
        do {
            let isNowBookmarked = try await manageBookmarkUseCase.toggle(item)
            Logger.presentation.debugPrint("Bookmark toggled: \(item.id) → \(isNowBookmarked)")
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].isBookmarked = isNowBookmarked
            }
        } catch {
            errorMessage = L10n.Search.error(error.localizedDescription)
            Logger.presentation.errorPrint("Bookmark toggle failed: \(error)")
        }
    }

    func clearResults() {
        items = []
        errorMessage = nil
        hasSearched = false
        Logger.presentation.debugPrint("Search results cleared")
    }
}
