# Development Roadmap – BINGO Mobile Game

This roadmap details the sequential milestones for taking the BINGO mobile game from initial architectural foundation to full production deployment.

---

## MILESTONE 1: Project Foundation & Architecture (Current Milestone)
* **Status**: Complete / Active Validation
* **Deliverables**:
  - Flutter & Dart project initialization with support for Android, iOS, Web, and Desktop.
  - Complete Stitch MCP design inspection and token extraction for all 16 screens ("Velvet Daub" design system).
  - Implementation of centralized design system: typography (`Outfit`), colors, spacing, radii, elevation.
  - Development of reusable shared widgets: `BingoLogo`, `PrimaryButton`, `SecondaryButton`, `AppCard`, `AppTextField`, `StatusBadge`, `PlayerAvatar`, `BingoCell`, `BingoBoardGrid`, `BingoProgressLetters`, `AppLoadingIndicator`.
  - GoRouter routing architecture with type-safe constants and guards for all 16 screens.
  - Riverpod state management foundation.
  - Supabase client integration contracts and environment templates.
  - Core game rules, technical architecture, and design inventory documentation.

---

## MILESTONE 2: Authentication & Player Profiles (Completed)
* **Status**: Complete / Verified (28/28 Unit & Widget Tests Green, Debug APK Built)
* **Deliverables**:
  - Full Supabase email/password authentication & guest mode integration in `AuthRepository` with graceful offline fallback.
  - Production database migration script (`docs/migrations/01_auth_and_profiles.sql`) with tables `profiles`, `player_statistics`, RLS security policies, and automatic profile trigger.
  - Complete `AuthScreen` matching Google Stitch Screen 2 (`152948b85345400fb54e55f8ba807a09`):
    - Segmented Create Account / Sign In switcher.
    - 2D 5×5 miniature preview board (cells 01–25).
    - Real-time email validation format indicator.
    - 3-tier password strength meter (Weak/Good/Strong) and confirm password matching checker.
    - Forgot Password recovery workflow with status notices.
    - Registration success celebration modal displaying Player ID tag (`#VTR-8821`), Codename, and 500 starting chips balance.
  - Complete `ProfileScreen` matching Google Stitch Screen 16 (`5e7e8a333408412990869a864a7b06f2`):
    - Player identity card with palette-colored avatar, display name, verified player badge, and member since date.
    - Performance 2×2 grid: Total Matches, Wins, Losses, Draws.
    - Win Rate metric card with rounded ratio bar and formula.
    - Winning streaks cards: Current Streak (with flame) & Best Streak (with star).
    - Personal Highlights card: Most wins in single room, highest lines claimed, longest streak, average calls.
    - Recent match history cards with victory/defeat/draw outcome tags.
    - Interactive Edit Profile modal dialog with 4 avatar color palettes (`#FC695C`, `#FFD166`, `#20243A`, `#E8E5FF`) and display name editing.
    - Audio & Game Settings bottom sheet (Sound effects & Haptic feedback toggles).
    - Sign out confirmation modal dialog with red destructive styling.
  - Caching & local storage resilience with `SharedPreferences` for user session, avatar palette, codename, and audio/haptics toggles.
  - 13 new unit and widget tests covering auth repository, profile repository, auth UI, and profile UI.

---

## MILESTONE 3: Core Bingo Game Engine
* **Focus**: Pure Dart, server-compatible board and game logic.
* **Tasks**:
  - Implement `BingoBoard` domain model (matrix generation, number placement validation, shuffle algorithms).
  - Implement `WinningLine` models (12 lines: 5 rows, 5 columns, 2 diagonals).
  - Implement the **Overlapping Line Rule**: ensure shared cells never invalidate independent lines.
  - Implement manual line claim detection and verification logic.
  - Implement `BingoLetterProgress` tracking ($B \to I \to N \to G \to O$).
  - Write comprehensive unit tests covering edge cases (simultaneous completions, diagonal intersections, full board draws).

---

## MILESTONE 4: Single Player Mode
* **Focus**: Local play against an AI opponent with difficulty settings.
* **Tasks**:
  - Build `SinglePlayerDifficultyScreen` with Easy, Medium, and Hard selections.
  - Build `BoardPreparationScreen` with drag-and-drop / tap-to-place numbers, quick shuffle, and board locking.
  - Develop computer AI logic:
    - *Easy*: Random number selection with instant line claims.
    - *Medium*: Balanced selection favoring near-complete lines.
    - *Hard*: Heuristic weighting evaluating intersection density across uncalled numbers.
  - Build interactive `SinglePlayerGameplayScreen` featuring top caller HUD, ball conveyor, B-I-N-G-O progress badges, and manual line claim action.
  - Build `SinglePlayerGameResultScreen` with rematch and score metrics.

---

## MILESTONE 5: Multiplayer Rooms & Lobby
* **Focus**: Private room governance, codes, and realtime participant presence.
* **Tasks**:
  - Deploy PostgreSQL migrations for `profiles`, `rooms`, and `room_players`.
  - Build `MultiplayerMenuScreen` (Create Room vs. Join with Code).
  - Build `CreateRoomScreen` with configurable capacity (2–4 players), preparation timer, and turn timer.
  - Build `JoinRoomScreen` with 6-character room code input and recent room history.
  - Build `MultiplayerLobbyScreen` (Waiting Room) using Supabase Realtime for live participant updates, host controls, ready toggles, and countdown triggers.

---

## MILESTONE 6: Multiplayer Gameplay Synchronization
* **Focus**: Server-authoritative turn execution and realtime match progression.
* **Tasks**:
  - Deploy PostgreSQL Stored Procedures / RPC:
    - `rpc_start_game`: validates ready players and locks room.
    - `rpc_call_number`: validates turn, registers called number, broadcasts to players.
    - `rpc_claim_line`: verifies line completion against player's secret board, updates letter progress, checks win conditions.
  - Build `MultiplayerBoardPreparationScreen` with synchronized UTC deadline countdown.
  - Build `MultiplayerGameplayScreen` with live turn banners, shared call history ribbon, and opponent presence chips.
  - Implement reconnection resilience: allow disconnected players to recover game state upon reconnecting.

---

## MILESTONE 7: Match Results, Leaderboards, & Persistent Statistics
* **Focus**: Session scoring, rankings, and historical records.
* **Tasks**:
  - Build `MultiplayerMatchResultScreen` celebrating winners and displaying podium standings.
  - Implement simultaneous winner resolution and tie-breaker statistics.
  - Build `DetailedRoomStatisticsScreen` displaying cumulative session scores, win streaks, and round logs.
  - Persist aggregate stats to `player_statistics` (wins, losses, win rate %, streaks) across all completed matches.
  - Add rematch voting allowing groups to play multiple rounds in the same room.

---

## MILESTONE 8: Final Polish, Hardening, & Production Readiness
* **Focus**: Production optimization, accessibility, and release builds.
* **Tasks**:
  - End-to-end integration testing and automated scenario tests.
  - UI refinement across small (320px), standard (360px–390px), and large screens.
  - Sound effects and tactile haptic feedback on number calls and line daubs.
  - Deep-linking configuration for seamless room invites via standard URLs.
  - Android App Bundle (AAB) and iOS Release Archive signing and packaging.
  - Production Supabase environment configuration and security audits.
