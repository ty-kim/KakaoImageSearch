//
//  BookmarkStore.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/17/26.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class BookmarkStore {

    private(set) var bookmarkedItems: [ImageItem] = []
    private(set) var bookmarkedIDs: Set<String> = []
    private(set) var isLoading: Bool = false

    private let manageBookmarkUseCase: ManageBookmarkUseCase

    init(manageBookmarkUseCase: ManageBookmarkUseCase) {
        self.manageBookmarkUseCase = manageBookmarkUseCase
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await manageBookmarkUseCase.fetchAll()
            bookmarkedItems = fetched
            bookmarkedIDs = Set(fetched.map(\.id))
            Logger.presentation.debugPrint("Loaded \(fetched.count) bookmarks")
        } catch {
            bookmarkedItems = []
            bookmarkedIDs = []
            Logger.presentation.errorPrint("Load bookmarks failed: \(error)")
        }
    }

    func isBookmarked(_ id: String) -> Bool {
        bookmarkedIDs.contains(id)
    }

    @discardableResult
    func toggle(_ item: ImageItem) async throws -> Bool {
        let isNowBookmarked = try await manageBookmarkUseCase.toggle(item)

        if isNowBookmarked {
            var updated = item
            updated.isBookmarked = true

            if let index = bookmarkedItems.firstIndex(where: { $0.id == item.id }) {
                bookmarkedItems[index] = updated
            } else {
                bookmarkedItems.insert(updated, at: 0)
            }

            bookmarkedIDs.insert(item.id)
        } else {
            bookmarkedItems.removeAll { $0.id == item.id }
            bookmarkedIDs.remove(item.id)
        }

        Logger.presentation.debugPrint("Bookmark toggled: \(item.id) → \(isNowBookmarked)")
        return isNowBookmarked
    }
}
