//
//  BookmarkCoordinator.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/17/26.
//

import Foundation
import Observation
import OSLog

/// SearchViewModel과 BookmarkViewModel 사이의 북마크 상태를 조율하는 Presentation 레이어 Coordinator.
/// 동일 인스턴스를 두 ViewModel에 주입해 탭 간 북마크 상태 동기화를 보장한다.
/// ManageBookmarkUseCase를 호출하고, 결과를 UI 상태(배열/Set)로 변환하며, optimistic update와 롤백을 담당한다.
@Observable
@MainActor
final class BookmarkCoordinator {

    private(set) var bookmarkedItems: [ImageItem] = []
    private(set) var inFlightBookmarkIDs: Set<String> = []
    private var loadTask: Task<Void, Error>?

    var bookmarkedIDs: Set<String> {
        Set(bookmarkedItems.map(\.id))
    }

    private let manageBookmarkUseCase: ManageBookmarkUseCase

    init(manageBookmarkUseCase: ManageBookmarkUseCase) {
        self.manageBookmarkUseCase = manageBookmarkUseCase
    }

    func load() async throws {
        if let existing = loadTask {
            try await existing.value
            return
        }

        let task = Task {
            let fetched = try await manageBookmarkUseCase.fetchAll()
            bookmarkedItems = fetched
            Logger.presentation.debugPrint("Loaded \(fetched.count) bookmarks")
        }
        loadTask = task

        do {
            try await task.value
        } catch {
            loadTask = nil
            throw error
        }
    }

    /// loadTask를 초기화하고 다시 fetch. 외부 변경이나 강제 새로고침 시 사용.
    func refresh() async throws {
        loadTask = nil
        try await load()
    }

    func isBookmarked(_ id: String) -> Bool {
        bookmarkedIDs.contains(id)
    }

    @discardableResult
    func toggle(_ item: ImageItem) async -> Result<Bool, Error> {
        guard !inFlightBookmarkIDs.contains(item.id) else {
            return .success(isBookmarked(item.id))
        }

        inFlightBookmarkIDs.insert(item.id)
        defer { inFlightBookmarkIDs.remove(item.id) }

        // 낙관적 업데이트: UI 먼저 토글
        optimisticUpdate(item)

        do {
            let isNowBookmarked = try await manageBookmarkUseCase.toggle(item)
            Logger.presentation.debugPrint("Bookmark toggled: \(item.id) → \(isNowBookmarked)")
            return .success(isNowBookmarked)
        } catch {
            // 실패 시 롤백
            optimisticUpdate(item)
            Logger.presentation.errorPrint("Bookmark toggle failed: \(item.id) — \(error)")
            return .failure(error)
        }
    }

    private func optimisticUpdate(_ item: ImageItem) {
        if let index = bookmarkedItems.firstIndex(where: { $0.id == item.id }) {
            bookmarkedItems.remove(at: index)
        } else {
            var updated = item
            updated.isBookmarked = true
            bookmarkedItems.append(updated)
        }
    }
}
