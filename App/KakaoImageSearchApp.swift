//
//  KakaoImageSearchApp.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

@main
struct KakaoImageSearchApp: App {
    @State private var viewModel = AppAssembler.makeMainViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
        }
    }
}
