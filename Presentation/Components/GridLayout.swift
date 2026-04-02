//
//  GridLayout.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/25/26.
//

import SwiftUI

struct GridLayout {

    let columns: Int
    let availableWidth: CGFloat

    var horizontalPadding: CGFloat { columns == 1 ? 0 : 20 }
    var columnSpacing: CGFloat { columns == 1 ? 0 : 20 }

    var itemWidth: CGFloat {
        (availableWidth - horizontalPadding * 2 - columnSpacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: columns)
    }
}
