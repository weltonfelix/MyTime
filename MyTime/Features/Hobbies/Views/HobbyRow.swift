//
//  HobbyView.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftData
import SwiftUI

struct HobbyRow: View {
    @Bindable var activity: Activity
    var onDelete: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Query private var allHobbies: [Hobby]

    init(activity: Activity, onDelete: (() -> Void)? = nil) {
        guard activity.hobby != nil else {
            fatalError("Activity must have a hobby")
        }

        self.activity = activity
        self.onDelete = onDelete
    }

    var body: some View {
        if let hobby = activity.hobby {
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(duration: 0.2)) {
                        activity.isCompleted.toggle()
                    }
                }) {
                    Image(
                        systemName: activity.isCompleted
                            ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.system(size: 22))
                    .contentTransition(
                        .symbolEffect(.replace)
                    )
                }
                .buttonStyle(.borderless)
                .foregroundStyle(activity.isCompleted ? .accent : .secondary)
                .sensoryFeedback(.success, trigger: activity.isCompleted) {
                    _, new in new
                }

                HStack {
                    Text(
                        "\(hobby.title) - \((activity.durationInMin ?? 0).formattedAsDuration)"
                    )
                    .foregroundStyle(
                        activity.isCompleted ? .secondary : .primary
                    )
                    .strikethrough(activity.isCompleted, color: .secondary)

                    Image(systemName: "sparkles")
                        .foregroundStyle(
                            LinearGradient.hobbyGradient
                        )

                }
            }
            .listRowBackground(
                LinearGradient.hobbyGradient.opacity(0.15)
            )
            .contextMenu {
                Picker("Hobby", selection: $activity.hobby) {
                    ForEach(allHobbies) { hobby in
                        Text(hobby.title).tag(hobby as Hobby?)
                    }
                }
                .pickerStyle(.inline)
                Button(
                    "Remover",
                    systemImage: "xmark",
                    role: .destructive
                ) {
                    onDelete?()
                }
            }

        }
    }
}

#Preview {
    let hobbies = [
        Hobby(title: "My Hobby", hobbyDescription: "Description"),
        Hobby(title: "My Hobby 2", hobbyDescription: "Description 2"),
    ]

    HobbyRow(
        activity: Activity(hobby: hobbies[0], durationInMin: 30)
    )
}
