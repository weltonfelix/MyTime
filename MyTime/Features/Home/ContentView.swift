//
//  ContentView.swift
//  MyTime
//
//  Created by Welton Felix on 15/05/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var showEditTasks = false
    @State private var showSettings = false
    @State private var showErrorAlert: Bool = false
    @State private var isLoading: Bool = false

    private var tasksClassifier = TaskClassifier()

    @AppStorage("userInstructions") private var instructions: String = ""

    @Query var routines: [Routine]
    var routine: Routine? {
        routines.first
    }
    @Query var hobbies: [Hobby]
    @Query var tasks: [MyTask]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack {
                if let routine, !routine.activities.isEmpty {
                    List {
                        ForEach(
                            routine.activities.sorted(by: {
                                $0.order < $1.order
                            })
                        ) { activity in
                            if let task = activity.task {
                                NavigationLink(value: task) {
                                    TaskRow(activity: activity)
                                }
                            } else if activity.hobby != nil {
                                HobbyRow(
                                    activity: activity,
                                ) {
                                    deleteHobbyActivity(activity)
                                }
                            }
                        }
                        .onMove(perform: moveActivity)
                        .listRowSeparator(.hidden)
                    }
                    .animation(.default, value: routine.activities.count)
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: 0,
                            bottom: 0,
                            trailing: 16
                        )
                    ).listStyle(.inset)

                } else {
                    if isLoading {
                        VStack {
                            ProgressView()
                            Text("Preparando seu dia...")
                        }
                    } else {
                        ContentUnavailableView {
                            VStack {
                                ZStack {
                                    Color.accent
                                        .opacity(0.15)
                                        .frame(width: 50, height: 50)
                                        .clipShape(.circle)
                                    Image(systemName: "sun.horizon.fill")
                                        .foregroundStyle(.accent)
                                }
                                Text("Rotina Vazia").fontWeight(.semibold)
                            }.font(.title2)

                        } description: {
                            Text("Seu dia está bem calmo")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        } actions: {
                            Button("Adicionar Tarefas", action: showTasksSheet)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(
                        "Preferências",
                        systemImage: "gear",
                        action: showSettingsSheet
                    )
                }
                ToolbarItem {
                    Button("Editar Tarefas", action: showTasksSheet)
                }
            }.navigationTitle("Meu Dia")
            .navigationSubtitle(
                Date().formatted(
                    .dateTime.weekday(.wide).month(.wide).day(.defaultDigits)
                )
            )
            .sheet(isPresented: $showEditTasks) {
                EditTasksView(onSubmit: { hasChanges in
                    if hasChanges { generateRoutine() }
                })
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert(
                "Houve um erro ao gerar seu dia",
                isPresented: $showErrorAlert
            ) {
                Button("Tentar Novamente") {
                    generateRoutine()
                }
                Button("Cancelar", role: .cancel) {}
            }
            .navigationDestination(for: MyTask.self) { task in
                PomodoroView().navigationTitle(task.taskDescription)
            }
            .onAppear(perform: deleteOldRoutines)
            .onAppear {
                Task {
                    await NotificationsService.shared.requestAuthorization()
                }
            }
        }
    }

    func deleteOldRoutines() {
        let routineDate = routine?.date ?? .distantPast

        if !Calendar.current.isDateInToday(routineDate) {
            routines.forEach(modelContext.delete)
            tasks.forEach(modelContext.delete)
        }

        if routines.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showTasksSheet()
            }
        }
    }

    func showSettingsSheet() {
        showSettings = true
    }

    func showTasksSheet() {
        showEditTasks = true
    }

    func moveActivity(from prevPos: IndexSet, to newPos: Int) {
        guard let routine else { return }

        var updated = routine.activities.sorted(by: { $0.order < $1.order })
        updated.move(fromOffsets: prevPos, toOffset: newPos)
        for (index, activity) in updated.enumerated() {
            activity.order = index
        }

    }

    func deleteHobbyActivity(_ activity: Activity) {
        routine?.activities.removeAll { $0.id == activity.id }
        modelContext.delete(activity)
    }

    func generateRoutine() {
        isLoading = true
        Task {
            do {
                for routine in routines {
                    modelContext.delete(routine)
                }
                try modelContext.save()

                let classifiedTasks = try await tasksClassifier.classify(
                    tasks: tasks
                )

                let routineGenerator = RoutineGenerator(
                    instructions: instructions
                )

                let newRoutine = routineGenerator.generate(
                    tasks: classifiedTasks,
                    hobbies: hobbies
                )
                modelContext.insert(newRoutine)

                try modelContext.save()

            } catch {
                print(error.localizedDescription)
                showErrorAlert = true
            }
            isLoading = false
        }
    }

}

#Preview("Populated") {
    do {
        return ContentView()
            .modelContainer(try mockContainer())
    } catch {
        return Text("Failed to create container: \(error.localizedDescription)")
    }
}

#Preview("Empty") {
    ContentView()
}
