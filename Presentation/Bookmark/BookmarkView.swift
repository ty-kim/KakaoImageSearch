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

                } else if viewModel.items.isEmpty {
                    EmptyStateView(message: L10n.Bookmark.empty)

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
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            Task { await viewModel.loadBookmarks() }
        }
    }
}
