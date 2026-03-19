//
//  ImageDownloaderEnvironment.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/20/26.
//

import SwiftUI

private struct ImageDownloaderKey: EnvironmentKey {
    static let defaultValue: any ImageDownloading = ImageDownloader.shared
}

extension EnvironmentValues {
    var imageDownloader: any ImageDownloading {
        get { self[ImageDownloaderKey.self] }
        set { self[ImageDownloaderKey.self] = newValue }
    }
}
