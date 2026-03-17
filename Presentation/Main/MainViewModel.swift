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
        await bookmarkStore.load()
    }

    func onSearchTextChanged(_ newValue: String) {
        debounceTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            searchViewModel.clearResults()
            return
        }

        Logger.presentation.debugPrint("Debounce queued: \"\(trimmed)\"")
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(1.0))
            guard !Task.isCancelled else { return }
            await searchViewModel.search(query: trimmed)
        }
    }
}
