//
//  AppColors.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/21/26.
//

import SwiftUI

/// 앱 전역 시맨틱 컬러 정의.
/// Asset Catalog(Colors/)에 라이트/다크 색상을 정의하고, 여기서 참조한다.
enum AppColors {

    // MARK: - Toast

    static let toastForeground = Color("Colors/ToastForeground")
    static let toastBackground = Color("Colors/ToastBackground")

    // MARK: - Search Bar

    static let searchBarBackground = Color("Colors/SearchBarBackground")
    static let searchBarIcon = Color("Colors/SearchBarIcon")

    // MARK: - Placeholder / Skeleton

    static let placeholderBackground = Color("Colors/PlaceholderBackground")
    static let placeholderIcon = Color("Colors/PlaceholderIcon")
    static let skeletonShimmer = Color("Colors/SkeletonShimmer")

    // MARK: - Bookmark Button

    static let bookmarkActive = Color("Colors/BookmarkActive")
    static let bookmarkInactive = Color("Colors/BookmarkInactive")
    static let bookmarkShadow = Color("Colors/BookmarkShadow")

    // MARK: - Image Detail

    static let detailBackground = Color("Colors/DetailBackground")
    static let detailOverlay = Color("Colors/DetailOverlay")
    static let detailCloseButton = Color("Colors/DetailCloseButton")
    static let detailCloseButtonShadow = Color("Colors/DetailCloseButtonShadow")

    // MARK: - Retry / Empty State

    static let retryBackground = Color("Colors/RetryBackground")
    static let retryForeground = Color("Colors/RetryForeground")
}
