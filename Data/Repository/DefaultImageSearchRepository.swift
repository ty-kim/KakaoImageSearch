//
//  DefaultImageSearchRepository.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

final class DefaultImageSearchRepository: ImageSearchRepository {

    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func search(query: String, page: Int) async throws -> [ImageItem] {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: query, page: page)
        let response: KakaoSearchResponseDTO = try await networkService.request(endpoint)
        return response.documents.compactMap { $0.toImageItem() }
    }
}
