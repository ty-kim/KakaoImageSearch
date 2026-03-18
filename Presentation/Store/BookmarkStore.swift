//
//  BookmarkStore.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/17/26.
//

import Foundation
import Observation
import OSLog

/// SearchViewModel과 BookmarkViewModel 사이의 북마크 UI 상태를 공유하기 위한 Presentation 레이어 공유 객체.
/// SwiftUI의 @EnvironmentObject와 동일한 역할로, 동일 인스턴스를 두 ViewModel에 주입해 탭 간 북마크 상태 동기화를 보장한다.
/// 비즈니스 로직은 ManageBookmarkUseCase에 위임하며, 이 클래스는 UseCase 결과를 UI 상태(배열/Set)로 변환하는 역할만 담당한다.
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
                bookmarkedItems.append(updated)
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
