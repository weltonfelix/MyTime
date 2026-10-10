//
//  SettingsView.swift
//  MyTime
//
//  Created by Welton Felix on 21/05/26.
//

import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("userInstructions") private var instructions: String = ""
    @Query(sort: \Hobby.createdAt) private var hobbies: [Hobby]
    @Environment(\.modelContext) private var modelContext

    @State private var isAdding: Bool = false
    @State private var newHobby: String = ""
    @FocusState private var isNewHobbyFocused: Bool

    @State var descriptionGenerator = HobbyDescriptionGenerator()

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Section("Hobbies") {
                        ForEach(hobbies) { hobby in
                            NavigationLink(value: hobby) {
                                HStack {
                                    Text(hobby.title)
                                    Spacer()
                                    if descriptionGenerator.pending.contains(hobby.persistentModelID) {
                                        ProgressView().accessibilityLabel("Preparing hobby details")
                                    }
                                }
                            }
                        }.onDelete(perform: handleHobbyDeletion)
                        if isAdding {
                            TextField("", text: $newHobby)
                                .focused($isNewHobbyFocused)
                                .onSubmit {
                                    handleNewHobby(promptForNew: true)
                                }
                                .onChange(of: isNewHobbyFocused) {
                                    _,
                                    focused in
                                    if !focused { handleNewHobby() }
                                }

                        }

                        Button("Add Hobby") {
                            withAnimation {
                                isAdding = true
                                isNewHobbyFocused = true
                            }
                        }.disabled(isAdding)

                    }
                    Section {
                        TextField(
                            "Additional Instructions",
                            text: $instructions,
                            axis: .vertical
                        )
                        .lineLimit(5...10)
                    } footer: {
                        Text(
                            "Choose more, fewer, or no hobbies; a busier or calmer day; low-energy activities; or short hobby sessions. Exact schedules are not supported."
                        )
                    }
                }
            }.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark", role: .close) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .alert("Could not prepare hobby details", isPresented: Binding(get: { !descriptionGenerator.errors.isEmpty }, set: { _ in })) {
                Button("OK", role: .cancel) {
                    if !descriptionGenerator.errors.isEmpty { descriptionGenerator.errors.removeFirst() }
                }
            } message: {
                Text(descriptionGenerator.errors.first ?? "")
            }
            .navigationDestination(for: Hobby.self) { hobby in
                HobbyDetailView(hobby: hobby, descriptionGenerator: descriptionGenerator, onClassificationError: reportClassificationError)
            }
        }
    }

    func handleNewHobby(promptForNew: Bool = false) {
        let hobby = newHobby.trimmingCharacters(in: .whitespacesAndNewlines)
        newHobby = ""

        guard !hobby.isEmpty else {
            withAnimation {
                isAdding = false
                isNewHobbyFocused = false
            }
            return
        }

        let createdHobby = Hobby(title: hobby, hobbyDescription: "")
        modelContext.insert(createdHobby)

        if promptForNew {
            isNewHobbyFocused = true
        } else {
            isNewHobbyFocused = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    isAdding = false
                }
            }
        }

        Task {
            await descriptionGenerator.prepare(createdHobby) { message in
                descriptionGenerator.errors.append(message)
            }
        }
    }

    private func reportClassificationError(_ error: Error) {
        descriptionGenerator.errors.append(OnDeviceAI.message(for: error))
    }

    func handleHobbyDeletion(indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(hobbies[index])
        }
    }
}

#Preview("Empty") {
    SettingsView()
}

#if DEBUG
#Preview("Populated") {
    SettingsView().modelContainer(mockContainer())
}
#endif
