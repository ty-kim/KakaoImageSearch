//
//  NetworkError.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, responseBody: String?)
    case decodingError(Error)
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "network.error.invalid_url")
        case .invalidResponse:
            return String(localized: "network.error.invalid_response")
        case .httpError(let code, _):
            return String(localized: "network.error.http_error \(code)")
        case .decodingError(let error):
            return String(localized: "network.error.decoding_error \(error.localizedDescription)")
        case .timeout:
            return String(localized: "network.error.timeout")
        case .unknown(let error):
            return String(localized: "network.error.unknown \(error.localizedDescription)")
        }
    }
}
