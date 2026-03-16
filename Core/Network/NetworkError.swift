//
//  NetworkError.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

@MainActor
enum NetworkError: Error, @preconcurrency LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L10n.Network.invalidURL
        case .invalidResponse:
            return L10n.Network.invalidResponse
        case .httpError(let code):
            return L10n.Network.httpError(code)
        case .decodingError(let error):
            return L10n.Network.decodingError(error.localizedDescription)
        case .unknown(let error):
            return L10n.Network.unknown(error.localizedDescription)
        }
    }
}
