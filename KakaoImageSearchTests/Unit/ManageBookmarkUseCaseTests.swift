//
//  ManageBookmarkUseCaseTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
@testable import KakaoImageSearch

@MainActor
@Suite("ManageBookmarkUseCase")
struct ManageBookmarkUseCaseTests {

    // MARK: - Helpers

    private func makeSUT(
        initialItems: [ImageItem] = []
    ) -> (sut: ManageBookmarkUseCase, repo: MockBookmarkRepository) {
        let repo = MockBookmarkRepository()
        repo.items = initialItems
        let sut = ManageBookmarkUseCase(bookmarkRepository: repo)
        return (sut, repo)
    }

    // MARK: - toggle

    @Test("북마크 안 된 아이템 toggle → 저장하고 true 반환")
    func toggle_unbookmarked_savesAndReturnsTrue() async throws {
        let item = ImageItem.fixture(id: "img-001")
        let (sut, repo) = makeSUT()

        let result = try await sut.toggle(item)

        #expect(result == true)
        #expect(repo.saveCallCount == 1)
        #expect(repo.items.contains { $0.id == "img-001" })
    }

    @Test("북마크 된 아이템 toggle → 삭제하고 false 반환")
    func toggle_bookmarked_deletesAndReturnsFalse() async throws {
        let item = ImageItem.fixture(id: "img-001", isBookmarked: true)
        let (sut, repo) = makeSUT(initialItems: [item])

        let result = try await sut.toggle(item)

        #expect(result == false)
        #expect(repo.deleteCallCount == 1)
        #expect(repo.lastDeletedID == "img-001")
        #expect(!repo.items.contains { $0.id == "img-001" })
    }

    @Test("toggle 저장 시 isBookmarked = true 로 저장됨")
    func toggle_save_setsIsBookmarkedTrue() async throws {
        let item = ImageItem.fixture(id: "img-002", isBookmarked: false)
        let (sut, repo) = makeSUT()

        _ = try await sut.toggle(item)

        let saved = try #require(repo.items.first { $0.id == "img-002" })
        #expect(saved.isBookmarked == true)
    }

    @Test("두 번 toggle 하면 원래 상태로 복귀")
    func toggle_twice_restoresOriginalState() async throws {
        let item = ImageItem.fixture(id: "img-003")
        let (sut, _) = makeSUT()

        let first = try await sut.toggle(item)
        let second = try await sut.toggle(item)

        #expect(first == true)
        #expect(second == false)
    }

    @Test("동일 아이템 두 번 toggle(add) 시 중복 저장 안 됨")
    func toggle_duplicateSave_notDuplicated() async throws {
        let item = ImageItem.fixture(id: "img-dup")
        let (sut, repo) = makeSUT()

        _ = try await sut.toggle(item)  // 저장
        _ = try await sut.toggle(item)  // 삭제
        _ = try await sut.toggle(item)  // 재저장

        #expect(repo.items.filter { $0.id == "img-dup" }.count == 1)
    }

    @Test("fetchAll 아이템 없을 때 빈 배열 반환")
    func fetchAll_emptyRepository_returnsEmpty() async throws {
        let (sut, _) = makeSUT(initialItems: [])

        let result = try await sut.fetchAll()

        #expect(result.isEmpty)
    }

    @Test("save 에러 시 throws 전파")
    func toggle_saveError_throws() async throws {
        let item = ImageItem.fixture(id: "img-004")
        let (sut, repo) = makeSUT()
        repo.stubbedSaveError = TestError.stub

        await #expect(throws: TestError.self) {
            try await sut.toggle(item)
        }
    }

    @Test("delete 에러 시 throws 전파")
    func toggle_deleteError_throws() async throws {
        let item = ImageItem.fixture(id: "img-005", isBookmarked: true)
        let (sut, repo) = makeSUT(initialItems: [item])
        repo.stubbedDeleteError = TestError.stub

        await #expect(throws: TestError.self) {
            try await sut.toggle(item)
        }
    }

    // MARK: - fetchAll

    @Test("fetchAll 은 Repository 아이템 그대로 반환")
    func fetchAll_returnsAllItems() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _) = makeSUT(initialItems: items)

        let result = try await sut.fetchAll()

        #expect(result.count == 2)
        #expect(result.map(\.id) == ["a", "b"])
    }

    @Test("fetchAll fetch 에러 시 throws 전파")
    func fetchAll_fetchError_throws() async throws {
        let (sut, repo) = makeSUT()
        repo.stubbedFetchError = TestError.stub

        await #expect(throws: TestError.self) {
            try await sut.fetchAll()
        }
    }
}
