//
//  MainView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct MainView: View {

    @State var viewModel: MainViewModel

    var body: some View {
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
        .task {
            await viewModel.loadInitialData()
        }
    }
}
