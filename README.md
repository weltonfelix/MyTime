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

*   **iOS 26.0+**
*   **Xcode 27.0+**
*   The Swift toolchain bundled with Xcode 27 (including `LanguageModelSession` and `@Generable`)
*   **Apple Intelligence** enabled on your test device/simulator.

---

## 📖 How to Get Started

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/weltonfelix/MyTime.git
    cd MyTime
    ```
2.  **Open in Xcode**: Open `MyTime.xcodeproj` in Xcode 27.
3.  **Enable Apple Intelligence**: Ensure that Apple Intelligence is active on your device or simulator to support task classification features.
4.  **Run the Target**: Select the `MyTime` target and run it on an eligible iOS Simulator or physical device.

---

## On-device interpretation and tests

`SystemLanguageModel.default` uses the model provided by the installed OS, including
its iOS 27 improvements. Requests classify one task or hobby at a time; a separate
request interprets bounded preferences. Swift calculates the routine and time budget.
If AI is unavailable or fails, the user can explicitly choose **Generate Basic Routine**.
The previous routine is retained until a validated replacement saves successfully.

Run the `MyTime` scheme's tests for validation, budgets, stale inputs, and SwiftData
replacement/rollback. Live model tests are opt-in: set `MYTIME_RUN_MODEL_TESTS=1`
as a build setting (or the test scheme environment variable) on an eligible test device.
The test scheme uses an in-memory app store so test-host startup cannot change saved routines.
A physical-device test run still installs the development build.
The live fixtures cover English and Portuguese, negation, conflicting preferences,
unsupported schedules, and repeated independent requests. Their inference latency is printed.
Passing deterministic tests does not establish model accuracy on an iPhone.

## 📄 License

This project is licensed under the terms of the [LICENSE](LICENSE) file.
