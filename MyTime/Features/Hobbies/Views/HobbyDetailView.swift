//
//  HobbyDetailView.swift
//  MyTime
//
//  Created by Welton Felix on 22/05/26.
//

import SwiftUI
import SwiftData

struct HobbyDetailView: View {
    @Bindable var hobby: Hobby
    var descriptionGenerator: HobbyDescriptionGenerator? = nil
    var onClassificationError: (Error) -> Void = { _ in }
    @State private var originalTitle: String = ""
    @State private var originalDescription: String = ""
    @State private var classifier = HobbyClassifier()

    var body: some View {
        VStack {
            List {
                Section {
                    if descriptionGenerator?.pending.contains(hobby.persistentModelID) == true {
                        ProgressView("Preparing hobby details")
                    }
                    TextField(
                        "Details",
                        text: $hobby.hobbyDescription,
                        axis: .vertical
                    )
                    .lineLimit(5...10)
                } footer: {
                    Text(
                        "The suggested description explains the activity. Edit it to add details relevant to your hobby."
                    )
                }
            }
        }
        .navigationTitle($hobby.title)
        .onAppear {
            originalTitle = hobby.title
            originalDescription = hobby.hobbyDescription
        }
        .onDisappear {
            guard descriptionGenerator?.pending.contains(hobby.persistentModelID) != true else { return }
            let titleChanged = hobby.title != originalTitle
            let descriptionChanged = hobby.hobbyDescription != originalDescription
            let notClassified = hobby.energyLevel == nil || hobby.minimumDurationInMinutes == nil
            
            guard titleChanged || descriptionChanged || notClassified else {
                return
            }
            
            Task {
                do {
                    try await classifier.classify(hobby: hobby)
                } catch {
                    onClassificationError(error)
                }
            }
        }
    }
}

#Preview {
    let hobby: Hobby = .init(title: "Correr", hobbyDescription: "")
    HobbyDetailView(hobby: hobby)
}
