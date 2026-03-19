//
//  MainViewModel.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class MainViewModel {

    var searchText: String = ""
    var selectedTab: Tab = .search

    private(set) var searchViewModel: SearchViewModel
    private(set) var bookmarkViewModel: BookmarkViewModel

    private let bookmarkStore: BookmarkStore
    private var debounceTask: Task<Void, Never>?

    enum Tab {
        case search, bookmark
    }

    init(
        searchImageUseCase: SearchImageUseCase,
        manageBookmarkUseCase: ManageBookmarkUseCase
    ) {
        let bookmarkStore = BookmarkStore(manageBookmarkUseCase: manageBookmarkUseCase)

        self.bookmarkStore = bookmarkStore
        self.searchViewModel = SearchViewModel(
            searchImageUseCase: searchImageUseCase,
            bookmarkStore: bookmarkStore
        )
        self.bookmarkViewModel = BookmarkViewModel(
            bookmarkStore: bookmarkStore
        )
    }

    func loadInitialData() async {
        do {
            try await bookmarkStore.load()
        } catch {
            Logger.presentation.errorPrint("Failed to load bookmarks: \(error)")
        }
    }

    func onSearchTextChanged(_ newValue: String) {
        debounceTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            searchViewModel.cancelSearchAndClear()
            return
        }

        Logger.presentation.debugPrint("Debounce queued: \"\(trimmed)\"")

        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled, let self else { return }

            self.searchViewModel.submitSearch(query: trimmed)
        }
    }
}
