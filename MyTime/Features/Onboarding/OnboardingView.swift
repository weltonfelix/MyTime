import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var step = 0
    @State private var isRequestingPermission = false
    @AccessibilityFocusState private var isHeadingFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var title: LocalizedStringKey {
        switch step {
        case 0: "Plan your day"
        case 1: "Make room for hobbies"
        case 2: "Focus one activity at a time"
        default: "Know when time is up"
        }
    }

    private var description: LocalizedStringKey {
        switch step {
        case 0: "Add your tasks and MyTime will organize them into a balanced daily routine."
        case 1: "Enjoy hobby breaks between tasks. Add your hobbies and tell MyTime how you like to organize your day in Preferences."
        case 2: "Use Pomodoro sessions to focus on tasks and a timer to enjoy your hobby breaks. Open an activity in My Day to get started."
        default: "Allow notifications to hear when a focus session or hobby timer finishes, even when MyTime is in the background."
        }
    }

    private var symbol: String {
        switch step {
        case 0: "sun.horizon.fill"
        case 1: "sparkles"
        case 2: "timer"
        default: "bell.badge.fill"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: symbol)
                            .font(.largeTitle.scaled(by: 2))
                            .foregroundStyle(step == 1 ? LinearGradient.hobbyGradient : accentGradient)
                            .padding(32)
                            .background(.tint.opacity(0.1), in: .circle)
                            .accessibilityHidden(true)
                    }

                    Text(title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isHeadingFocused)

                    Text(description)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    if step == 0 {
                        Label("Routine generation requires Apple Intelligence enabled on a compatible device.", systemImage: "apple.intelligence")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 {
                        Button("Back", systemImage: "chevron.left") {
                            step -= 1
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", action: onComplete)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    ProgressView(value: Double(step + 1), total: 4)
                        .accessibilityLabel("Onboarding progress")
                        .accessibilityValue(Text("Step \(step + 1) of 4"))

                    if step == 3 {
                        Button(action: enableNotifications) {
                            HStack {
                                if isRequestingPermission {
                                    ProgressView()
                                }
                                Text("Enable Notifications")
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glassProminent)

                        Button("Not Now", action: onComplete)
                            .frame(minHeight: 44)
                    } else {
                        Button {
                            step += 1
                        } label: {
                            Text("Next")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.bar)
            }
            .disabled(isRequestingPermission)
            .onChange(of: step) {
                isHeadingFocused = true
            }
        }
    }

    private var accentGradient: LinearGradient {
        LinearGradient(colors: [.accentColor, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func enableNotifications() {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        Task { @MainActor in
            await NotificationsService.shared.requestAuthorization()
            onComplete()
        }
    }
}

#Preview("English") {
    OnboardingView {}
}

#Preview("Portuguese") {
    OnboardingView {}
        .environment(\.locale, Locale(identifier: "pt_BR"))
}
