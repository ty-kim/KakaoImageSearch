//
//  ManageBookmarkUseCase.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

final class ManageBookmarkUseCase: Sendable {

    private let bookmarkRepository: any BookmarkRepository

    init(bookmarkRepository: some BookmarkRepository) {
        self.bookmarkRepository = bookmarkRepository
    }

    /// 현재 북마크 상태를 반전시킵니다. 변경 후 isBookmarked 값을 반환합니다.
    func toggle(_ item: ImageItem) async throws -> Bool {
        if try await bookmarkRepository.isBookmarked(id: item.id) {
            try await bookmarkRepository.delete(id: item.id)
            return false
        } else {
            var bookmarked = item
            bookmarked.isBookmarked = true
            try await bookmarkRepository.save(bookmarked)
            return true
        }
    }

    func fetchAll() async throws -> [ImageItem] {
        try await bookmarkRepository.fetchAll()
    }
}
