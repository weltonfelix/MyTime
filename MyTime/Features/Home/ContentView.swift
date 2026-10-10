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

    @State private var generationMessage = ""
    @State private var showPreferenceNotice = false

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
                if isLoading {
                    ProgressView("Preparing your day...")
                        .padding()
                        .accessibilityLabel("Preparing your day")
                } else if let routine, !routine.activities.isEmpty {
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
                    if !isLoading {
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
                Button("Generate Basic Routine") { generateRoutine(basic: true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(generationMessage + "\n\n" + String(localized: "Basic routines use local rules and reserve 30 minutes per task when estimating time for hobbies."))
            }
            .alert("Some preferences could not be applied", isPresented: $showPreferenceNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("MyTime supports hobby amounts, available time, energy, and short sessions. Exact times, deadlines, and specific activity ordering are not supported.")
            }
            .navigationDestination(for: MyTask.self) { task in
                PomodoroView().navigationTitle(task.taskDescription)
            }
            .navigationDestination(for: Activity.self) { activity in
                TimerView(durationInMinutes: activity.durationInMin ?? 30)
                    .navigationTitle(activity.hobby?.title ?? "Timer")
            }
            .onAppear(perform: deleteOldRoutines)
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

    func generateRoutine(basic: Bool = false) {
        guard !isLoading else { return }
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            do {
                try modelContext.save()
                let inputTasks = try modelContext.fetch(FetchDescriptor<MyTask>())
                let inputHobbies = try modelContext.fetch(FetchDescriptor<Hobby>())
                let inputInstructions = instructions
                let snapshot = RoutineSnapshot(tasks: inputTasks, hobbies: inputHobbies, instructions: inputInstructions)
                let preferences: UserInstructionsParser.Adjustments
                let classifiedTasks: [MatchedTask]
                var unsupported = false
                if basic {
                    preferences = UserInstructionsParser.parse(inputInstructions)
                    classifiedTasks = inputTasks.map { MatchedTask(task: $0, classification: nil) }
                } else {
                    try OnDeviceAI.checkAvailability()
                    let interpretation = try await PreferenceInterpreter.interpret(inputInstructions)
                    preferences = interpretation.adjustments
                    unsupported = interpretation.hasUnsupportedRequests
                    classifiedTasks = try await tasksClassifier.classify(tasks: inputTasks)
                }
                try Task.checkCancellation()
                let current = RoutineSnapshot(
                    tasks: try modelContext.fetch(FetchDescriptor<MyTask>()),
                    hobbies: try modelContext.fetch(FetchDescriptor<Hobby>()), instructions: instructions)
                guard snapshot == current else { throw OnDeviceAI.Failure.staleInput }
                let draft = try RoutineGenerator(preferences: preferences).generate(tasks: classifiedTasks, hobbies: inputHobbies)
                try RoutinePersistence.replace(with: draft, in: modelContext)
                showPreferenceNotice = unsupported
            } catch {
                generationMessage = OnDeviceAI.message(for: error)
                showErrorAlert = true
            }
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
