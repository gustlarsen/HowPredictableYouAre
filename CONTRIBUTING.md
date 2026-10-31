# Contributing to How Predictable You Are

Thank you for your interest in contributing to **How Predictable You Are**! We welcome bug reports, feature suggestions, documentation improvements, and pull requests.

## 🛠️ Development Setup

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.20.0 or later)
- [Dart SDK](https://dart.dev/get-dart) (version 3.3.0 or later)
- An IDE with Flutter support (VS Code, Android Studio, or IntelliJ)

### Getting Started
1. Fork the repository on GitHub.
2. Clone your fork locally:
   ```bash
   git clone https://github.com/gustlarsen/HowPredictableYouAre.git
   cd HowPredictableYouAre
   ```
3. Navigate to either `VSCode` or `app`:
   ```bash
   cd VSCode
   flutter pub get
   ```
4. Run the automated test suite:
   ```bash
   flutter test
   ```
5. Run the application locally:
   ```bash
   flutter run
   ```

## 📋 Code Quality & Testing Guidelines

- Run `flutter analyze` before committing to ensure there are no linter warnings or errors.
- Ensure all automated unit and widget tests pass with `flutter test`.
- When adding a new feature or algorithm improvement (e.g. higher-order Markov chains), provide corresponding unit tests under `test/`.
- Maintain privacy-first principles: no external telemetry, tracking, or network transmission of player data.

## 📄 Licensing

By contributing to this repository, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
