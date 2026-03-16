//
//  KakaoImageSearchEndpointTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
import Foundation
@testable import KakaoImageSearch

@MainActor
@Suite("KakaoImageSearchEndpoint 테스트")
struct KakaoImageSearchEndpointTests {

    // MARK: - URL 구조

    @Test("baseURL은 dapi.kakao.com 이다")
    func baseURL_isKakaoDapi() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        let request = try endpoint.makeURLRequest()

        #expect(request.url?.scheme == "https")
        #expect(request.url?.host == "dapi.kakao.com")
    }

    @Test("path는 /v2/search/image 이다")
    func path_isImageSearchPath() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        let request = try endpoint.makeURLRequest()

        #expect(request.url?.path == "/v2/search/image")
    }

    @Test("HTTP 메서드는 GET 이다")
    func httpMethod_isGET() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        let request = try endpoint.makeURLRequest()

        #expect(request.httpMethod == "GET")
    }

    // MARK: - 쿼리 파라미터

    @Test("query 파라미터가 URL에 포함된다")
    func queryParam_includedInURL() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "고양이", page: 1)
        let request = try endpoint.makeURLRequest()

        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
        let query = items?.first { $0.name == "query" }?.value

        #expect(query == "고양이")
    }

    @Test("page 파라미터가 URL에 포함된다")
    func pageParam_includedInURL() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 3)
        let request = try endpoint.makeURLRequest()

        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
        let page = items?.first { $0.name == "page" }?.value

        #expect(page == "3")
    }

    @Test("size 파라미터를 지정하면 URL에 반영된다")
    func sizeParam_customValue_reflectedInURL() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1, size: 15)
        let request = try endpoint.makeURLRequest()

        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
        let size = items?.first { $0.name == "size" }?.value

        #expect(size == "15")
    }

    @Test("기본 size는 30 이다")
    func sizeParam_defaultValue_is30() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        let request = try endpoint.makeURLRequest()

        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
        let size = items?.first { $0.name == "size" }?.value

        #expect(size == "30")
    }

    @Test("query, page, size 세 파라미터가 모두 포함된다")
    func allThreeParams_presentInURL() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "dog", page: 2, size: 20)
        let request = try endpoint.makeURLRequest()

        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let names = Set(items.map(\.name))

        #expect(names.contains("query"))
        #expect(names.contains("page"))
        #expect(names.contains("size"))
    }

    // MARK: - 헤더

    @Test("Authorization 헤더에 KakaoAK 접두사가 포함된다")
    func authorizationHeader_containsKakaoAK() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat", page: 1)
        let request = try endpoint.makeURLRequest()

        let auth = request.value(forHTTPHeaderField: "Authorization")
        #expect(auth?.hasPrefix("KakaoAK ") == true)
    }

    // MARK: - 특수 문자 / 한글

    @Test("한글 쿼리는 퍼센트 인코딩되어 유효한 URL이 생성된다")
    func koreanQuery_producesValidURL() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "강아지 사진", page: 1)
        let request = try endpoint.makeURLRequest()

        #expect(request.url != nil)
        #expect(request.url?.absoluteString.isEmpty == false)
    }

    @Test("특수문자 쿼리도 유효한 URL이 생성된다")
    func specialCharQuery_producesValidURL() throws {
        let endpoint = KakaoImageSearchEndpoint.searchImages(query: "cat & dog", page: 1)
        let request = try endpoint.makeURLRequest()

        #expect(request.url != nil)
    }
}
