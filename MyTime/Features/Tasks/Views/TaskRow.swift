//
//  TaskView.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftUI

struct TaskRow: View {
    var activity: Activity

    var body: some View {
        HStack {
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

            Text(activity.task?.taskDescription ?? "")
                .strikethrough(activity.isCompleted, color: .secondary)
                .foregroundStyle(activity.isCompleted ? .secondary : .primary)

        }
    }
}

#Preview {
    let task = MyTask(taskDescription: "Test")
    let activity = Activity(task: task, isCompleted: false)
    TaskRow(activity: activity)
}
