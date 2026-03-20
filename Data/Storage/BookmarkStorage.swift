//
//  BookmarkStorage.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import SwiftData
import OSLog

/// SwiftData 기반 북마크 영속성 저장소.
/// @ModelActor로 선언해 Swift 6 동시성 안전성을 보장합니다.
@ModelActor
actor BookmarkStorage {

    func save(_ item: ImageItem) throws {
        let id = item.id
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard try modelContext.fetchCount(descriptor) == 0 else {
            Logger.bookmark.debugPrint("Already bookmarked: \(item.id)")
            return
        }
        modelContext.insert(BookmarkEntity(from: item))
        try modelContext.save()
        Logger.bookmark.debugPrint("Saved bookmark: \(item.id)")
    }

    func delete(id: String) throws {
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }
        try modelContext.save()
        Logger.bookmark.debugPrint("Deleted bookmark: \(id)")
    }

    func fetchAll() throws -> [ImageItem] {
        let descriptor = FetchDescriptor<BookmarkEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        Logger.bookmark.debugPrint("Fetched \(entities.count) bookmarks")
        return entities.map { $0.toImageItem() }
    }

    func isBookmarked(id: String) throws -> Bool {
        let descriptor = FetchDescriptor<BookmarkEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetchCount(descriptor) > 0
    }
}
