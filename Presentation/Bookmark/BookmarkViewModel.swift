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

    private let bookmarkStore: BookmarkStore

    var items: [ImageItem] {
        bookmarkStore.bookmarkedItems
    }

    var isLoading: Bool {
        bookmarkStore.isLoading
    }

    init(bookmarkStore: BookmarkStore) {
        self.bookmarkStore = bookmarkStore
    }

    func loadBookmarks() async {
        await bookmarkStore.load()
    }

    func removeBookmark(for item: ImageItem) async {
        do {
            _ = try await bookmarkStore.toggle(item)
            Logger.presentation.debugPrint("Removed bookmark: \(item.id)")
        } catch {
            Logger.presentation.errorPrint("Remove bookmark failed: \(error)")
        }
    }
}
