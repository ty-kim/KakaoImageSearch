//
//  SearchView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct SearchView: View {

    let viewModel: SearchViewModel

    var body: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.items) { item in
                                SearchResultItemView(
                                    item: item,
                                    screenWidth: geometry.size.width
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

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .accessibilityIdentifier("searchView.loadingMore")
                            } else if viewModel.hasLoadMoreError {
                                Button {
                                    Task { await viewModel.retryLoadMore() }
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
                                .accessibilityIdentifier("searchView.loadMoreRetryButton")
                            }
                        }
                    }
                    .accessibilityIdentifier("searchView.resultsList")
                }
            }
        }
    }
}
