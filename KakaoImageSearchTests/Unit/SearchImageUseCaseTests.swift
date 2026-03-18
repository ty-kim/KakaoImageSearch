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
        searchError: Error? = nil
    ) -> (sut: SearchImageUseCase, searchRepo: MockImageSearchRepository) {
        let searchRepo = MockImageSearchRepository()
        searchRepo.stubbedResult = searchItems
        searchRepo.stubbedError = searchError

        let sut = SearchImageUseCase(imageSearchRepository: searchRepo)
        return (sut, searchRepo)
    }

    // MARK: - Tests

    @Test("검색 성공 시 결과 아이템 반환")
    func execute_success_returnsItems() async throws {
        let items = [ImageItem.fixture(id: "a"), ImageItem.fixture(id: "b")]
        let (sut, _) = makeSUT(searchItems: items)

        let result = try await sut.execute(query: "cat")

        #expect(result.items.count == 2)
    }

    @Test("검색 결과가 비어있으면 빈 배열 반환")
    func execute_emptyResult_returnsEmpty() async throws {
        let (sut, _) = makeSUT(searchItems: [])

        let result = try await sut.execute(query: "zzz")

        #expect(result.items.isEmpty)
    }

    @Test("검색 Repository 에러 시 throws")
    func execute_searchRepositoryError_throws() async throws {
        let (sut, _) = makeSUT(searchError: URLError(.notConnectedToInternet))

        await #expect(throws: URLError.self) {
            try await sut.execute(query: "cat")
        }
    }

    @Test("쿼리 문자열이 Repository에 올바르게 전달됨")
    func execute_passesQueryToRepository() async throws {
        let (sut, searchRepo) = makeSUT()

        _ = try await sut.execute(query: "고양이")

        #expect(searchRepo.lastQuery == "고양이")
    }

    @Test("page 파라미터가 Repository에 올바르게 전달됨")
    func execute_passesPageToRepository() async throws {
        let (sut, searchRepo) = makeSUT()

        _ = try await sut.execute(query: "cat", page: 3)

        #expect(searchRepo.lastPage == 3)
    }
}
