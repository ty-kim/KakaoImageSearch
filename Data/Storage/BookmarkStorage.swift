//
//  BookmarkStorage.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import OSLog

/// FileManager + JSON 파일 기반 북마크 영속성 저장소.
/// actor로 선언해 Swift 6 동시성 안전성을 보장합니다.
/// 저장 경로: <Application Support>/bookmarks.json
actor BookmarkStorage {

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("KakaoImageSearch", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("bookmarks.json")
    }

    func save(_ item: ImageItem) throws {
        var items = try fetchAll()
        guard !items.contains(where: { $0.id == item.id }) else {
            Logger.bookmark.debugPrint("Already bookmarked: \(item.id)")
            return
        }
        items.append(item)
        try persist(items)
        Logger.bookmark.debugPrint("Saved bookmark: \(item.id) (total: \(items.count))")
    }

    func delete(id: String) throws {
        var items = try fetchAll()
        items.removeAll { $0.id == id }
        try persist(items)
        Logger.bookmark.debugPrint("Deleted bookmark: \(id) (total: \(items.count))")
    }

    func fetchAll() throws -> [ImageItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let items = try decoder.decode([ImageItem].self, from: data)
        Logger.bookmark.debugPrint("Fetched \(items.count) bookmarks")
        return items
    }

    func isBookmarked(id: String) throws -> Bool {
        try fetchAll().contains { $0.id == id }
    }

    private func persist(_ items: [ImageItem]) throws {
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
