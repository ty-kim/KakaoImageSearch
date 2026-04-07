//
//  ImageAnalyzerEnvironment.swift
//  KakaoImageSearch
//
//  Created by tykim on 4/7/26.
//

import SwiftUI

private struct ImageAnalyzerKey: EnvironmentKey {
    static let defaultValue: ImageAnalyzer = ImageAnalyzer()
}

extension EnvironmentValues {
    var imageAnalyzer: ImageAnalyzer {
        get { self[ImageAnalyzerKey.self] }
        set { self[ImageAnalyzerKey.self] = newValue }
    }
}
