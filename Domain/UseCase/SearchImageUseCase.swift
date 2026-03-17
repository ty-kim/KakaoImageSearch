//
//  SearchImageUseCase.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

final class SearchImageUseCase: Sendable {

    private let imageSearchRepository: any ImageSearchRepository
    private let bookmarkRepository: any BookmarkRepository

    init(
        imageSearchRepository: some ImageSearchRepository,
        bookmarkRepository: some BookmarkRepository
    ) {
        self.imageSearchRepository = imageSearchRepository
        self.bookmarkRepository = bookmarkRepository
    }

    /// 검색 결과에 북마크 상태를 merge해서 반환합니다.
    func execute(query: String, page: Int = 1) async throws -> SearchResultPage {
        async let searchResult = imageSearchRepository.search(query: query, page: page)
        async let bookmarks = bookmarkRepository.fetchAll()

        let result = try await searchResult
        let bookmarkedIDs = Set(try await bookmarks.map(\.id))

        var items = result.items
        for i in items.indices {
            items[i].isBookmarked = bookmarkedIDs.contains(items[i].id)
        }

        return SearchResultPage(items: items, isEnd: result.isEnd)
    }
}
