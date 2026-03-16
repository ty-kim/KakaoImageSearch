//
//  AppLogger.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import OSLog

/// 앱 전역 로거. OSLog 기반으로 Console 앱에서 카테고리별 필터링을 지원합니다.
///
/// 사용 예:
/// ```swift
/// Logger.network.debug("Request: \(url)")
/// Logger.network.error("Decode failed: \(error)")
/// ```
extension Logger {
    nonisolated private static let subsystem = "com.start.KakaoImageSearch"

    /// 네트워크 요청/응답/에러
    nonisolated static let network      = Logger(subsystem: subsystem, category: "Network")

    /// 이미지 다운로드 및 캐시
    nonisolated static let imageLoader  = Logger(subsystem: subsystem, category: "ImageLoader")

    /// 북마크 저장/불러오기
    nonisolated static let bookmark     = Logger(subsystem: subsystem, category: "Bookmark")

    /// ViewModel 상태 변화
    nonisolated static let presentation = Logger(subsystem: subsystem, category: "Presentation")
}

// MARK: - Debug Console 출력 보조
// OS_ACTIVITY_MODE=   환경에서도 Xcode 콘솔에 출력됩니다.
extension Logger {
    nonisolated func debugPrint(_ message: String) {
        self.debug("\(message)")
        #if DEBUG
        print("[Logger] \(message)")
        #endif
    }

    nonisolated func errorPrint(_ message: String) {
        self.error("\(message)")
        #if DEBUG
        print("[Logger] ⚠️ \(message)")
        #endif
    }
}
