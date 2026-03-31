//
//  SearchResultsStoreTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/31/26.
//

import Testing
@testable import KakaoImageSearch
import Foundation

@MainActor
@Suite("SearchResultsStore")
struct SearchResultsStoreTests {

    private func makeSUT() async throws -> (sut: SearchResultsStore, bookmarkStore: BookmarkStore) {
        let bookmarkRepo = MockBookmarkRepository()
        let bookmarkStore = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)
        )
        try await bookmarkStore.load()
        let sut = SearchResultsStore(bookmarkStore: bookmarkStore)
        return (sut, bookmarkStore)
    }

    // MARK: - replace

    @Test("replace — items 교체")
    func replace_setsItems() async throws {
        let (sut, _) = try await makeSUT()

        sut.replace(with: [.fixture(id: "1"), .fixture(id: "2")])

        #expect(sut.items.count == 2)
        #expect(sut.items[0].id == "1")
        #expect(sut.items[1].id == "2")
    }

    @Test("replace — 기존 items 덮어씀")
    func replace_overwritesPrevious() async throws {
        let (sut, _) = try await makeSUT()

        sut.replace(with: [.fixture(id: "1")])
        sut.replace(with: [.fixture(id: "2")])

        #expect(sut.items.count == 1)
        #expect(sut.items[0].id == "2")
    }

    // MARK: - append

    @Test("append — 기존 items에 추가")
    func append_addsToExisting() async throws {
        let (sut, _) = try await makeSUT()

        sut.replace(with: [.fixture(id: "1")])
        sut.append([.fixture(id: "2"), .fixture(id: "3")])

        #expect(sut.items.count == 3)
    }

    // MARK: - clear

    @Test("clear — items 비움")
    func clear_emptiesItems() async throws {
        let (sut, _) = try await makeSUT()

        sut.replace(with: [.fixture(id: "1"), .fixture(id: "2")])
        sut.clear()

        #expect(sut.items.isEmpty)
    }

    // MARK: - 북마크 상태 반영

    @Test("replace — 북마크된 아이템은 isBookmarked=true")
    func replace_reflectsBookmarkState() async throws {
        let (sut, bookmarkStore) = try await makeSUT()
        let item = ImageItem.fixture(id: "1")
        try await bookmarkStore.toggle(item)

        sut.replace(with: [.fixture(id: "1"), .fixture(id: "2")])

        #expect(sut.items[0].isBookmarked == true)
        #expect(sut.items[1].isBookmarked == false)
    }

    @Test("refresh — 북마크 변경 후 수동 갱신")
    func refresh_updatesBookmarkState() async throws {
        let (sut, bookmarkStore) = try await makeSUT()
        sut.replace(with: [.fixture(id: "1")])

        #expect(sut.items[0].isBookmarked == false)

        try await bookmarkStore.toggle(ImageItem.fixture(id: "1"))
        sut.refresh()

        #expect(sut.items[0].isBookmarked == true)
    }

    // MARK: - observeBookmarkStore

    @Test("북마크 토글 시 자동으로 items 갱신")
    func observeBookmarkStore_autoUpdates() async throws {
        let (sut, bookmarkStore) = try await makeSUT()
        sut.replace(with: [.fixture(id: "1")])

        #expect(sut.items[0].isBookmarked == false)

        try await bookmarkStore.toggle(ImageItem.fixture(id: "1"))

        // withObservationTracking onChange는 비동기로 실행되므로 약간 대기
        try await Task.sleep(for: .milliseconds(100))

        #expect(sut.items[0].isBookmarked == true)
    }
}
