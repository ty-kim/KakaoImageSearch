//
//  BookmarkView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct BookmarkView: View {

    let viewModel: BookmarkViewModel

    var body: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("bookmarkView.loadingIndicator")

                } else if viewModel.items.isEmpty {
                    EmptyStateView(message: L10n.Bookmark.empty, accessibilityID: "bookmarkView.emptyState")

                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.items) { item in
                                SearchResultItemView(
                                    item: item,
                                    screenWidth: geometry.size.width
                                ) {
                                    Task { await viewModel.removeBookmark(for: item) }
                                }
                                .accessibilityIdentifier("bookmarkItem.\(item.id)")
                                Divider()
                            }
                        }
                    }
                    .accessibilityIdentifier("bookmarkView.list")
                }
            }
        }
        .onAppear {
            Task { await viewModel.loadBookmarks() }
        }
    }
}
