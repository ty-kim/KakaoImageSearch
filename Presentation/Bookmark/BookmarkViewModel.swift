//
//  BookmarkViewModel.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import Observation

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
        } catch {
            items = []
        }
        isLoading = false
    }

    func removeBookmark(for item: ImageItem) async {
        do {
            _ = try await manageBookmarkUseCase.toggle(item)
            await loadBookmarks()
        } catch {
            // 북마크 해제 실패 시 무시 (목록 갱신 없음)
        }
    }
}
