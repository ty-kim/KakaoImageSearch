//
//  SearchView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct SearchView: View {

    let viewModel: SearchViewModel
    var columns: Int = 1

    var body: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel(L10n.Accessibility.loading)
                        .accessibilityIdentifier("searchView.loadingIndicator")

                } else if let message = viewModel.errorMessage {
                    EmptyStateView(
                        message: message,
                        accessibilityID: "searchView.emptyState",
                        retryAction: viewModel.hasError ? { Task { await viewModel.retry() } } : nil
                    )

                } else if !viewModel.hasSearched {
                    EmptyStateView(message: L10n.Search.emptyInitial, accessibilityID: "searchView.emptyState")

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
                                .accessibilityIdentifier("searchResultItem.\(item.id)")
                                .onAppear {
                                    if item.id == viewModel.items.last?.id {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, horizontalPadding)

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .accessibilityIdentifier("searchView.loadingMore")
                        } else if viewModel.hasLoadMoreError {
                            Button {
                                viewModel.retryLoadMore()
                            } label: {
                                Text(L10n.Search.loadMoreRetry)
                                    .font(.callout.weight(.medium))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(.tint.opacity(0.12))
                                    .foregroundStyle(.tint)
                                    .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .accessibilityHint(L10n.Accessibility.loadMoreRetryHint)
                            .accessibilityIdentifier("searchView.loadMoreRetryButton")
                        }
                    }
                    .accessibilityIdentifier("searchView.resultsList")
                }
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
}
