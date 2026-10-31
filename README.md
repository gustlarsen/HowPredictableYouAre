# How Predictable You Are 🎮🧠

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Tests](https://img.shields.io/badge/Tests-12%20Passing-success)](#automated-testing)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Web-blue)](#prerequisites--installation)

**How Predictable You Are** is an interactive, cross-platform casual strategy game and behavioral puzzle built with Flutter and Dart. Players face off against an adaptive algorithmic opponent in Rock-Paper-Scissors (and optional extended Lizard-Spock modes) that analyzes their subconscious decision patterns in real time using discrete Markov chain transition frequency matrices.

Originally conceived as a mobile prototype on Kodular, the project has been completely modernized into a clean, reactive, multiplatform Flutter application.

---

## 📖 Table of Contents
- [About The Project](#about-the-project)
  - [Who It's For](#who-its-for)
  - [How The Predictive Engine Works](#how-the-predictive-engine-works)
- [Key Features](#key-features)
- [Tech Stack & Architecture](#tech-stack--architecture)
- [Repository Structure](#repository-structure)
- [Getting Started & Running Locally](#getting-started--running-locally)
- [Automated Testing](#automated-testing)
- [Privacy & Offline Guarantee](#privacy--offline-guarantee)
- [Roadmap & Planned Work](#roadmap--planned-work)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 About The Project

Most humans believe their choices in Rock-Paper-Scissors are random. In reality, human decision-making is heavily influenced by subconscious patterns, win-stay/lose-shift heuristics, and transitional biases. 

**How Predictable You Are** turns this psychological reality into a game. As you play, the application constructs a real-time transition matrix tracking your likelihood of playing a specific hand given your previous hand. After a calibration period (100 rounds), the app grades your subconscious predictability across rigorous evaluation tiers ranging from *"Completely Unpredictable"* to *"Total Machine Food"*.

### 👥 Who It's For
- **Casual Gamers**: Anyone who enjoys fast-paced, intuitive casual strategy games with satisfying audio cues and progression.
- **Math & Probability Enthusiasts**: Players intrigued by stochastic processes, discrete probability tables, and game theory.
- **Developers & Learners**: Mobile and cross-platform engineers interested in clean Flutter architecture, state management with `ChangeNotifier`, custom transitions, and algorithmic game logic.

### 🧠 How The Predictive Engine Works
The game uses a discrete first-order **Markov Engine** (`MarkovEngine`):
1. **Transition Observation**: Every time the player chooses a hand $M_t$ after previously choosing $M_{t-1}$, the cell `Matrix[Index(M_{t-1})][Index(M_t)]` is incremented.
2. **Frequency Distribution**: When the player makes their next choice, the engine queries the transition row for their current hand:
   $$\text{Predicted Move} = \arg\max_{c} \left( \text{Matrix}[\text{LastMove}][c] \right)$$
3. **Counter-Strategy**: The algorithmic opponent automatically selects the dominant counter-hand (e.g., if predicted Rock, play Paper). If no statistical transition has been recorded yet or in the event of a tie, the opponent chooses randomly to prevent deterministic exploitation.
4. **Predictability Score**:
   $$\text{Predictability (\%)} = \frac{\text{Total Machine Victories}}{\text{Total Rounds Played}} \times 100$$
   Players must play at least 100 rounds to unlock their official evaluation rating.

---

## ✨ Key Features

- 🖐️ **Classic & Extended Hands**: Play standard **Rock, Paper, Scissors** or unlock **Lizard & Spock** (inspired by Sam Kass and Karen Bryla) for a 5x5 strategic matrix.
- 📊 **Real-Time Markov Matrix Visualizer**: Inspect the live transition table as you play to observe the exact patterns the computer is detecting.
- 💎 **Progression & In-Game Shop**: Earn diamonds through gameplay victories to unlock hint bars, predictability scores, algorithm inspection, and custom reset actions (all earned in-game; zero real-money in-app purchases).
- 🏆 **Predictability Evaluation Tiers**: Dynamic ratings calculated over 100+ rounds (e.g., *Under Evaluation*, *Unpredictable*, *Semi-Predictable*, *Predictable*, *Machine Food*).
- 🌍 **Full Localization (i18n)**: Multi-language support with instant in-game switching for **English**, **German (Deutsch)**, **Spanish (Español)**, and **Portuguese (Português)**.
- 🎨 **Modern Theming & Haptics**: Dark mode aesthetic, responsive card layouts, smooth scale animations, background soundtrack, sound effects, and haptic vibration feedback.
- 🔒 **100% Offline & Private**: Zero user tracking, zero network requests, zero personal data collection.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: [Flutter 3.x](https://flutter.dev) (Dart 3.x)
- **State Management**: `ChangeNotifier` & `ListenableBuilder` (Provider-style reactive state, lightweight and zero external overhead)
- **Local Persistence**: `shared_preferences` (persisting player unlockables, high scores, diamonds, and transition matrices across sessions)
- **Audio & Haptics**: `audioplayers` for dual BGM and SFX playback, with fallback wav and midi soundscapes.
- **Design Pattern**: Clean MVC (Model-View-Controller) architecture:
  ```
  lib/
  ├── controllers/       # GameController (state coordination, shop logic, round resolution)
  ├── models/            # HandMove (enums, win/loss rules), EvaluationTier (scoring tiers)
  ├── services/          # MarkovEngine, AudioService, LocalizationService, StorageService
  └── views/
      ├── dialogs/       # HelpDialog, SettingsDialog, ShopDialog
      ├── screens/       # GameScreen (main game loop and UI)
      └── widgets/       # HintsBar, MarkovMatrixView, ScoreHeader, VersusArena
  ```

---

## 📁 Repository Structure

```
HowPredictableYouAre/
├── .github/
│   └── ISSUE_TEMPLATE/     # GitHub issue templates for bug reports & features
├── VSCode/                 # Modernized Flutter application project
│   ├── android/            # Android platform configuration
│   ├── assets/             # Audio (wav/mid), images, and localization JSON
│   ├── ios/                # iOS platform configuration
│   ├── lib/                # Flutter Dart application source code
│   ├── test/               # Comprehensive automated test suite
│   ├── pubspec.yaml        # Flutter dependencies and asset registrations
│   └── README.md           # VSCode sub-folder workspace documentation
├── app/                    # Synced Flutter project directory
├── Kodular/                # Original MIT App Inventor / Kodular prototype archives (.aia)
├── .env.example            # Secrets & configuration template (demonstrating safe handling)
├── .gitignore              # Comprehensive Git ignore rules (secrets, build files, caches)
├── CONTRIBUTING.md         # Contribution guidelines and workflow
├── LICENSE                 # Permissive MIT Open-Source License
├── README.md               # Main repository documentation (this file)
└── ROADMAP.md              # Detailed 28+ hour engineering roadmap & milestones
```

---

## 🚀 Getting Started & Running Locally

### Prerequisites
- Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.20.0 or later).
- Ensure Dart is available on your PATH (`dart --version`).
- Connect an emulator, physical device, or use desktop targets (Windows, macOS, Linux, Chrome).

### Quickstart

1. **Clone the repository**:
   ```bash
   git clone https://github.com/gustlarsen/HowPredictableYouAre.git
   cd HowPredictableYouAre
   ```

2. **Navigate to the Flutter project folder**:
   ```bash
   cd VSCode
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the game**:
   ```bash
   flutter run
   ```
   *(To specify a target device, use `flutter run -d windows`, `flutter run -d chrome`, or `flutter run -d <device_id>`)*

---

## 🧪 Automated Testing

The project includes unit, state, and widget tests covering core game theory mechanics, transition recording, evaluation tier thresholds, and reactive controller behaviors:

```bash
cd VSCode
flutter test
```

### Test Coverage Highlights:
- **`markov_engine_test.dart`**: Validates initial zero-state, transition frequency accumulation, counter-move selection, tie-breaking heuristics, and 5-move extended rules (Rock-Paper-Scissors-Lizard-Spock).
- **`game_controller_test.dart`**: Verifies diamond economy deductions, shop item unlocking, independent state toggles, and persistent audio/vibration settings.
- **`widget_test.dart`**: Tests initial UI smoke loading, score header rendering, and hand button interactions.

---

## 🛡️ Privacy & Offline Guarantee

- **No Secrets**: This repository contains no private keys, passwords, API tokens, or credentials.
- **No Personal Data**: The application does not collect, process, or transmit personal data, identifiers, or behavioral telemetry.
- **Fully Offline**: All probability computations, state transitions, and save files reside strictly within local device sandbox storage (`SharedPreferences`).

---

## 🗺️ Roadmap & Planned Work

Active future development is tracked in [ROADMAP.md](ROADMAP.md), covering over **28 hours** of planned features and engineering milestones:

- **Adaptive Pattern Engine**: High-order Markov chains (2-grams, 3-grams) and exponential recency decay ($\lambda = 0.95$).
- **Local Pass-and-Play**: Split-screen two-player simultaneous input mode with dual predictability scoring.
- **Interactive Analytics**: Animated Markov state-transition directed graphs and real-time Shannon Entropy metrics.
- **Synthesizer Audio**: Pitch-shifting dynamic soundtrack responsive to player win/loss streaks.
- **CI/CD Automation**: GitHub Actions workflow for multi-platform artifact builds and golden widget testing.

---

## 🤝 Contributing

Contributions, bug reports, and suggestions are welcome! Please review [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on code style, branch management, and submitting pull requests.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for complete details.
