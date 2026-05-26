//
//  DotsProgressIndicator.swift
//  MyTime
//
//  Created by Welton Felix on 25/05/26.
//

import SwiftUI

struct DotProgressIndicator: View {
    var width: Double = 20
    let progress: Double


    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.tertiary)
            UnevenRoundedRectangle(
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(Color.accent)
            .frame(width: width * progress)
        }
        .frame(width: width, height: width)
        .clipShape(Capsule())
    }
}

#Preview {
    DotProgressIndicator(progress: 0)
    DotProgressIndicator(progress: 0.25)
    DotProgressIndicator(progress: 0.5)
    DotProgressIndicator(progress: 0.75)
    DotProgressIndicator(progress: 1)
}
