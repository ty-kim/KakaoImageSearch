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
    private let toastDuration: Duration
    private(set) var toastMessage: String? = nil
    private(set) var inFlightBookmarkIDs: Set<String> = []
    private var toastTask: Task<Void, Never>? = nil

    var items: [ImageItem] {
        bookmarkStore.bookmarkedItems
    }

    var isLoading: Bool {
        bookmarkStore.isLoading
    }

    init(bookmarkStore: BookmarkStore, toastDuration: Duration = .seconds(3)) {
        self.bookmarkStore = bookmarkStore
        self.toastDuration = toastDuration
    }

    func loadBookmarks() async {
        do {
            try await bookmarkStore.load()
        } catch {
            showToast(L10n.Bookmark.loadError)
            Logger.presentation.errorPrint("Load bookmarks failed: \(error)")
        }
    }

    func removeBookmark(for item: ImageItem) async {
        guard !inFlightBookmarkIDs.contains(item.id) else { return }
        inFlightBookmarkIDs.insert(item.id)
        defer { inFlightBookmarkIDs.remove(item.id) }

        do {
            _ = try await bookmarkStore.toggle(item)
            Logger.presentation.debugPrint("Removed bookmark: \(item.id)")
        } catch {
            showToast(L10n.Bookmark.toggleError)
            Logger.presentation.errorPrint("Remove bookmark failed: \(error)")
        }
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
}
