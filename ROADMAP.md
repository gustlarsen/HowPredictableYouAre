# 🗺️ Project Roadmap & Development Plan

This document outlines the planned future development for **How Predictable You Are**, representing over **28+ hours** of active feature development, performance optimization, architectural refactoring, and test coverage expansion.

---

## 📊 Summary of Planned Work

| Phase | Milestone | Focus Area | Estimated Effort | Status |
|---|---|---|---|---|
| **Phase 1** | Adaptive Pattern Engine & Markov N-Gram Models | Algorithm / Core Logic | 6 Hours | 📋 Planned |
| **Phase 2** | Local Pass-and-Play & Asymmetric Duel Mode | Features / Game Modes | 5 Hours | 📋 Planned |
| **Phase 3** | Interactive Analytics & Historical Visualizations | UI / UX / Data Viz | 5 Hours | 📋 Planned |
| **Phase 4** | Synthesizer Audio Engine & Reactive Soundscapes | Audio / Multimedia | 4 Hours | 📋 Planned |
| **Phase 5** | Accessibility, Haptics & Localization Overhaul | Accessibility / i18n | 4 Hours | 📋 Planned |
| **Phase 6** | CI/CD Automation & End-to-End Golden Testing | DevOps / Quality Assurance | 4 Hours | 📋 Planned |
| **Total** | | | **28 Hours** | |

---

## 🎯 Phase 1: Adaptive Pattern Engine & Markov N-Gram Models (~6 Hours)
- [ ] **Second-Order Markov Chains (2-gram model)**:
  - Extend prediction capability from 1st-order (previous single move) to 2nd-order (previous sequence of 2 moves: `(move[t-2], move[t-1]) -> move[t]`).
  - Introduce dynamic weight blending: blend 1st-order and 2nd-order probabilities using a weighted confidence metric.
- [ ] **Decay Weighting / Recency Bias Factor**:
  - Implement an exponential decay factor ($\lambda \approx 0.95$) so that older player moves carry less weight than recent tendencies, allowing the algorithm to quickly adapt when the player intentionally switches strategies.
- [ ] **Custom Opponent Personalities**:
  - Add selectable computer playstyles:
    - *The Mirror*: Anticipates player will repeat their previous move.
    - *The Counter-Attacker*: Plays against the move that would have defeated the player's last choice.
    - *The Grandmaster*: Pure high-order Markov with entropy minimization.
- [ ] **Unit Test Expansion**:
  - Add regression test suites for 2-gram probability distributions and decay factor convergence.

---

## 🎮 Phase 2: Local Pass-and-Play & Dual Play Modes (~5 Hours)
- [ ] **Pass-and-Play Two Player Mode**:
  - Add a split-screen or sequential local duel mode for two human players on the same device.
  - Track head-to-head predictability scores between both players simultaneously.
- [ ] **Blind Reveal & Simultaneous Input Mechanics**:
  - Create a card-flip animation where each player locks in their selection secretly before simultaneous reveal.
- [ ] **Streak Challenges & Boss Battles**:
  - Introduce themed rounds (e.g., "Defeat 5 consecutive predictive moves without a draw").
  - Unlock special visual themes and card badges for completing challenge ladders.

---

## 📈 Phase 3: Interactive Analytics & Visual Transition Graphs (~5 Hours)
- [ ] **Interactive Markov State Transition Graph**:
  - Replace static grid matrix with an animated directed graph (nodes for Rock, Paper, Scissors; edges representing transition likelihoods).
- [ ] **Entropy & Randomness Meter**:
  - Compute Shannon entropy ($H(X) = -\sum P(x) \log_2 P(x)$) of player moves over the last 20, 50, and 100 rounds.
  - Display a real-time "Subconscious Predictability Gauge" comparing human choice randomness against true pseudo-random distributions.
- [ ] **Match History Export & Data Inspection**:
  - Provide a clean JSON / CSV export dialog so players can inspect their session history offline.
  - Ensure zero cloud transmissions to preserve 100% offline privacy.

---

## 🎵 Phase 4: Synthesizer Audio Engine & Dynamic Soundscapes (~4 Hours)
- [ ] **Audio Engine Refactor**:
  - Abstract audio layer with dedicated background channel and sound-effects bus.
  - Preload sound buffers to eliminate latency on mobile devices.
- [ ] **Adaptive Dynamic Music Pitch**:
  - Modulate background music tempo and pitch dynamically based on the current player win/loss streak.
- [ ] **Custom Sound Packs**:
  - Add retro 8-bit sound effects pack and modern orchestral cues unlockable in the Diamonds shop.

---

## 🌐 Phase 5: Accessibility, Haptic Customization & Localization (~4 Hours)
- [ ] **Expanded Localization**:
  - Complete Italian, French, and Japanese translations for strings in `stringsHowPredict.json`.
  - Add dynamic RTL support for Arabic / Hebrew.
- [ ] **Accessibility (Semantics & Screen Readers)**:
  - Ensure all hand buttons and score headers have descriptive Flutter `Semantics` tags.
  - Provide high-contrast color palette option for visually impaired players.
- [ ] **Granular Haptic Feedback**:
  - Support distinct vibration patterns for Victory, Defeat, Draw, and Shop Unlock events using native system haptic feedback APIs.

---

## 🧪 Phase 6: CI/CD Pipeline & End-to-End Testing (~4 Hours)
- [ ] **GitHub Actions Workflow**:
  - Automated pull request verification: `flutter analyze` and `flutter test`.
  - Multi-platform build verification for Android APK, Windows executable, and Web.
- [ ] **Golden Widget Tests**:
  - Implement golden snapshot tests for `GameScreen`, `MarkovMatrixView`, `ScoreHeader`, and `ShopDialog` to catch UI regressions across light and dark modes.
- [ ] **Automated Release Packaging**:
  - Fastlane or GitHub release script to build and sign multi-platform release artifacts automatically.
