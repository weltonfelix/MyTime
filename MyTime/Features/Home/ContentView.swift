//
//  ContentView.swift
//  MyTime
//
//  Created by Welton Felix on 15/05/26.
//

import FoundationModels
import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var showEditTasks = false
    @State private var showSettings = false
    @State private var showErrorAlert: Bool = false

    @State private var showAINotAvailable: Bool = false
    @State private var aiNotAvailableMessage: String?

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
                                NavigationLink(value: activity) {
                                    HobbyRow(
                                        activity: activity,
                                    ) {
                                        deleteHobbyActivity(activity)
                                    }
                                }.listRowBackground(
                                    LinearGradient.hobbyGradient.opacity(0.15)
                                )
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
                            Text("Preparing your day...")
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
                                Text("Empty Routine").fontWeight(.semibold)
                            }.font(.title2)

                        } description: {
                            Text("Your day is wide open")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        } actions: {
                            Button("Add Tasks", action: showTasksSheet)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(
                        "Preferences",
                        systemImage: "gear",
                        action: showSettingsSheet
                    )
                }
                ToolbarItem {
                    Button("Edit Tasks", action: showTasksSheet)
                }
            }.navigationTitle("My Day")
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
                "There was an error generating your day",
                isPresented: $showErrorAlert
            ) {
                Button("Try Again") {
                    generateRoutine()
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(aiNotAvailableMessage ?? "Apple Inteligence is not available", isPresented: $showAINotAvailable) {}
            .navigationDestination(for: MyTask.self) { task in
                PomodoroView().navigationTitle(task.taskDescription)
            }
            .navigationDestination(for: Activity.self) { activity in
                TimerView(durationInMinutes: activity.durationInMin ?? 30)
                    .navigationTitle(activity.hobby?.title ?? "Timer")
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
        guard SystemLanguageModel.default.isAvailable else {
            aiNotAvailableMessage =
                switch SystemLanguageModel.default.availability {
                case .unavailable(.deviceNotEligible):
                    String(
                        localized:
                            "This device is not eligible for Apple Intelligence"
                    )
                case .unavailable(.appleIntelligenceNotEnabled):
                    String(
                        localized:
                            "You must enable Apple Intelligence in Settings"
                    )
                case .unavailable(.modelNotReady):
                    String(localized: "Apple Intelligence is not ready")
                case .unavailable:
                    String(localized: "Unknown Apple Intelligence error")
                default: ""
                }
            
            showAINotAvailable = true
            return
        }

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
