// L10n.swift
// KakaoImageSearch
//
// Created by tykim on 3/16/26.
//
// Localizable.xcstrings 키를 타입 세이프하게 래핑합니다.
// 뷰/모델에서 문자열 리터럴 대신 L10n.Search.placeholder 형태로 사용하세요.

import Foundation

nonisolated enum L10n {

    /// 현재 기기 언어를 영문 이름으로 반환 (Foundation Models 프롬프트용)
    static var currentLanguageName: String {
        let code = Locale.current.language.languageCode?.identifier ?? "ko"
        return switch code {
        case "en": "English"
        case "ja": "Japanese"
        default: "Korean"
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
        static var apiLimitReached: String {
            String(localized: "search.api_limit_reached")
        }
        static var offline: String {
            String(localized: "search.error.offline")
        }
        static var imageLoadFailed: String {
            String(localized: "search.error.image_load_failed")
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
        static var photo: String {
              String(localized: "accessibility.photo")
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
        static var detailClose: String {
            String(localized: "accessibility.detail.close")
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
