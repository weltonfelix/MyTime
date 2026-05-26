//
//  ProgressIndicator.swift
//  MyTime
//
//  Created by Welton Felix on 22/05/26.
//

import SwiftUI

struct ProgressIndicator: View {
    var isExpanded: Bool = false
    var large: Bool = false
    var progress: CGFloat = 0

    private var width: Double { isExpanded ? (large ? 120 : 48) : 20 }
    private var progressWidth: Double {
        if isExpanded {
            let radius = 10.0  // half of the height
            return width * progress + progress * (radius * (1 - progress))
        } else {
            return progress < 1 ? 0 : width
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().glassEffect()
            Capsule()
                .frame(width: progressWidth)
                .glassEffect(.regular.tint(.accent))
        }.frame(width: width, height: 20)
            .clipShape(Capsule())
            .animation(.spring, value: isExpanded)
    }
}

#Preview("Progress Indicator") {
    HStack {
        ProgressIndicator()

        ProgressIndicator()

        ProgressIndicator(isExpanded: true, progress: 0.5)

        ProgressIndicator(progress: 0)

    }
    ProgressIndicator(isExpanded: true, large: true, progress: 0)
}
