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
