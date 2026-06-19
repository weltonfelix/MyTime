# MyTime ⏳

MyTime is a smart, AI-powered daily routine planner for iOS. Built using **SwiftUI**, **SwiftData**, and **Apple Intelligence**, it dynamically translates your goals, habits, and tasks into a beautifully structured, balanced daily routine.

The app uses on-device Language Models to classify tasks, estimate their durations, and interleave hobbies as rejuvenating breaks to ensure you stay productive without burning out.

---

## 🚀 Key Features

*   **Apple Intelligence Task Classification**: Automatically classifies your daily tasks into various load profiles (`cognitiveHeavy`, `cognitiveMedium`, `cognitiveLight`, `physical`, `domestic`) and estimates durations using on-device Language Models.
*   **Smart Routine Scheduling**:
    *   Front-loads physical tasks in the morning to kickstart your day.
    *   Avoids scheduling consecutive heavy cognitive tasks.
    *   Uses domestic or light cognitive tasks as cognitive buffers.
    *   Interleaves your hobbies as breaks once accumulated focus time exceeds threshold limits.
*   **Live Activities & Dynamic Island**: Track your current Pomodoro task or hobby break duration right from your Lock Screen or Dynamic Island with live controls.
*   **Siri & App Intents**: Check or read your daily routine via Siri or Shortcuts using the built-in `GetDailyRoutineIntent`.
*   **SwiftData Integration**: Clean, local persistence of your daily routine, activities, hobbies, and tasks.

---

## 🛠️ Architecture & Tech Stack

The project follows a clean, modular structure:

*   **`MyTime` (Main App Target)**:
    *   **`App`**: Main entry point (`MyTimeApp.swift`).
    *   **`Core`**:
        *   `Algorithms`: Includes `RoutineGenerator`, `TaskClassifier` (AI classification), and `HobbySelector`.
        *   `Models`: Core SwiftData entities including `Routine`, `Activity`, `Hobby`, and `MyTask`.
        *   `Services`: Core utilities like `NotificationsService` and `SoundManager`.
    *   **`Features`**: SwiftUI feature views, ViewModels, and components for:
        *   `Home` (Main daily overview & timeline)
        *   `Tasks` (Adding and editing tasks)
        *   `Hobbies` (Managing hobbies)
        *   `Pomodoro` (Dedicated Pomodoro views)
        *   `Timer` (STOP/GO timing for hobbies)
    *   **`Intents`**: App Intents enabling Siri integration (`DailyRoutineIntent`, `PauseTimerIntent`).
*   **`MyTimePomodoro` (Widget Extension Target)**:
    *   Implements the Live Activity widget UI, including progress rings, play/pause controls, and Dynamic Island presentations.

---

## ⚙️ Requirements

*   **iOS 18.0+** / **macOS 15.0+**
*   **Xcode 16.0+**
*   **Swift 6.0+** (with support for Apple Intelligence APIs like `LanguageModelSession` and `@Generable`)
*   **Apple Intelligence** enabled on your test device/simulator.

---

## 📖 How to Get Started

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/weltonfelix/MyTime.git
    cd MyTime
    ```
2.  **Open in Xcode**: Open `MyTime.xcodeproj` in Xcode 16.
3.  **Enable Apple Intelligence**: Ensure that Apple Intelligence is active on your device or simulator to support task classification features.
4.  **Run the Target**: Select the `MyTime` target and run it on an eligible iOS Simulator or physical device.

---

## 📄 License

This project is licensed under the terms of the [LICENSE](LICENSE) file.
