//
//  ImageAnalyzer.swift
//  KakaoImageSearch
//
//  Created by tykim on 4/7/26.
//

import Vision
import UIKit

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
}

enum ImageAnalyzerError: Error {
    case invalidImage
}
