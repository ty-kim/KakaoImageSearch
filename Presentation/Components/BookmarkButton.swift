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
                .foregroundStyle(isBookmarked ? AppColors.bookmarkActive : AppColors.bookmarkInactive)
                .shadow(color: AppColors.bookmarkShadow, radius: 2, x: 0, y: 1)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isBookmarked ? L10n.Accessibility.bookmarkRemove : L10n.Accessibility.bookmarkAdd)
        .accessibilityHint(isBookmarked ? L10n.Accessibility.bookmarkRemoveHint : L10n.Accessibility.bookmarkAddHint)
        .accessibilityIdentifier(isBookmarked ? "bookmarkButton.active" : "bookmarkButton.inactive")
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 32) {
        BookmarkButton(isBookmarked: false, action: {})
        BookmarkButton(isBookmarked: true, action: {})
    }
    .padding()
}
#endif
