// L10n.swift
// KakaoImageSearch
//
// Created by tykim on 3/16/26.
//
// Localizable.xcstrings 키를 타입 세이프하게 래핑합니다.
// 뷰/모델에서 문자열 리터럴 대신 L10n.Search.placeholder 형태로 사용하세요.

import Foundation

nonisolated enum L10n {

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

    enum ImageDownload {
        static var invalidResponse: String {
            String(localized: "image_download.error.invalid_response")
        }
        static var invalidData: String {
            String(localized: "image_download.error.invalid_data")
        }
        static var notImageContentType: String {
            String(localized: "image_download.error.not_image_content_type")
        }
        static var contentLengthExceeded: String {
            String(localized: "image_download.error.content_length_exceeded")
        }
    }

    enum Accessibility {
        static var bookmarkAdd: String {
            String(localized: "accessibility.bookmark.add")
        }
        static var bookmarkRemove: String {
            String(localized: "accessibility.bookmark.remove")
        }
        static var bookmarkAddHint: String {
            String(localized: "accessibility.bookmark.add.hint")
        }
        static var bookmarkRemoveHint: String {
            String(localized: "accessibility.bookmark.remove.hint")
        }
        static var searchClear: String {
            String(localized: "accessibility.search.clear")
        }
        static func imageItem(width: Int?, height: Int?) -> String {
            let w = width ?? 0
            let h = height ?? 0
            return String(localized: "accessibility.image_item \(w) \(h)")
        }
        static var tabSearchHint: String {
            String(localized: "accessibility.tab.search.hint")
        }
        static var tabBookmarkHint: String {
            String(localized: "accessibility.tab.bookmark.hint")
        }
        static var loadMoreRetryHint: String {
            String(localized: "accessibility.load_more_retry.hint")
        }
        static var retryHint: String {
            String(localized: "accessibility.retry.hint")
        }
        static var searchFieldHint: String {
            String(localized: "accessibility.search_field.hint")
        }
        static var loading: String {
            String(localized: "accessibility.loading")
        }
    }

    enum Bookmark {
        static var empty: String {
            String(localized: "bookmark.empty")
        }
        static var toggleError: String {
            String(localized: "bookmark.error.toggle")
        }
        static var loadError: String {
            String(localized: "bookmark.error.load")
        }
    }
}
