//
//  ContentView.swift
//  MyTime
//
//  Created by Welton Felix on 15/05/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    private enum GenerationFocus: Hashable {
        case preparing
        case activity(PersistentIdentifier)
        case empty
    }

    @AccessibilityFocusState(for: .voiceOver) private var generationFocus: GenerationFocus?
    @State private var shouldAnnounceRoutineReady = false
    @State private var hobbyForOptions: Activity?
    @State private var showHobbyOptions = false
    @State private var path = NavigationPath()
    private let pomodoro = PomodoroViewModel.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var showEditTasks = false
    @State private var regenerateAfterEditingTasks = false
    @State private var showSettings = false
    @State private var descriptionGenerator = HobbyDescriptionGenerator()
    @State private var initialHobbies: Set<PersistentIdentifier> = []
    @State private var awaitingRegenerationOffer = false
    @State private var showRegenerationOffer = false
    @State private var showHobbyError = false
    @State private var failedGenerationPreservesCompletion = false
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
        NavigationStack(path: $path) {
            VStack {
                if isLoading {
                    ProgressView("Preparing your day...")
                        .padding()
                        .accessibilityLabel("Preparing your day")
                        .accessibilityFocused($generationFocus, equals: .preparing)
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
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text(task.taskDescription))
                                .accessibilityFocused($generationFocus, equals: .activity(activity.persistentModelID))
                                .accessibilityValue(activity.isCompleted ? Text("Completed") : Text("Not completed"))
                                .accessibilityHint("Opens the Pomodoro timer")
                                .accessibilityAction { path.append(task) }
                                .accessibilityAction(named: activity.isCompleted ? Text("Mark as incomplete") : Text("Mark as complete")) {
                                    activity.isCompleted.toggle()
                                }
                            } else if activity.hobby != nil {
                                NavigationLink(value: activity) {
                                    HobbyRow(
                                        activity: activity,
                                    ) {
                                        deleteHobbyActivity(activity)
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text(activity.hobby?.title ?? ""))
                                .accessibilityFocused($generationFocus, equals: .activity(activity.persistentModelID))
                                .accessibilityValue(Text("\((TimeInterval((activity.durationInMin ?? 0) * 60)).formattedForAccessibility). \(String(localized: activity.isCompleted ? "Completed" : "Not completed"))"))
                                .accessibilityAction(named: activity.isCompleted ? Text("Mark as incomplete") : Text("Mark as complete")) {
                                    activity.isCompleted.toggle()
                                }
                                .accessibilityHint("Opens the hobby timer")
                                .accessibilityAction { path.append(activity) }
                                .accessibilityAction(named: Text("Replace or remove hobby")) {
                                    hobbyForOptions = activity
                                    showHobbyOptions = true
                                }
                                .listRowBackground(
                                    LinearGradient.hobbyGradient.opacity(0.15)
                                )
                            }
                        }
                        .onMove(perform: moveActivity)
                        .listRowSeparator(.hidden)
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16)
                        )
                    }
                    .animation(.default, value: routine.activities.count)
                    .listStyle(.inset)

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
                        .accessibilityFocused($generationFocus, equals: .empty)
                    }
                }
            }
            .task(id: generationFocusTarget) {
                updateGenerationAccessibilityFocus()
            }
            .confirmationDialog("Replace or remove hobby", isPresented: $showHobbyOptions, titleVisibility: .visible) {
                ForEach(hobbies) { hobby in
                    Button(hobby.title) { hobbyForOptions?.hobby = hobby }
                }
                Button("Remove", role: .destructive) {
                    if let activity = hobbyForOptions { deleteHobbyActivity(activity) }
                }
                Button("Cancel", role: .cancel) {}
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
            .sheet(isPresented: $showEditTasks, onDismiss: {
                if regenerateAfterEditingTasks {
                    regenerateAfterEditingTasks = false
                    generateRoutine(preserveCompletion: true)
                }
                updateGenerationAccessibilityFocus()
            }) {
                EditTasksView(onSubmit: { hasChanges in
                    if hasChanges || (routine == nil && !tasks.isEmpty) {
                        regenerateAfterEditingTasks = true
                    }
                })
            }
            .sheet(isPresented: $showSettings, onDismiss: {
                awaitingRegenerationOffer = true
                presentPreferencesOutcome()
            }) {
                SettingsView(descriptionGenerator: descriptionGenerator)
            }
            .onChange(of: descriptionGenerator.pending) { _, _ in presentPreferencesOutcome() }
            .onChange(of: descriptionGenerator.errors) { _, _ in presentPreferencesOutcome() }
            .onChange(of: isLoading) { _, _ in presentPreferencesOutcome() }
            .onChange(of: showErrorAlert) { _, _ in presentPreferencesOutcome() }
            .onChange(of: showPreferenceNotice) { _, _ in presentPreferencesOutcome() }
            .alert("Regenerate routine?", isPresented: $showRegenerationOffer) {
                Button("Regenerate routine") {
                    generateRoutine(preserveCompletion: true)
                }
                Button("Keep routine", role: .cancel) {}
            } message: {
                Text("You added new hobbies. Would you like to update your routine to consider them?")
            }
            .alert("Could not prepare hobby details", isPresented: $showHobbyError) {
                Button("OK", role: .cancel) {
                    if !descriptionGenerator.errors.isEmpty { descriptionGenerator.errors.removeFirst() }
                    showHobbyError = false
                    presentPreferencesOutcome()
                }
            } message: {
                Text(descriptionGenerator.errors.first ?? "")
            }
            .alert(
                "There was an error generating your day",
                isPresented: $showErrorAlert
            ) {
                Button("Try Again") {
                    generateRoutine(preserveCompletion: failedGenerationPreservesCompletion)
                }
                Button("Generate Basic Routine") { generateRoutine(basic: true, preserveCompletion: failedGenerationPreservesCompletion) }
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
                PomodoroView(task: task).navigationTitle(task.taskDescription)
            }
            .navigationDestination(for: Activity.self) { activity in
                TimerView(durationInMinutes: activity.durationInMin ?? 30)
                    .navigationTitle(activity.hobby?.title ?? "Timer")
            }
            .safeAreaInset(edge: .bottom) {
                if pomodoro.hasSession, let task = tasks.first(where: { pomodoro.belongs(to: $0) }) {
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        Button {
                            path = NavigationPath()
                            path.append(task)
                        } label: {
                            HStack {
                                Image(systemName: "timer")
                                VStack(alignment: .leading) {
                                    Text("Return to Pomodoro").font(.headline)
                                    Text(task.taskDescription).font(.subheadline).lineLimit(1)
                                }
                                Spacer()
                                Text(pomodoro.displayTime(at: timeline.date).formattedAsTimer)
                                    .monospacedDigit()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                        }
                        .buttonStyle(.glass)
                        .padding(.horizontal)
                        .onChange(of: timeline.date) { _, now in
                            Task { await pomodoro.advanceStage(at: now) }
                        }
                    }
                }
            }
            .onOpenURL { url in
                guard let id = pomodoro.taskID(for: url),
                      let task = tasks.first(where: { $0.persistentModelID == id }) else { return }
                showEditTasks = false
                showSettings = false
                path = NavigationPath()
                path.append(task)
            }
            .task { await pomodoro.reconcile(tasks: tasks) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await pomodoro.reconcile(tasks: tasks) } }
            }
            .onChange(of: tasks.map(\.persistentModelID)) { _, _ in
                Task { await pomodoro.reconcile(tasks: tasks) }
            }
            .onAppear(perform: deleteOldRoutines)
        }
    }

    private var generationFocusTarget: GenerationFocus? {
        guard !showEditTasks, !showSettings, !showRegenerationOffer,
              !showErrorAlert, !showPreferenceNotice, !showHobbyError, path.isEmpty else { return nil }
        if isLoading { return .preparing }
        guard shouldAnnounceRoutineReady else { return nil }
        if let first = routine?.activities.sorted(by: { $0.order < $1.order })
            .first(where: { $0.task != nil || $0.hobby != nil }) {
            return .activity(first.persistentModelID)
        }
        return .empty
    }

    private func updateGenerationAccessibilityFocus() {
        guard let target = generationFocusTarget else { return }
        generationFocus = target
        if shouldAnnounceRoutineReady && !isLoading {
            shouldAnnounceRoutineReady = false
            var announcement = AttributedString(String(localized: "Your day is ready"))
            announcement.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    func deleteOldRoutines() {
        if let routine, !Calendar.current.isDateInToday(routine.date) {
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
        initialHobbies = Set(hobbies.map(\.persistentModelID))
        awaitingRegenerationOffer = false
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

    func presentPreferencesOutcome() {
        guard !showSettings, !isLoading, !showErrorAlert, !showPreferenceNotice,
              !showHobbyError, !showRegenerationOffer, descriptionGenerator.pending.isEmpty else { return }
        if !descriptionGenerator.errors.isEmpty {
            showHobbyError = true
            return
        }
        guard awaitingRegenerationOffer else { return }
        awaitingRegenerationOffer = false
        showRegenerationOffer = HobbyRegeneration.shouldOffer(initial: initialHobbies,
            current: Set(hobbies.map(\.persistentModelID)), routineDate: routine?.date)
    }

    func generateRoutine(basic: Bool = false, preserveCompletion: Bool = false) {
        guard !isLoading else { return }
        shouldAnnounceRoutineReady = false
        generationFocus = nil
        isLoading = true
        failedGenerationPreservesCompletion = preserveCompletion
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
                try RoutinePersistence.replace(with: draft, in: modelContext, preserveCompletion: preserveCompletion)
                shouldAnnounceRoutineReady = true
                showPreferenceNotice = unsupported
            } catch {
                generationMessage = OnDeviceAI.message(for: error)
                showErrorAlert = true
            }
        }
    }

}

#if DEBUG
#Preview("Populated") {
    ContentView()
        .modelContainer(mockContainer())
}
#endif

#Preview("Empty") {
    ContentView()
}
