//
//  BookmarkStore.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 4/2/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

// MARK: - BookmarkStore

@MainActor
@Suite("BookmarkStore")
struct BookmarkStoreTests {

    private func makeSUT(
        initialItems: [ImageItem] = [],
        fetchError: Error? = nil
    ) -> (sut: BookmarkStore, repo: MockBookmarkRepository) {
        let repo = MockBookmarkRepository()
        repo.items = initialItems
        repo.stubbedFetchError = fetchError
        let sut = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: repo)
        )
        return (sut, repo)
    }

    @Test("load 성공 시 bookmarkedItems, bookmarkedIDs 설정")
    func load_success_setsItemsAndIDs() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _) = makeSUT(initialItems: items)

        try await sut.load()

        #expect(sut.bookmarkedItems.count == 2)
        #expect(sut.bookmarkedIDs == ["a", "b"])
    }

    @Test("load 실패 시 에러 throw")
    func load_failure_throws() async {
        let (sut, _) = makeSUT(fetchError: TestError.stub)

        await #expect(throws: TestError.stub) {
            try await sut.load()
        }
    }

    @Test("toggle 북마크 추가 시 bookmarkedItems, bookmarkedIDs에 반영")
    func toggle_add_updatesItemsAndIDs() async throws {
        let item = ImageItem.fixture(id: "a")
        let (sut, _) = makeSUT()

        _ = try await sut.toggle(item)

        #expect(sut.bookmarkedIDs.contains("a"))
        #expect(sut.bookmarkedItems.contains { $0.id == "a" })
    }

    @Test("toggle 북마크 제거 시 bookmarkedItems, bookmarkedIDs에서 삭제")
    func toggle_remove_updatesItemsAndIDs() async throws {
        let item = ImageItem.fixture(id: "a", isBookmarked: true)
        let (sut, _) = makeSUT(initialItems: [item])
        try await sut.load()

        _ = try await sut.toggle(item)

        #expect(!sut.bookmarkedIDs.contains("a"))
        #expect(!sut.bookmarkedItems.contains { $0.id == "a" })
    }

    @Test("isBookmarked: bookmarkedIDs 기반으로 판별")
    func isBookmarked_returnsCorrectState() async throws {
        let item = ImageItem.fixture(id: "a", isBookmarked: true)
        let (sut, _) = makeSUT(initialItems: [item])
        try await sut.load()

        #expect(sut.isBookmarked("a") == true)
        #expect(sut.isBookmarked("z") == false)
    }

    @Test("같은 아이템을 연속 toggle 시 add→remove로 최종 상태 일관")
    func toggle_sameTwice_addsAndRemoves() async throws {
        let item = ImageItem.fixture(id: "a")
        let (sut, _) = makeSUT()

        let first = try await sut.toggle(item)
        #expect(first == true)
        #expect(sut.bookmarkedIDs.contains("a"))

        let second = try await sut.toggle(item)
        #expect(second == false)
        #expect(!sut.bookmarkedIDs.contains("a"))
        #expect(sut.bookmarkedItems.isEmpty)
    }
}
