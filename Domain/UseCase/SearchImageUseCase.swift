//
//  SearchImageUseCase.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

final class SearchImageUseCase: Sendable {

    private let imageSearchRepository: any ImageSearchRepository

    init(imageSearchRepository: some ImageSearchRepository) {
        self.imageSearchRepository = imageSearchRepository
    }

    /// 검색 결과를 반환합니다. 북마크 상태 merge는 Presentation 레이어(BookmarkStore)에서 처리합니다.
    func execute(query: String, page: Int = 1) async throws -> SearchResultPage {
        try await imageSearchRepository.search(query: query, page: page)
    }
}
