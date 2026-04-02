//
//  ImageSearchError.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/29/26.
//

import Foundation

enum ImageSearchError: Error {
    case serverError(message: String)
    case unknown(Error)

    var userMessage: String {
        switch self {
        case .serverError(let message): return message
        case .unknown(let error): return error.localizedDescription
        }
    }
}
