//
//  ProgressIndicator.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import SwiftUI

struct LiveActivityProgressIndicator: View {
    private let height: Double = 20
    let progress: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.tertiary)
            GeometryReader { geo in
                UnevenRoundedRectangle(
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(Color.accent)
                .frame(width: geo.size.width * min(1.0, max(0.0, progress)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: height)
        .clipShape(Capsule())
    }
}

#Preview {
    LiveActivityProgressIndicator(progress: 0)
    LiveActivityProgressIndicator(progress: 0.25)
    LiveActivityProgressIndicator(progress: 0.5)
    LiveActivityProgressIndicator(progress: 0.75)
    LiveActivityProgressIndicator(progress: 1)
    LiveActivityProgressIndicator(progress: 0.9)
    LiveActivityProgressIndicator(progress: 0.95)
    LiveActivityProgressIndicator(progress: 1.5)
    LiveActivityProgressIndicator(progress: 2)
}
