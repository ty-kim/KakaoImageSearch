//
//  ImageSearchRepository.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

struct SearchResultPage: Sendable {
    let items: [ImageItem]
    let isEnd: Bool
}

protocol ImageSearchRepository: Sendable {
    func search(query: String, page: Int) async throws -> SearchResultPage
}
