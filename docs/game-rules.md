# BINGO Game Rules & Mechanics Specification

This document defines the official rules, mathematical constraints, state transitions, and validation invariants for the **BINGO** mobile application.

---

## 1. Board Structure & Formation

### 1.1 Matrix Constraints
* **Grid Dimension**: Exactly $5 \times 5$ matrix (25 total cells).
* **Number Range**: Integers from $1$ to $25$ inclusive.
* **Bijection Invariant**: Every number in $\{1, 2, \dots, 25\}$ must appear **exactly once** on the board.
  $$\forall i \in \{1, 2, \dots, 25\}, \quad \text{count}(i) = 1$$
* **No Free Cell**: Unlike traditional 75-ball American Bingo, there is **no free center space**. All 25 cells hold player-assigned numbers.
* **Board Privacy**: Every player possesses a private, secret board arrangement. The arrangement of a player's board is never exposed to opponents or client-side game state of rival devices.

### 1.2 Preparation Phase
* **Custom Arrangement**: Players may place numbers manually cell-by-cell or tap **"Quick Shuffle"** to generate a cryptographically pseudo-random permutation of $[1..25]$.
* **Confirmation & Locking**:
  * A board cannot be confirmed until all 25 cells are filled with distinct numbers from $1$ to $25$.
  * Once confirmed, the board is immutable for the duration of that round.
  * Confirmed boards cannot be rearranged after round kickoff.

---

## 2. Number Calling & Turn Mechanics

### 2.1 Shared Call History
* A single, synchronized array of **Called Numbers** ($\mathcal{C}$) is maintained for the match.
* When a number is selected by the active player, it is immediately appended to $\mathcal{C}$ and broadcast to all participants.
* **Auto-Marking**: The called number is automatically marked as called on every player's board at its corresponding cell index $(r, c)$.
* **Call Immutability & Uniqueness**:
  * A number once called cannot be called again.
  * $$x \in \mathcal{C} \implies x \text{ is ineligible for selection}$$
  * Maximum calls in a match: 25.

### 2.2 Turn Order
* **Single Player**: Turns strictly alternate between the human player and the computer opponent.
* **Multiplayer**: Turns proceed in a fixed cyclic sequence determined at round start:
  $$\text{Player}_0 \to \text{Player}_1 \to \dots \to \text{Player}_{k-1} \to \text{Player}_0$$
* **Turn Timeout**: If an active player fails to select an uncalled number before the turn timer expires, a random uncalled number is selected on their behalf, or the turn advances according to room configuration.

---

## 3. Winning Lines & Overlapping Rule

### 3.1 Line Definitions
There are exactly **12 possible winning lines** on a $5 \times 5$ board:
1. **5 Horizontal Rows**:
   * $R_0 = \{(0,0), (0,1), (0,2), (0,3), (0,4)\}$
   * $R_1 = \{(1,0), (1,1), (1,2), (1,3), (1,4)\}$
   * $R_2 = \{(2,0), (2,1), (2,2), (2,3), (2,4)\}$
   * $R_3 = \{(3,0), (3,1), (3,2), (3,3), (3,4)\}$
   * $R_4 = \{(4,0), (4,1), (4,2), (4,3), (4,4)\}$
2. **5 Vertical Columns**:
   * $C_0 = \{(0,0), (1,0), (2,0), (3,0), (4,0)\}$
   * $C_1 = \{(0,1), (1,1), (2,1), (3,1), (4,1)\}$
   * $C_2 = \{(0,2), (1,2), (2,2), (3,2), (4,2)\}$
   * $C_3 = \{(0,3), (1,3), (2,3), (3,3), (4,3)\}$
   * $C_4 = \{(0,4), (1,4), (2,4), (3,4), (4,4)\}$
3. **2 Diagonals**:
   * $D_{\text{main}} = \{(0,0), (1,1), (2,2), (3,3), (4,4)\}$
   * $D_{\text{anti}} = \{(0,4), (1,3), (2,2), (3,1), (4,0)\}$

### 3.2 Line State Model
Each of the 12 lines tracks independent state:
* `lineId`: Unique identifier (e.g. `row_0`, `col_3`, `diag_main`).
* `lineType`: `horizontal`, `vertical`, or `diagonal`.
* `cellIndices`: The 5 fixed matrix coordinate pairs.
* `isComplete`: Boolean — true if and only if all 5 cells contain numbers in $\mathcal{C}$.
* `isClaimed`: Boolean — true if and only if the player has explicitly claimed this line.

### 3.3 Critical Overlapping Rule
> [!IMPORTANT]
> **Claiming one winning line must never disable or invalidate another overlapping line.**

* Example: A diagonal line $D_{\text{main}}$ is completed and claimed by the player. Later, row $R_2$ becomes complete.
* Both lines share cell $(2,2)$.
* **Rule**: Row $R_2$ remains **independently valid and claimable**.
* **Engine Invariant**: Line completion and eligibility are calculated strictly over the *called state* of its member cells, **never** over a cell-level "claimed" flag.

---

## 4. Manual Claiming & BINGO Letter Progression

### 4.1 Claim Mechanics
* **Manual Strike by Human**: When a line becomes complete, the client alerts the player (visual pulsing / highlight). The human player must manually trigger the claim action (e.g. tapping the completed line or the primary "CLAIM LINE" button).
* **Asynchronous Claiming**:
  * A player **does not need to wait for their turn** to claim a completed line.
  * Line claims can occur at any moment during the match.
* **Accumulated Claims**: If a single called number completes multiple lines simultaneously (e.g., an intersection completing both a row and a column), all completed unclaimed lines accumulate and can be claimed.

### 4.2 Letter Progression
Each distinct claimed line awards the next letter in the fixed sequence:
$$\text{Line 1} \to \mathbf{B}$$
$$\text{Line 2} \to \mathbf{I}$$
$$\text{Line 3} \to \mathbf{N}$$
$$\text{Line 4} \to \mathbf{G}$$
$$\text{Line 5} \to \mathbf{O}$$

* Achieving all 5 letters ($\mathbf{B-I-N-G-O}$) constitutes match victory.
* Any additional completed lines beyond 5 do not affect the win condition.

---

## 5. Single Player Mode

* **Participants**: Exactly 1 human player vs 1 computer opponent.
* **Opponent Integrity**:
  * The computer maintains its own private, isolated $5 \times 5$ board.
  * The computer AI has **zero access** to the human player's board, state, or future picks.
* **Opponent Claiming**: The computer automatically detects and claims its completed lines immediately upon completion.
* **Difficulty Levels**:
  1. **Easy**:
     * Selects numbers randomly from remaining uncalled numbers on its board.
     * Instant claim recognition.
  2. **Medium**:
     * Periodically evaluates lines with 3–4 marked cells and biases picks toward completing those lines.
  3. **Hard**:
     * Applies heuristic weighting: calculates the intersection density of uncalled numbers across all uncompleted lines, selecting the optimal number to maximize its own line progression.

---

## 6. Multiplayer Mode

### 6.1 Room Governance
* **Access**: Private rooms only; entry requires a unique 6-character alphanumeric room code.
* **Capacity**: 2 to 4 players.
* **Host Authority**:
  * The room creator is designated as `Host`.
  * The host configures room settings: preparation duration (30s, 45s, 60s), turn timer (15s, 20s, 30s), player count.
  * The host controls kickoff to the preparation phase.
  * The host can kick inactive or unready players.

### 6.2 Board Preparation & Timer Mechanics
* Upon kickoff, all room players enter board preparation simultaneously.
* **Synchronized Server Deadline**: A unified UTC timestamp (`preparation_deadline`) is set by the server.
* **Confirmed State**: When a player confirms their board, their state transitions to `ready = true` and their board is locked.
* **Timer Expiration Invariant**:
  * Expiration of the preparation timer **does not** automatically start the game if players are unready.
  * When time expires:
    - The host may grant a timer extension (+15s / +30s).
    - Unready players may be prompted to auto-shuffle.
    - The host can remove unready players.
  * The match cannot begin if the number of ready players is below the configured minimum (minimum 2 players).

---

## 7. Game Completion, Winners, & Draws

### 7.1 Victory Condition
* The first player (or players) to claim 5 distinct winning lines achieves **BINGO** and wins the match.

### 7.2 Simultaneous Winners
* In multiplayer, if the calling of number $N$ results in multiple players completing their 5th line in the same turn window, the system supports **Simultaneous Valid Winners**.
* Both players are awarded a match win in the room leaderboard and personal statistics.

### 7.3 Draw Condition
* If all 25 numbers are called and no player has claimed 5 lines, the match concludes as a **Draw**.

---

## 8. Persistent Statistics

### 8.1 Room-Level Statistics (Session-Scoped)
Room statistics persist across rematches within the same room:
* `roundsPlayed`: Total completed rounds.
* `wins`: Count per player.
* `draws`: Total tied matches.
* `losses`: Count per player.
* `winPercentage`: $\frac{\text{wins}}{\text{roundsPlayed}} \times 100\%$.
* `currentStreak`: Consecutive wins in the active room.
* `bestStreak`: Longest consecutive win streak in the active room.

### 8.2 Personal Player Statistics (Global Profile)
Aggregated across all completed matches globally:
* Total matches played, total wins, draws, losses, overall win rate, highest career winning streak.
* **Integrity Rule**: Aborted, abandoned, or cancelled matches **never** pollute completed match statistics.
