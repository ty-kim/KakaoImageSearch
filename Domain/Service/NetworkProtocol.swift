//
//  NetworkProtocol.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

protocol APIEndpoint: Sendable {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
}

extension APIEndpoint {
    var body: Data? { nil }
}

/// 네트워크 요청 추상화. Data 레이어에서 Infrastructure 구체 타입 대신 이 프로토콜에 의존합니다.
protocol NetworkServiceProtocol: Sendable {
    func request<T: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> T
}

/// 네트워크 연결 상태 감지 추상화.
protocol NetworkMonitoring: Sendable {
    var isConnected: Bool { get }
}
