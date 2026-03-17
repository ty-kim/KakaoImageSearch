//
//  DefaultBookmarkRepository.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

final class DefaultBookmarkRepository: BookmarkRepository {

    private let storage: BookmarkStorage

    init(storage: BookmarkStorage) {
        self.storage = storage
    }

    func save(_ item: ImageItem) async throws {
        try await storage.save(item)
    }

    func delete(id: String) async throws {
        try await storage.delete(id: id)
    }

    func fetchAll() async throws -> [ImageItem] {
        try await storage.fetchAll()
    }

    func isBookmarked(id: String) async throws -> Bool {
        try await storage.isBookmarked(id: id)
    }
}
