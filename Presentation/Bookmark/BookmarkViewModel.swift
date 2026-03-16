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

    private(set) var items: [ImageItem] = []
    private(set) var isLoading: Bool = false

    private let manageBookmarkUseCase: ManageBookmarkUseCase

    init(manageBookmarkUseCase: ManageBookmarkUseCase) {
        self.manageBookmarkUseCase = manageBookmarkUseCase
    }

    func loadBookmarks() async {
        isLoading = true
        do {
            items = try await manageBookmarkUseCase.fetchAll()
            Logger.presentation.debugPrint("Loaded \(items.count) bookmarks")
        } catch {
            items = []
            Logger.presentation.errorPrint("Load bookmarks failed: \(error)")
        }
        isLoading = false
    }

    func removeBookmark(for item: ImageItem) async {
        do {
            _ = try await manageBookmarkUseCase.toggle(item)
            Logger.presentation.debugPrint("Removed bookmark: \(item.id)")
            await loadBookmarks()
        } catch {
            Logger.presentation.errorPrint("Remove bookmark failed: \(error)")
        }
    }
}
