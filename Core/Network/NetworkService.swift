//
//  NetworkService.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

/// Generic URLSession 래퍼.
/// actor로 선언해 Swift 6 데이터 레이스 안전성을 보장합니다.
actor NetworkService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func request<T: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> T {
        let urlRequest = try await endpoint.makeURLRequest()

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw NetworkError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            // decoder를 매번 생성해 @MainActor 격리 충돌을 방지합니다.
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8 data"
            print("[NetworkService] Decoding failed: \(error)")
            print("[NetworkService] Raw JSON:\n\(raw)")
            #endif
            throw NetworkError.decodingError(error)
        }
    }
}
