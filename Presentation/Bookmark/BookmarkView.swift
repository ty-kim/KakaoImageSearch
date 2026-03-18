//
//  BookmarkView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct BookmarkView: View {

    let viewModel: BookmarkViewModel
    var columns: Int = 1

    var body: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("bookmarkView.loadingIndicator")

                } else if viewModel.hasLoadError {
                    EmptyStateView(
                        message: L10n.Bookmark.loadError,
                        accessibilityID: "bookmarkView.errorState",
                        retryAction: { viewModel.retryLoadBookmarks() }
                    )

                } else if viewModel.items.isEmpty {
                    EmptyStateView(message: L10n.Bookmark.empty, accessibilityID: "bookmarkView.emptyState")

                } else {
                    let horizontalPadding: CGFloat = 20
                    let columnSpacing: CGFloat = 20
                    let itemWidth = (geometry.size.width - horizontalPadding * 2 - columnSpacing * CGFloat(columns - 1)) / CGFloat(columns)
                    let gridColumns = Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: columns)

                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 20) {
                            ForEach(viewModel.items) { item in
                                SearchResultItemView(
                                    item: item,
                                    screenWidth: itemWidth,
                                    isBookmarkInFlight: viewModel.inFlightBookmarkIDs.contains(item.id)
                                ) {
                                    Task { await viewModel.toggleBookmark(for: item) }
                                }
                                .accessibilityIdentifier("bookmarkItem.\(item.id)")
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                    .accessibilityIdentifier("bookmarkView.list")
                }
            }
        }
        .task {
            await viewModel.loadBookmarks()
        }
        .overlay(alignment: .bottom) {
            if let msg = viewModel.toastMessage {
                ToastView(message: msg)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.toastMessage)
    }
}
