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

    private var debounceTask: Task<Void, Never>?

    enum Tab {
        case search, bookmark
    }

    init(searchViewModel: SearchViewModel, bookmarkViewModel: BookmarkViewModel) {
        self.searchViewModel = searchViewModel
        self.bookmarkViewModel = bookmarkViewModel
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
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await searchViewModel.search(query: trimmed)
        }
    }
}
