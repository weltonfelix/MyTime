//
//  EditTasksView.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftData
import SwiftUI

struct EditTasksView: View {
    @Environment(\.dismiss) var dismiss
    var onSubmit: ((Bool) -> Void)

    @Query(sort: \MyTask.createdAt) var tasks: [MyTask]
    @Environment(\.modelContext) var modelContext

    @State private var showNewTask: Bool = false
    @State private var showDiscardConfirmation = false
    @State private var pendingDeletions = [MyTask]()
    @State private var pendingAdditions = [MyTask]()

    private var hasChanges: Bool {
        !pendingAdditions.isEmpty || !pendingDeletions.isEmpty
    }

    var displayedTasks: [MyTask] {
        tasks.filter { !pendingDeletions.contains($0) } + pendingAdditions
    }

    var body: some View {
        NavigationStack {
            VStack {
                if displayedTasks.isEmpty {
                    ContentUnavailableView("No Tasks", systemImage: "")
                        .transition(.opacity)
                } else {
                    List {
                        ForEach(displayedTasks) { task in
                            Text(task.taskDescription).listRowSeparator(
                                .visible,
                                edges: .bottom
                            )
                        }
                        .onDelete(perform: deleteTasks)
                        .listSectionSeparator(.hidden, edges: .all)
                    }.listStyle(.inset).transition(.opacity)
                }
            }.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(
                        "Close",
                        systemImage: "xmark",
                        role: .close,
                        action: tryDismiss
                    )
                    .confirmationDialog(
                        "Your task changes will be discarded",
                        isPresented: $showDiscardConfirmation,
                        titleVisibility: .visible,
                    ) {
                        Button("Discard", role: .destructive, action: discard)
                        Button("Cancel", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        "Save",
                        systemImage: "checkmark",
                        action: save
                    )
                    .buttonStyle(.glassProminent)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Add Task", systemImage: "plus") {
                        showNewTask = true
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.accent)
                }
            }
            .animation(.default, value: displayedTasks.isEmpty)
            .navigationTitle("What are we doing today?")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .interactiveDismissDisabled(hasChanges)
            .sheet(isPresented: $showNewTask) {
                NewTaskView(onSubmit: handleNewTask)
            }
        }
    }

    func deleteTasks(at offsets: IndexSet) {
        let tasksToDelete = offsets.map { displayedTasks[$0] }
        for task in tasksToDelete {
            if let index = pendingAdditions.firstIndex(of: task) {
                pendingAdditions.remove(at: index)
            } else {
                pendingDeletions.append(task)
            }
        }
    }

    func handleNewTask(_ task: MyTask) {
        pendingAdditions.append(task)
    }

    func save() {
        do {
            try modelContext.save()
        } catch {
            showDiscardConfirmation = true
            return
        }

        for task in pendingDeletions {
            modelContext.delete(task)
        }
        for task in pendingAdditions {
            modelContext.insert(task)
        }

        do {
            if modelContext.hasChanges {
                try modelContext.save()
            }

            onSubmit(hasChanges)
            dismiss()
        } catch {
            modelContext.rollback()
            showDiscardConfirmation = true
        }
    }

    func tryDismiss() {
        if hasChanges {
            showDiscardConfirmation = true
        } else {
            discard()
        }
    }

    func discard() {
        pendingDeletions = []
        pendingAdditions = []
        dismiss()
    }
}

#Preview("Empty") {
    EditTasksView { changed in }
}

#if DEBUG
#Preview("Populated") {
    EditTasksView { _ in }
        .modelContainer(mockContainer())
}
#endif
