//
//  NetworkService.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import OSLog

/// Generic URLSession 래퍼.
/// actor로 선언해 Swift 6 데이터 레이스 안전성을 보장합니다.
actor NetworkService {
    private let session: URLSession

    init(session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()) {
        self.session = session
    }

    func request<T: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> T {
        let urlRequest = try await endpoint.makeURLRequest()

        Logger.network.debugPrint("→ \(urlRequest.httpMethod ?? "") \(urlRequest.url?.absoluteString ?? "")")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch is CancellationError {
            Logger.network.debugPrint("Request cancelled")
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            Logger.network.debugPrint("Request cancelled: \(error)")
            throw CancellationError()
        } catch {
            Logger.network.errorPrint("Request failed: \(error)")
            throw NetworkError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.errorPrint("Invalid response type")
            throw NetworkError.invalidResponse
        }

        Logger.network.debugPrint("← \(httpResponse.statusCode) (\(data.count) bytes)")

        guard (200..<300).contains(httpResponse.statusCode) else {
            Logger.network.errorPrint("HTTP \(httpResponse.statusCode)")
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            // decoder를 매번 생성해 @MainActor 격리 충돌을 방지합니다.
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(T.self, from: data)
            Logger.network.debugPrint("Decoded \(T.self) successfully")
            return result
        } catch {
            #if DEBUG
            let raw = String(data: data, encoding: .utf8) ?? "non-UTF8"
            Logger.network.errorPrint("Decoding \(T.self) failed: \(error)\nRaw: \(raw)")
            #else
            Logger.network.errorPrint("Decoding \(T.self) failed: \(error)")
            #endif
            throw NetworkError.decodingError(error)
        }
    }
}
