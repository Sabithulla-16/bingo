# BINGO – Multiplayer Mobile Game

A turn-based mobile board game built with **Flutter**, **Dart**, **Riverpod**, and **GoRouter**, styled according to the **"Velvet Daub"** design system extracted from **Google Stitch**.

---

## Overview

BINGO is a turn-based board game where players arrange their own $5 \times 5$ number boards (numbers 1–25) and compete to complete and manually claim 5 winning lines ($B \to I \to N \to G \to O$). It supports both single player vs. a strategic computer opponent and private 2–4 player multiplayer rooms.

---

## Key Architectural Principles

1. **Feature-First Organization**: Clear separation between Views, ViewModels, Repositories, and Services.
2. **Server-Authoritative Multiplayer**: PostgreSQL and backend functions/RPC serve as the single source of truth for match turns, call validations, line completions, and victories.
3. **Overlapping Line Invariant**: Claiming one line never disables or invalidates an overlapping line sharing common cells.
4. **Design Fidelity**: Strict adherence to the Velvet Daub Stitch tokens (Outfit typography, `#FAFAF7` warm canvas, `#20243A` Midnight Navy, `#FF6B5E` Coral, `#FFD166` Soft Yellow, `#E8E5FF` Lavender).

---

## Project Structure

```
lib/
├── main.dart                                # Application entry point
├── app/
│   ├── bingo_app.dart                       # MaterialApp.router configuration
│   ├── bootstrap.dart                       # Async binding & initialization
│   ├── router/
│   │   ├── app_router.dart                  # GoRouter configuration for all 16 screens
│   │   ├── app_routes.dart                  # Centralized type-safe route constants
│   │   └── route_guards.dart                # Session-aware auth redirects
│   └── theme/
│       ├── app_theme.dart                   # Customized Material 3 ThemeData
│       ├── app_colors.dart                  # Velvet Daub color tokens
│       ├── app_typography.dart              # Outfit font styles & tabular figures
│       ├── app_spacing.dart                 # Layout spacing & padding units
│       ├── app_dimensions.dart              # Sizing constraints & touch targets
│       └── app_radii.dart                   # Border radii tokens
├── core/
│   ├── config/app_config.dart               # Environment & credentials loader
│   ├── constants/app_constants.dart         # Grid dimensions, timers, letters
│   ├── errors/                              # AppException, AppFailure, domain errors
│   └── widgets/
│       ├── bingo_logo.dart                  # Canonical BINGO brand component
│       ├── primary_button.dart              # Primary coral action pill
│       ├── secondary_button.dart            # Midnight navy secondary pill
│       ├── app_card.dart                    # Flat paper-style card container
│       ├── app_text_field.dart              # Low-surface custom text input
│       ├── status_badge.dart                # Status pill badge
│       ├── player_avatar.dart               # Circular player avatar token
│       ├── bingo_cell.dart                  # 5x5 cell with 4 visual states
│       ├── bingo_board_grid.dart            # Responsive 5x5 board grid
│       ├── bingo_progress_letters.dart      # B-I-N-G-O progress letter badges
│       ├── room_badge.dart                  # Room code pill with clipboard copy
│       ├── app_loading_indicator.dart       # 3-dot animated bouncing indicator
│       ├── confirmation_dialog.dart         # Modal confirmation dialog
│       └── responsive_scaffold.dart         # Safe-area & keyboard-resilient wrapper
├── data/
│   └── supabase/
│       ├── supabase_service.dart            # Supabase SDK initialization
│       └── supabase_provider.dart           # Riverpod providers & AuthStateNotifier
└── features/
    ├── splash/presentation/                 # Screen 1: Splash Screen
    ├── authentication/                      # Screen 2: Create Account / Sign In
    ├── home/presentation/                   # Screen 3: Home Screen
    ├── single_player/
    │   ├── difficulty/                      # Screen 4: Difficulty Selection
    │   ├── board_preparation/               # Screen 5: Board Setup
    │   ├── gameplay/                        # Screen 6: Gameplay
    │   └── result/                          # Screen 7: Result
    ├── multiplayer/
    │   ├── menu/                            # Screen 8: Multiplayer Menu
    │   ├── create_room/                     # Screen 9: Create Room Settings
    │   ├── join_room/                       # Screen 10: Join Room
    │   ├── lobby/                           # Screen 11: Waiting Room
    │   ├── board_preparation/               # Screen 12: Board Setup
    │   ├── gameplay/                        # Screen 13: Gameplay
    │   └── result/                          # Screen 14: Match Result & Leaderboard
    ├── room_statistics/presentation/        # Screen 15: Detailed Room Stats
    └── profile/presentation/                # Screen 16: Player Profile
```

---

## Screen Route Map (All 16 Screens)

| # | Screen Name | Route Constant | Path |
|---|---|---|---|
| 1 | Splash Screen | `AppRoutes.splash` | `/splash` |
| 2 | Create Account / Sign In | `AppRoutes.auth` | `/auth` |
| 3 | Home Screen | `AppRoutes.home` | `/home` |
| 4 | Difficulty Selection | `AppRoutes.singlePlayerDifficulty` | `/single-player/difficulty` |
| 5 | Single Player Board Prep | `AppRoutes.singlePlayerBoardPrep` | `/single-player/board-preparation` |
| 6 | Single Player Gameplay | `AppRoutes.singlePlayerGame` | `/single-player/game/:gameId` |
| 7 | Single Player Result | `AppRoutes.singlePlayerResult` | `/single-player/result/:gameId` |
| 8 | Multiplayer Menu | `AppRoutes.multiplayerMenu` | `/multiplayer` |
| 9 | Create Room Settings | `AppRoutes.createRoom` | `/multiplayer/create-room` |
| 10 | Join Room | `AppRoutes.joinRoom` | `/multiplayer/join-room` |
| 11 | Waiting Lobby | `AppRoutes.roomLobby` | `/multiplayer/room/:roomId/lobby` |
| 12 | Multiplayer Board Prep | `AppRoutes.roomBoardPrep` | `/multiplayer/room/:roomId/board-preparation` |
| 13 | Multiplayer Gameplay | `AppRoutes.roomGame` | `/multiplayer/room/:roomId/game` |
| 14 | Multiplayer Result & Rank | `AppRoutes.roomResult` | `/multiplayer/room/:roomId/result` |
| 15 | Room Statistics | `AppRoutes.roomStatistics` | `/multiplayer/room/:roomId/statistics` |
| 16 | Player Profile | `AppRoutes.profile` | `/profile` |

---

## Setup & Run Instructions

### Prerequisites
* Flutter SDK (3.41+ stable)
* Dart SDK (3.11+ stable)
* Android Studio / Xcode (for Android and iOS mobile targets)

### Environment Configuration
Copy `.env.example` to `.env` or provide environment variables at run/build time:
```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=your-anon-key
```

### Running the App
```bash
# Get dependencies
flutter pub get

# Run on connected device / emulator
flutter run
```

### Running Quality Checks & Tests
```bash
# Code format check
dart format .

# Static analysis
flutter analyze

# Unit & Widget test suite
flutter test
```

---

## Documentation Index
* [Stitch Design Inventory](docs/stitch-design-inventory.md): Full mapping of all 16 Stitch screens, design dimensions, and component inventory.
* [Game Rules & Mechanics](docs/game-rules.md): Game rules, overlapping line logic, turn order, and scoring.
* [Application & Backend Architecture](docs/architecture.md): Data flow, Riverpod topology, PostgreSQL schema, RLS policies, and RPC definitions.
* [Development Roadmap](docs/development-roadmap.md): Milestone breakdown from project foundation through production release.
