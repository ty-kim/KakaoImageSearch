// L10n.swift
// KakaoImageSearch
//
// Created by tykim on 3/16/26.
//
// Localizable.xcstrings 키를 타입 세이프하게 래핑합니다.
// 뷰/모델에서 문자열 리터럴 대신 L10n.Search.placeholder 형태로 사용하세요.

import Foundation

enum L10n {

    enum Network {
        static var invalidURL: String {
            String(localized: "network.error.invalid_url")
        }
        static var invalidResponse: String {
            String(localized: "network.error.invalid_response")
        }
        static func httpError(_ code: Int) -> String {
            String(localized: "network.error.http_error \(code)")
        }
        static func decodingError(_ description: String) -> String {
            String(localized: "network.error.decoding_error \(description)")
        }
        static func unknown(_ description: String) -> String {
            String(localized: "network.error.unknown \(description)")
        }
    }

    enum Search {
        static var placeholder: String {
            String(localized: "search.bar.placeholder")
        }
        static var emptyInitial: String {
            String(localized: "search.empty.initial")
        }
        static var emptyNoResults: String {
            String(localized: "search.empty.no_results")
        }
        static func error(_ description: String) -> String {
            String(localized: "search.error.generic \(description)")
        }
        static var retry: String {
            String(localized: "search.error.retry")
        }
        static var loadMoreRetry: String {
            String(localized: "search.error.load_more_retry")
        }
    }

    enum Tab {
        static var search: String {
            String(localized: "tab.search")
        }
        static var bookmark: String {
            String(localized: "tab.bookmark")
        }
    }

    enum Bookmark {
        static var empty: String {
            String(localized: "bookmark.empty")
        }
        static var toggleError: String {
            String(localized: "bookmark.error.toggle")
        }
    }
}
