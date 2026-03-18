//
//  BookmarkButton.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct BookmarkButton: View {

    let isBookmarked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.title2)
                .foregroundStyle(isBookmarked ? Color.yellow : Color.white)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isBookmarked ? L10n.Accessibility.bookmarkRemove : L10n.Accessibility.bookmarkAdd)
        .accessibilityHint(isBookmarked ? L10n.Accessibility.bookmarkRemoveHint : L10n.Accessibility.bookmarkAddHint)
        .accessibilityIdentifier(isBookmarked ? "bookmarkButton.active" : "bookmarkButton.inactive")
    }
}
