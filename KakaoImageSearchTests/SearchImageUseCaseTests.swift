//
//  SearchImageUseCaseTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

@MainActor
@Suite("SearchImageUseCase")
struct SearchImageUseCaseTests {

    // MARK: - Helpers

    private func makeSUT(
        searchItems: [ImageItem] = [],
        bookmarkedItems: [ImageItem] = [],
        searchError: Error? = nil
    ) -> (sut: SearchImageUseCase, searchRepo: MockImageSearchRepository, bookmarkRepo: MockBookmarkRepository) {
        let searchRepo = MockImageSearchRepository()
        searchRepo.stubbedResult = searchItems
        searchRepo.stubbedError = searchError

        let bookmarkRepo = MockBookmarkRepository()
        bookmarkRepo.items = bookmarkedItems

        let sut = SearchImageUseCase(
            imageSearchRepository: searchRepo,
            bookmarkRepository: bookmarkRepo
        )
        return (sut, searchRepo, bookmarkRepo)
    }

    // MARK: - Tests

    @Test("북마크 없으면 모든 아이템 isBookmarked = false")
    func execute_noBookmarks_allUnbookmarked() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _, _) = makeSUT(searchItems: items)

        let result = try await sut.execute(query: "cat")

        #expect(result.count == 2)
        #expect(result.allSatisfy { !$0.isBookmarked })
    }

    @Test("북마크된 id와 일치하는 아이템은 isBookmarked = true")
    func execute_withBookmarks_mergesBookmarkState() async throws {
        let itemA = ImageItem.fixture(id: "a")
        let itemB = ImageItem.fixture(id: "b")
        let bookmarked = ImageItem.fixture(id: "a", isBookmarked: true)

        let (sut, _, _) = makeSUT(searchItems: [itemA, itemB], bookmarkedItems: [bookmarked])

        let result = try await sut.execute(query: "cat")

        let resultA = try #require(result.first { $0.id == "a" })
        let resultB = try #require(result.first { $0.id == "b" })
        #expect(resultA.isBookmarked == true)
        #expect(resultB.isBookmarked == false)
    }

    @Test("검색 결과가 비어있으면 빈 배열 반환")
    func execute_emptyResult_returnsEmpty() async throws {
        let (sut, _, _) = makeSUT(searchItems: [])

        let result = try await sut.execute(query: "zzz")

        #expect(result.isEmpty)
    }

    @Test("검색 Repository 에러 시 throws")
    func execute_searchRepositoryError_throws() async throws {
        let (sut, _, _) = makeSUT(searchError: URLError(.notConnectedToInternet))

        await #expect(throws: URLError.self) {
            try await sut.execute(query: "cat")
        }
    }

    @Test("북마크 Repository 에러 시 throws")
    func execute_bookmarkRepositoryError_throws() async throws {
        let (sut, _, bookmarkRepo) = makeSUT(searchItems: [ImageItem.fixture()])
        bookmarkRepo.stubbedFetchError = TestError.stub

        await #expect(throws: TestError.self) {
            try await sut.execute(query: "cat")
        }
    }

    @Test("검색 결과 전체가 북마크된 경우 모두 isBookmarked = true")
    func execute_allItemsBookmarked_allMarkedTrue() async throws {
        let itemA = ImageItem.fixture(id: "a")
        let itemB = ImageItem.fixture(id: "b")
        let (sut, _, _) = makeSUT(
            searchItems: [itemA, itemB],
            bookmarkedItems: [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        )

        let result = try await sut.execute(query: "cat")

        #expect(result.allSatisfy { $0.isBookmarked })
    }

    @Test("쿼리 문자열이 Repository에 올바르게 전달됨")
    func execute_passesQueryToRepository() async throws {
        let (sut, searchRepo, _) = makeSUT()

        _ = try await sut.execute(query: "고양이")

        #expect(searchRepo.lastQuery == "고양이")
    }
}
