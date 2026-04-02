//
//  SearchBookmarkHandlerTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/31/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

@MainActor
@Suite("SearchBookmarkHandler")
struct SearchBookmarkHandlerTests {

    private func makeSUT() async throws -> (sut: SearchBookmarkHandler, bookmarkStore: BookmarkStore) {
        let bookmarkRepo = MockBookmarkRepository()
        let bookmarkStore = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        try await bookmarkStore.load()
        let sut = SearchBookmarkHandler(bookmarkStore: bookmarkStore)
        return (sut, bookmarkStore)
    }

    // MARK: - toggle 성공

    @Test("toggle — 성공 시 updated 반환")
    func toggle_success_returnsUpdated() async throws {
        let (sut, _) = try await makeSUT()
        let item = ImageItem.fixture(id: "1")

        let outcome = await sut.toggle(item)

        #expect(outcome.effect == .updated)
    }

    @Test("toggle — 성공 후 inFlightBookmarkIDs에서 제거됨")
    func toggle_success_removesFromInFlight() async throws {
        let (sut, _) = try await makeSUT()
        let item = ImageItem.fixture(id: "1")

        let outcome = await sut.toggle(item)

        #expect(!outcome.inFlightBookmarkIDs.contains("1"))
    }

    // MARK: - toggle 실패

    @Test("toggle — 실패 시 failed 반환")
    func toggle_failure_returnsFailed() async throws {
        let bookmarkRepo = MockBookmarkRepository()
        bookmarkRepo.stubbedSaveError = TestError.stub
        let bookmarkStore = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        try await bookmarkStore.load()
        let sut = SearchBookmarkHandler(bookmarkStore: bookmarkStore)
        let item = ImageItem.fixture(id: "1")

        let outcome = await sut.toggle(item)

        if case .failed = outcome.effect {
            // OK
        } else {
            Issue.record("Expected .failed but got \(outcome.effect)")
        }
    }

    @Test("toggle — 실패 후 inFlightBookmarkIDs에서 제거됨")
    func toggle_failure_removesFromInFlight() async throws {
        let bookmarkRepo = MockBookmarkRepository()
        bookmarkRepo.stubbedSaveError = TestError.stub
        let bookmarkStore = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        try await bookmarkStore.load()
        let sut = SearchBookmarkHandler(bookmarkStore: bookmarkStore)
        let item = ImageItem.fixture(id: "1")

        let outcome = await sut.toggle(item)

        #expect(!outcome.inFlightBookmarkIDs.contains("1"))
    }
}
