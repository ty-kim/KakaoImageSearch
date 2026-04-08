//
//  ImageAnalyzer.swift
//  KakaoImageSearch
//
//  Created by tykim on 4/7/26.
//

import Vision
import UIKit
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

actor ImageAnalyzer {
    // - 너무 낮으면 (0.1) — 관계없는 키워드까지 나옴
    // - 너무 높으면 (0.7) — 키워드가 거의 안 나옴
    nonisolated let minimumConfidence: VNConfidence = 0.2
    nonisolated let maxKeywordCount: Int = 5
    
    nonisolated func classifyImage(_ image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw ImageAnalyzerError.invalidImage
        }
        
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        
        let results = request.results ?? []
        return results
            .sorted { $0.confidence > $1.confidence }
            .filter { $0.confidence > self.minimumConfidence }
            .prefix(self.maxKeywordCount)
            .map { $0.identifier }
    }

    /// Vision API 키워드를 사용자 언어의 자연스러운 설명문으로 변환.
    /// iOS 26+: Foundation Models 온디바이스 LLM 사용.
    /// iOS 17~25: "Photo, keyword1, keyword2" 형태로 폴백.
    nonisolated func describeImage(keywords: [String]) async -> String {
        guard !keywords.isEmpty else { return "" }
        if #available(iOS 26, *) {
            if let description = await generateDescription(keywords: keywords) {
                return description
            }
        }

        return L10n.Accessibility.photo + ", " + keywords.joined(separator: ", ")
    }

    @available(iOS 26, *)
    private nonisolated func generateDescription(keywords: [String]) async -> String? {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            Logger.imageAnalyzer.debugPrint("Foundation Models unavailable")
            return nil
        }

        let keywordList = keywords.joined(separator: ", ")
        let language = L10n.currentLanguageName

        let session = LanguageModelSession(instructions: """
            You are an accessibility assistant. \
            Given image classification keywords, generate a concise, natural description \
            of the image in \(language). \
            Keep it under 20 words. Do not add any prefix like "Photo" or "Image". \
            Respond only in \(language).
            """)

        do {
            let response = try await session.respond(to: "Keywords: \(keywordList)")
            let description = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            Logger.imageAnalyzer.debugPrint("Foundation Models description: \(description)")
            guard !description.isEmpty else { return nil }
            return description
        } catch {
            Logger.imageAnalyzer.errorPrint("Foundation Models failed: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
}

enum ImageAnalyzerError: Error {
    case invalidImage
}
