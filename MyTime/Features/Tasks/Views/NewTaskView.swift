//
//  NewTaskView.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftUI

struct NewTaskView: View {
    var onSubmit: (MyTask) -> Void

    @State private var description: String = ""
    @State private var sheetHeight: CGFloat = .zero
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextField(
                "Descreva a tarefa",
                text: $description,
                axis: .vertical
            )
            .lineLimit(3...10).fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 80).focused($isFocused)

            Button("Adicionar", systemImage: "arrow.up", action: handleSubmit)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(
                    .circle
                ).disabled(description.isEmpty)
        }
        .padding()
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { sheetHeight = geo.size.height }
                    .onChange(of: geo.size.height) { old, _new in
                        sheetHeight = old
                    }
            }
        )
        .presentationDetents([.height(sheetHeight)])
        .onAppear { isFocused = true }
        .interactiveDismissDisabled(!description.isEmpty)

    }

    func handleSubmit() {
        onSubmit(MyTask(taskDescription: description))
        dismiss()
    }
}

#Preview {
    NewTaskView { task in
        print(task.taskDescription)
    }
}
