# BINGO

## Complete Game Design Document & Technical Specification

**Platform:** Android and iOS
**Category:** Turn-Based Board Game
**Game Format:** 2D Minimalist Mobile Game
**Player Capacity:** 2–4 players initially
**Game Modes:** Single Player and Multiplayer

---

# 1. GAME OVERVIEW

BINGO is a traditional number-based game in which players create their own 5×5 number boards using numbers from 1 to 25.

Players take turns selecting numbers from their boards. Whenever a number is selected, it is automatically marked on every player's board.

The objective is to complete five different lines by manually striking completed horizontal, vertical or diagonal lines.

Each successful strike awards one letter:

**B → I → N → G → O**

The first player to collect all five letters wins.

The game supports:

* Single Player against a computer-controlled opponent.
* Multiplayer through private rooms.
* Room creation and joining using unique codes.
* Administrator-controlled game sessions.
* Configurable board preparation time.
* Room-wide leaderboard and match history.
* Multiple rounds within the same room.

The visual design must remain minimalist, lightweight and mobile-friendly.

---

# 2. BOARD FORMATION

Each player receives a 5×5 matrix containing numbers from 1 to 25.

Rules:

1. Every number must appear exactly once.
2. Players can arrange numbers in any position.
3. Duplicate numbers are prohibited.
4. Missing numbers are prohibited.
5. Players can rearrange numbers before confirmation.
6. Boards become locked once the game begins.

Every player has a different private arrangement.

Example:

| 7  | 12 | 1  | 19 | 23 |
| -- | -- | -- | -- | -- |
| 3  | 18 | 24 | 5  | 10 |
| 15 | 2  | 21 | 8  | 14 |
| 25 | 11 | 6  | 17 | 4  |
| 9  | 20 | 13 | 22 | 16 |

---

# 3. GAME MODES

## 3.1 Single Player

The player competes against a system-controlled opponent.

Features:

* Human-created board.
* System-generated random board.
* Shared number-selection history.
* Alternating turns.
* Automatic number marking.
* Manual striking by the human.
* Automatic striking by the system.
* Difficulty selection.
* Game result and rematch.

### System difficulty

**Easy:** Random number selection and immediate line recognition.

**Medium:** Random selection with regular line checking and immediate claiming.

**Hard:** Strategic number selection, prioritization of useful lines and immediate claiming.

The system must follow the same game rules as human players and must never access the human player's private board.

## 3.2 Multiplayer

Players create or join private rooms using unique room codes.

The initial supported capacity is 2–4 players.

All players participate in one shared game with individual private boards.

---

# 4. MULTIPLAYER ROOM MANAGEMENT

## 4.1 Create Room

A player creates a room and becomes its administrator.

Room configuration:

| Setting           | Default      |
| ----------------- | ------------ |
| Minimum players   | 2            |
| Maximum players   | 4            |
| Board preparation | 60 seconds   |
| Room visibility   | Private      |
| Administrator     | Room creator |

The administrator can modify the room settings before the game starts.

## 4.2 Join Room

Players enter the unique room code.

The backend validates:

* Room existence.
* Room availability.
* Room capacity.
* Room status.
* Player eligibility.

After successful validation, the player enters the waiting room.

## 4.3 Waiting Room

The waiting room displays:

* Room code.
* Current player count.
* Maximum capacity.
* Player names.
* Administrator identification.
* Player readiness.
* Connection status.
* Room configuration.

The administrator controls the Start Game action.

Other players cannot independently start the game.

Players can join or leave while the room is waiting.

If the administrator leaves, privileges transfer to another eligible player.

The room cannot start until the configured minimum player requirement is satisfied.

---

# 5. BOARD PREPARATION

When the administrator clicks Start Game, the room enters BOARD_PREPARATION.

A synchronized countdown begins.

Available preparation durations:

* 30 seconds.
* 45 seconds.
* 60 seconds.
* 90 seconds.
* 120 seconds.

Players arrange their numbers and confirm their boards.

Once confirmed, their boards become locked.

### Timer expiration

If some players have not completed their boards:

* The game must not silently start.
* The administrator receives an incomplete-player notification.
* The administrator can extend the preparation time or remove unready players.
* The game starts only when the remaining players satisfy the minimum requirement and all are ready.

After preparation:

1. Validate all boards.
2. Lock the arrangements.
3. Initialize called-number history.
4. Initialize player progress.
5. Select the first player randomly.
6. Start gameplay.

---

# 6. NUMBER SELECTION AND TURN MANAGEMENT

Players take turns selecting uncalled numbers.

Example:

Player 1 → Player 2 → Player 3 → Player 4 → Player 1.

When a player selects a number:

1. Validate the player's turn.
2. Validate that the number has not been called.
3. Add the number to shared history.
4. Mark it on every player's board.
5. Update completed-line detection.
6. Broadcast the new game state.
7. Advance the turn.

Players cannot select:

* Previously called numbers.
* Invalid numbers.
* Numbers during another player's turn.
* Numbers after game completion.

The selected number affects every player's board, regardless of its position.

---

# 7. LINE DETECTION

There are 12 possible winning lines.

| Line Type  | Number |
| ---------- | -----: |
| Horizontal |      5 |
| Vertical   |      5 |
| Diagonal   |      2 |
| Total      |     12 |

A line becomes eligible when all five of its cells are marked.

Every line must have its own unique identifier.

Examples:

H1, H2, H3, H4, H5
V1, V2, V3, V4, V5
D1, D2

---

# 8. MANUAL STRIKING SYSTEM

Manual striking is a core gameplay mechanic.

Completing a line does not automatically award a letter.

The player must manually tap a completed line.

### Striking procedure

1. A player completes a line.
2. The line becomes eligible.
3. The player taps the completed line.
4. The backend verifies the line.
5. The next BINGO letter is awarded.
6. The line is marked as claimed.

Letter progression:

| Successful Claim | Letter |
| ---------------- | ------ |
| First            | B      |
| Second           | I      |
| Third            | N      |
| Fourth           | G      |
| Fifth            | O      |

Rules:

* Players can strike completed lines at any time, including during another player's turn.
* Players can claim any completed line.
* Completed lines remain available until claimed.
* Missing a strike does not remove the opportunity.
* Already-claimed lines cannot be claimed again.
* Incomplete lines cannot be claimed.
* Multiple completed lines can accumulate.

## 8.1 Overlapping Line Striking

**This is an important independent-line rule.**

A cell can belong to multiple winning lines.

For example, the top-left cell belongs to:

* First horizontal row.
* First vertical column.
* First diagonal.

If the player strikes the first horizontal row, the first diagonal and first vertical column must remain independently eligible.

### Example

The player has already claimed the top horizontal row.

Later, the diagonal becomes complete.

The player must still be able to claim that diagonal.

The previous claim must not disable the new claim.

### Technical rules

Every winning line maintains independent state:

* Line ID.
* Line type.
* Five cell positions.
* Completion status.
* Claim status.

Marking a number updates all lines containing that number.

Claiming a line updates only that line.

**Never use a shared-cell claimed flag to determine whether another line can be claimed.**

A claimed line and an unclaimed overlapping line can coexist.

This rule applies to every combination of horizontal, vertical and diagonal lines.

## 8.2 Multiple Completed Lines

If several lines become complete simultaneously:

* All completed lines become eligible.
* The player can choose any one.
* Each successful claim awards one letter.
* Remaining lines stay available.

The game ends when the player successfully claims five distinct lines.

---

# 9. VICTORY CONDITION

A player wins after collecting:

B → I → N → G → O

The backend immediately validates and records the winner.

After victory:

* Stop number selection.
* Reject additional strike requests.
* Complete the current round.
* Broadcast the winner.
* Display results to all players.

If multiple players legitimately complete their fifth claim from the same shared game event, simultaneous winners are supported.

Each simultaneous winner receives a win in the room statistics.

---

# 10. SYSTEM OPPONENT

The system participates as an ordinary player.

It has its own random 5×5 board.

It follows the same rules:

* Alternating turns.
* Shared number selection.
* Automatic marking.
* Independent line detection.
* Letter progression.
* Victory validation.

The system can access only its own board and shared game information.

It must not access the human player's private arrangement.

---

# 11. ROOM LIFECYCLE

The room follows this lifecycle:

CREATED
↓
WAITING
↓
BOARD_PREPARATION
↓
PLAYING
↓
ROUND_COMPLETED
↓
RESULT DISPLAY
↓
WAITING
↓
NEXT ROUND

A room remains available after a completed round.

The same room code is retained for rematches.

## 11.1 Game Completion

When a winner is determined:

1. Backend records the result.
2. Round status changes to COMPLETED.
3. All players receive the result.
4. Final standings are calculated.
5. Players return to the original room lobby.

The room itself is not destroyed.

## 11.2 Rematch

The administrator can initiate another round.

During rematch:

* Clear called numbers.
* Clear marked numbers.
* Clear claimed-line records.
* Reset BINGO progression.
* Generate a new turn order.
* Start board preparation again.

The previous round's results remain stored.

The room leaderboard must not reset.

---

# 12. ROOM-WIDE LEADERBOARD

Every room maintains a persistent leaderboard across multiple rounds.

Example:

| Player   | Rounds | Wins | Win Rate |
| -------- | -----: | ---: | -------: |
| Player A |      5 |    3 |      60% |
| Player B |      5 |    1 |      20% |
| Player C |      5 |    1 |      20% |
| Player D |      5 |    0 |       0% |

### Tracked statistics

* Total rounds played.
* Total wins.
* Total losses.
* Win percentage.
* Current winning streak.
* Best winning streak.
* Last round result.

### Leaderboard rules

1. Every completed round updates the statistics.
2. A winning player receives one win.
3. A simultaneous winner receives one win each.
4. Players who do not win receive a loss.
5. Incomplete or cancelled rounds do not affect statistics.
6. Statistics persist across rematches.
7. The leaderboard is scoped to the room.
8. A newly created room starts with fresh statistics.

### Ranking

Recommended ranking order:

1. Highest wins.
2. Highest win percentage.
3. Best winning streak.

For equal statistics, display tied positions rather than inventing a winner.

---

# 13. GAME STATE MANAGEMENT

Use a backend-controlled state machine.

CREATED
↓
WAITING
↓
BOARD_PREPARATION
↓
PLAYING
↓
ROUND_COMPLETED
↓
WAITING

Additional states:

* CANCELLED
* EXPIRED
* PAUSED

Every state transition must be validated.

Invalid actions must never modify the game state.

---

# 14. DATA ARCHITECTURE

Maintain separate records for rooms, players, games, boards, events and statistics.

### Rooms

* id
* room_code
* admin_id
* status
* minimum_players
* maximum_players
* board_preparation_seconds
* created_at
* expires_at

### Room Players

* id
* room_id
* user_id
* display_name
* role
* connection_status
* joined_at

### Games

* id
* room_id
* round_number
* status
* current_player_id
* called_numbers
* turn_number
* winner_ids
* started_at
* completed_at

### Player Boards

* id
* game_id
* player_id
* board_numbers
* marked_numbers
* claimed_lines
* bingo_progress

### Room Statistics

* id
* room_id
* player_id
* rounds_played
* wins
* losses
* current_win_streak
* best_win_streak

### Game Events

* id
* game_id
* player_id
* event_type
* event_payload
* sequence_number
* created_at

All game events should be recorded in a reliable, ordered manner.

---

# 15. SECURITY AND ERROR HANDLING

The backend is the authoritative source of game state.

Players must not be allowed to directly manipulate:

* Called-number history.
* Turn order.
* Board arrangements after locking.
* BINGO progression.
* Claimed-line records.
* Winner records.
* Room statistics.

### Error handling

| Scenario                   | Handling                               |
| -------------------------- | -------------------------------------- |
| Invalid room code          | Reject joining                         |
| Room full                  | Reject joining                         |
| Invalid board              | Reject confirmation                    |
| Duplicate number           | Reject selection                       |
| Wrong turn                 | Reject action                          |
| Incomplete line            | Reject strike                          |
| Previously claimed line    | Reject duplicate strike                |
| Overlapping unclaimed line | Allow strike                           |
| Duplicate request          | Prevent using idempotency              |
| Player disconnect          | Support reconnection                   |
| Admin disconnect           | Transfer privileges after grace period |
| Network failure            | Resynchronize authoritative state      |
| Game completed             | Reject additional actions              |
| Invalid room state         | Reject state transition                |

All important actions must be transactional.

---

# 16. RECOMMENDED TECHNOLOGY STACK

## Primary recommendation

### Mobile

Flutter + Dart

### Backend

Supabase

### Database

PostgreSQL

### Realtime

Supabase Realtime

### Game Logic

PostgreSQL transactional functions and secure server-side logic

### Authentication

Supabase Auth

### Local Preferences

Lightweight local storage

### Architecture

Flutter Mobile Application
↓
Secure API / Backend Functions
↓
PostgreSQL Game Engine
↓
Supabase Realtime Notifications
↓
Connected Players

PostgreSQL remains the source of truth.

Realtime messages are used to notify clients about committed state changes.

The mobile application must not be trusted to validate winners independently.

---

# 17. UI/UX DESIGN

The game follows a minimalist design philosophy.

Requirements:

* Portrait orientation.
* Clean 2D interface.
* Limited colour palette.
* Simple geometric elements.
* Minimal typography.
* No 3D models.
* No unnecessary illustrations.
* Smooth and subtle animations.
* Clear marked and unmarked states.
* Distinct completed and claimed line states.
* Mobile-friendly touch targets.

Primary screens:

1. Splash Screen.
2. Home Screen.
3. Game Mode Selection.
4. Difficulty Selection.
5. Create Room.
6. Join Room.
7. Waiting Room.
8. Room Settings.
9. Board Preparation.
10. Gameplay.
11. Game Result.
12. Room Lobby.
13. Room Leaderboard.
14. Match History.
15. Settings.

---

# 18. DEVELOPMENT ROADMAP

### Phase 1 — Core Game Engine

* Board generation.
* Board validation.
* Number selection.
* Shared marking.
* Line detection.
* Independent line claims.
* Overlapping strike support.
* BINGO progression.
* Victory detection.

### Phase 2 — Single Player

* System opponent.
* Difficulty levels.
* Turn management.
* Result screen.
* Rematch.

### Phase 3 — Multiplayer Foundation

* Authentication.
* Room creation.
* Unique room codes.
* Joining rooms.
* Waiting room.
* Admin permissions.
* Room configuration.

### Phase 4 — Board Preparation

* Custom arrangement.
* Preparation timer.
* Ready status.
* Board locking.
* Admin-controlled start.

### Phase 5 — Multiplayer Gameplay

* Turn synchronization.
* Shared number selection.
* Independent manual striking.
* Private boards.
* Winner detection.

### Phase 6 — Room Lifecycle

* Game results.
* Return to room.
* Rematch.
* New round initialization.
* Round history.

### Phase 7 — Leaderboard

* Room statistics.
* Win/loss tracking.
* Winning streaks.
* Ranking.
* Persistent records.

### Phase 8 — Reliability

* Reconnection.
* Duplicate request prevention.
* Transaction handling.
* Authorization.
* Room expiration.
* Network failure handling.

### Phase 9 — Final Polish

* Animations.
* Sound.
* Haptic feedback.
* Performance optimization.
* Android and iOS testing.

---

# 19. FINAL PRODUCT REQUIREMENTS

| Feature            | Requirement              |
| ------------------ | ------------------------ |
| Board              | 5×5                      |
| Numbers            | 1–25                     |
| Number arrangement | Player controlled        |
| Number selection   | Alternating turns        |
| Marking            | Shared automatically     |
| Board visibility   | Private                  |
| Winning lines      | 12                       |
| Striking           | Manual                   |
| Overlapping lines  | Independently claimable  |
| Letters            | B-I-N-G-O                |
| Single Player      | Human vs system          |
| Difficulty         | Easy, Medium, Hard       |
| Multiplayer        | Private rooms            |
| Room code          | Unique                   |
| Waiting room       | Required                 |
| Administrator      | Required                 |
| Board preparation  | Timed                    |
| Game start         | Admin controlled         |
| Victory            | Five successful claims   |
| Room lifecycle     | Persistent across rounds |
| Rematch            | Supported                |
| Leaderboard        | Persistent per room      |
| Match history      | Required                 |
| Visual design      | Minimalist 2D            |
| Platforms          | Android and iOS          |

---

# CONCLUSION

BINGO should retain the simplicity of its traditional rules while providing a modern mobile experience.

Its defining mechanics are:

* Custom player-created boards.
* Shared number selection.
* Private board arrangements.
* Manual line striking.
* Independent overlapping line claims.
* Competitive system opponents.
* Private multiplayer rooms.
* Administrator-controlled game sessions.
* Persistent room leaderboards.
* Multiple rounds and rematches.

The development priority is:

**Correct Gameplay → Reliable Multiplayer → Secure Backend → Mobile Experience → Visual Polish.**
