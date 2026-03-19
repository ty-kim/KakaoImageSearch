//
//  PresentationLogger.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/20/26.
//

import OSLog

extension Logger {
    /// ViewModel 상태 변화
    nonisolated static let presentation = Logger(subsystem: "com.start.KakaoImageSearch", category: "Presentation")
}
