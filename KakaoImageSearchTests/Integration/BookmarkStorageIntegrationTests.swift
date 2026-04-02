//
//  BookmarkStorageIntegrationTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
import Foundation
import SwiftData
@testable import KakaoImageSearch

@MainActor
@Suite("BookmarkStorage 통합 테스트", .serialized)
struct BookmarkStorageIntegrationTests {

    // MARK: - Helpers

    private func makeStorage() throws -> BookmarkStorage {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: BookmarkEntity.self, configurations: config)
        return BookmarkStorage(modelContainer: container)
    }

    private func makeOnDiskStorage(url: URL) throws -> (BookmarkStorage, ModelContainer) {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: BookmarkEntity.self, configurations: config)
        return (BookmarkStorage(modelContainer: container), container)
    }

    // MARK: - fetchAll

    @Test("비어있을 때 fetchAll은 빈 배열을 반환한다")
    func fetchAll_empty_returnsEmpty() async throws {
        let sut = try makeStorage()
        let result = try await sut.fetchAll()
        #expect(result.isEmpty)
    }

    // MARK: - save

    @Test("save 후 fetchAll하면 저장된 아이템이 포함된다")
    func save_thenFetchAll_containsSavedItem() async throws {
        let sut = try makeStorage()
        let item = ImageItem.fixture(id: "img-save-test")

        try await sut.save(item)
        let result = try await sut.fetchAll()

        #expect(result.count == 1)
        #expect(result.first?.id == "img-save-test")
    }

    @Test("동일한 아이템을 두 번 save해도 중복 저장되지 않는다")
    func save_duplicate_notDuplicated() async throws {
        let sut = try makeStorage()
        let item = ImageItem.fixture()

        try await sut.save(item)
        try await sut.save(item)
        let result = try await sut.fetchAll()

        #expect(result.count == 1)
    }

    @Test("여러 아이템을 save하면 모두 저장된다")
    func save_multipleItems_allPersisted() async throws {
        let sut = try makeStorage()
        let items = (1...3).map { ImageItem.fixture(id: "id-\($0)") }

        for item in items { try await sut.save(item) }
        let result = try await sut.fetchAll()

        #expect(result.count == 3)
        #expect(Set(result.map(\.id)) == Set(["id-1", "id-2", "id-3"]))
    }

    // MARK: - delete

    @Test("save 후 delete하면 fetchAll에서 사라진다")
    func delete_savedItem_removedFromFetchAll() async throws {
        let sut = try makeStorage()
        let item = ImageItem.fixture()

        try await sut.save(item)
        try await sut.delete(id: item.id)
        let result = try await sut.fetchAll()

        #expect(result.isEmpty)
    }

    @Test("존재하지 않는 id를 delete해도 오류가 발생하지 않는다")
    func delete_nonExistentID_noError() async throws {
        let sut = try makeStorage()
        try await sut.delete(id: "ghost-id")
        let result = try await sut.fetchAll()
        #expect(result.isEmpty)
    }

    @Test("여러 아이템 중 하나만 delete하면 나머지는 유지된다")
    func delete_oneOfMany_othersRemain() async throws {
        let sut = try makeStorage()
        try await sut.save(ImageItem.fixture(id: "id-1"))
        try await sut.save(ImageItem.fixture(id: "id-2"))
        try await sut.save(ImageItem.fixture(id: "id-3"))

        try await sut.delete(id: "id-2")
        let result = try await sut.fetchAll()

        #expect(result.count == 2)
        #expect(!result.contains { $0.id == "id-2" })
        #expect(result.contains { $0.id == "id-1" })
        #expect(result.contains { $0.id == "id-3" })
    }

    // MARK: - isBookmarked

    @Test("저장된 아이템은 isBookmarked가 true를 반환한다")
    func isBookmarked_savedItem_returnsTrue() async throws {
        let sut = try makeStorage()
        let item = ImageItem.fixture()

        try await sut.save(item)
        let result = try await sut.isBookmarked(id: item.id)

        #expect(result == true)
    }

    @Test("저장하지 않은 아이템은 isBookmarked가 false를 반환한다")
    func isBookmarked_unsavedItem_returnsFalse() async throws {
        let sut = try makeStorage()
        let result = try await sut.isBookmarked(id: "no-such-id")
        #expect(result == false)
    }

    @Test("delete 후 isBookmarked는 false를 반환한다")
    func isBookmarked_afterDelete_returnsFalse() async throws {
        let sut = try makeStorage()
        let item = ImageItem.fixture()

        try await sut.save(item)
        try await sut.delete(id: item.id)
        let result = try await sut.isBookmarked(id: item.id)

        #expect(result == false)
    }

    // MARK: - 영속성

    @Test("저장된 데이터는 새 인스턴스(앱 재시작 시뮬레이션)에서도 읽힌다")
    func persistence_newInstance_canReadSavedData() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let storeURL = dir.appendingPathComponent("bookmarks.store")

        let item = ImageItem.fixture(id: "persist-id")
        let (first, _) = try makeOnDiskStorage(url: storeURL)
        try await first.save(item)

        let (second, _) = try makeOnDiskStorage(url: storeURL)
        let result = try await second.fetchAll()

        #expect(result.count == 1)
        #expect(result.first?.id == "persist-id")
    }

    // MARK: - 필드 보존

    @Test("저장된 데이터는 모든 ImageItem 필드를 보존한다")
    func persistence_roundTrip_preservesAllFields() async throws {
        let sut = try makeStorage()
        let item = ImageItem.fixture(
            id: "round-trip-id",
            imageURL: URL(string: "https://example.com/img.jpg"),
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            width: 1920,
            height: 1080,
            displaySitename: "Naver Blog",
            datetime: Date(timeIntervalSince1970: 1704034800),
            isBookmarked: true
        )

        try await sut.save(item)
        let result = try await sut.fetchAll()
        let loaded = try #require(result.first)

        #expect(loaded.id == item.id)
        #expect(loaded.imageURL == item.imageURL)
        #expect(loaded.thumbnailURL == item.thumbnailURL)
        #expect(loaded.width == item.width)
        #expect(loaded.height == item.height)
        #expect(loaded.displaySitename == item.displaySitename)
        #expect(loaded.datetime == item.datetime)
    }
}
