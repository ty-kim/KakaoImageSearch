//
//  BookmarkViewModel.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class BookmarkViewModel {

    enum BookmarkState {
        case idle
        case loading
        case loaded
        case error(message: String)
    }

    private let bookmarkStore: BookmarkStore
    let toast: ToastState
    private(set) var bookmarkState: BookmarkState = .idle

    var items: [ImageItem] {
        bookmarkStore.bookmarkedItems
    }

    var toastMessage: String? {
        toast.message
    }

    init(bookmarkStore: BookmarkStore, toastDuration: Duration = ToastView.defaultDuration) {
        self.bookmarkStore = bookmarkStore
        self.toast = ToastState(duration: toastDuration)
    }

    func loadBookmarks() async {
        bookmarkState = .loading
        do {
            try await bookmarkStore.load()
            bookmarkState = .loaded
        } catch {
            bookmarkState = .error(message: L10n.Bookmark.loadError)
            Logger.presentation.errorPrint("Load bookmarks failed: \(error)")
        }
    }

    func retryLoadBookmarks() {
        Task { await loadBookmarks() }
    }

    var inFlightBookmarkIDs: Set<String> {
        bookmarkStore.inFlightBookmarkIDs
    }

    func toggleBookmark(for item: ImageItem) async {
        let result = await bookmarkStore.toggle(item)

        if case .failure = result {
            toast.show(L10n.Bookmark.toggleError)
            Logger.presentation.errorPrint("Toggle bookmark failed: \(item.id)")
        }
    }
}
