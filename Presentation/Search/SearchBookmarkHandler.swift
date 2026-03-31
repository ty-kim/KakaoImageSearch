//
//  SearchBookmarkHandler.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/31/26.
//

import Foundation

struct SearchBookmarkOutcome {
    let effect: SearchBookmarkEffect
    let inFlightBookmarkIDs: Set<String>
}

enum SearchBookmarkEffect: Equatable {
    case updated
    case ignored
    case failed(message: String)
}

@MainActor
final class SearchBookmarkHandler {
    private let bookmarkStore: BookmarkStore
    private var inFlightBookmarkIDs: Set<String> = []

    init(bookmarkStore: BookmarkStore) {
        self.bookmarkStore = bookmarkStore
    }

    func toggle(_ item: ImageItem) async -> SearchBookmarkOutcome {
        guard !inFlightBookmarkIDs.contains(item.id) else {
            return SearchBookmarkOutcome(
                effect: .ignored,
                inFlightBookmarkIDs: inFlightBookmarkIDs
            )
        }

        inFlightBookmarkIDs.insert(item.id)
        defer { inFlightBookmarkIDs.remove(item.id) }

        do {
            _ = try await bookmarkStore.toggle(item)
            return SearchBookmarkOutcome(
                effect: .updated,
                inFlightBookmarkIDs: inFlightBookmarkIDs.subtracting([item.id])
            )
        } catch {
            return SearchBookmarkOutcome(
                effect: .failed(message: L10n.Bookmark.toggleError),
                inFlightBookmarkIDs: inFlightBookmarkIDs.subtracting([item.id])
            )
        }
    }
}
