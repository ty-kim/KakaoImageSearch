//
//  APIEndpoint.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

extension APIEndpoint {
    func makeURLRequest() throws -> URLRequest {
        var components = URLComponents(string: baseURL + path)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = body
        return request
    }
}
