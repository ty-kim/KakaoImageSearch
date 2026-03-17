//
//  Mocks.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Foundation
@testable import KakaoImageSearch

// MARK: - MockImageSearchRepository

final class MockImageSearchRepository: ImageSearchRepository, @unchecked Sendable {
    var stubbedResult: [ImageItem] = []
    var stubbedIsEnd: Bool = false
    var stubbedError: Error?
    private(set) var searchCallCount = 0
    private(set) var lastQuery: String?
    private(set) var lastPage: Int?

    func search(query: String, page: Int) async throws -> SearchResultPage {
        searchCallCount += 1
        lastQuery = query
        lastPage = page
        if let error = stubbedError { throw error }
        return SearchResultPage(items: stubbedResult, isEnd: stubbedIsEnd)
    }
}

// MARK: - MockBookmarkRepository

final class MockBookmarkRepository: BookmarkRepository, @unchecked Sendable {
    var items: [ImageItem] = []
    var stubbedSaveError: Error?
    var stubbedDeleteError: Error?
    var stubbedFetchError: Error?
    private(set) var saveCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var lastDeletedID: String?

    func save(_ item: ImageItem) async throws {
        if let error = stubbedSaveError { throw error }
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        saveCallCount += 1
    }

    func delete(id: String) async throws {
        if let error = stubbedDeleteError { throw error }
        items.removeAll { $0.id == id }
        deleteCallCount += 1
        lastDeletedID = id
    }

    func fetchAll() async throws -> [ImageItem] {
        if let error = stubbedFetchError { throw error }
        return items
    }

    func isBookmarked(id: String) async throws -> Bool {
        items.contains { $0.id == id }
    }
}

// MARK: - TestError

enum TestError: Error {
    case stub
}

// MARK: - Fixture

extension ImageItem {
    static func fixture(
        id: String = "img-001",
        imageURL: URL? = URL(string: "https://example.com/image.jpg"),
        thumbnailURL: URL? = URL(string: "https://example.com/thumb.jpg"),
        width: Int? = 800,
        height: Int? = 600,
        isBookmarked: Bool = false
    ) -> ImageItem {
        ImageItem(
            id: id,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            width: width,
            height: height,
            isBookmarked: isBookmarked
        )
    }
}
