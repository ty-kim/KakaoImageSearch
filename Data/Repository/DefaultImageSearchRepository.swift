//
//  DefaultImageSearchRepository.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

final class DefaultImageSearchRepository: ImageSearchRepository {

    private let networkService: any NetworkServiceProtocol

    init(networkService: any NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func search(query: String, page: Int) async throws -> SearchResultPage {
        do {
            let endpoint = KakaoImageSearchEndpoint.searchImages(query: query, page: page)
            let response: KakaoSearchResponseDTO = try await networkService.request(endpoint)
            return SearchResultPage(
                items: response.documents.compactMap { $0.toImageItem() },
                isEnd: response.meta.isEnd
            )
        } catch NetworkError.httpError(let statusCode, let body) {
            if let data = body?.data(using: .utf8),
               let dto = try? JSONDecoder().decode(KakaoErrorResponseDTO.self, from: data) {
                throw ImageSearchError.serverError(message: dto.message)
            }
            throw ImageSearchError.serverError(message: "HTTP \(statusCode)")
        } catch {
            throw ImageSearchError.unknown(error)
        }
    }
}
