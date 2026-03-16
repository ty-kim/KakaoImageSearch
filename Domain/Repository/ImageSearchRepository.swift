//
//  ImageSearchRepository.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

protocol ImageSearchRepository: Sendable {
    func search(query: String, page: Int) async throws -> [ImageItem]
}
