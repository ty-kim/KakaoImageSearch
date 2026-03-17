//
//  MainView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct MainView: View {

    @State var viewModel: MainViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            SearchBar(text: $viewModel.searchText)
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.onSearchTextChanged(newValue)
                }

            TabView(selection: $viewModel.selectedTab) {
                SearchView(viewModel: viewModel.searchViewModel)
                    .tabItem {
                        Label(L10n.Tab.search, systemImage: "magnifyingglass")
                    }
                    .tag(MainViewModel.Tab.search)

                BookmarkView(viewModel: viewModel.bookmarkViewModel)
                    .tabItem {
                        Label(L10n.Tab.bookmark, systemImage: "bookmark.fill")
                    }
                    .tag(MainViewModel.Tab.bookmark)
            }
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchText)
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.onSearchTextChanged(newValue)
                    }
                SearchView(viewModel: viewModel.searchViewModel, columns: 2)
            }
            .navigationTitle(L10n.Tab.search)
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            BookmarkView(viewModel: viewModel.bookmarkViewModel, columns: 2)
                .navigationTitle(L10n.Tab.bookmark)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
