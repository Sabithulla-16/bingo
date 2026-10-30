# Stitch Design Inventory – BINGO Mobile Game

## Overview

This inventory documents all 16 user interface screens discovered and inspected in the Google Stitch design project **"Bingo Minimalist Splash Screen"** (Project ID: `projects/1917718787847945379`), based on the official design system **"Velvet Daub"** (`assets/efd11fd78a994306a92a6562ded75f7f`).

The aesthetic is **Modern Minimalist Pop**: generous cream-toned negative space, clean flat 2D layout with physical-paper elevation, deliberate color blocking, and geometric clarity.

---

## Design System Tokens ("Velvet Daub")

### Color Palette

| Token Name | Hex Code | Role & Usage |
|---|---|---|
| **Base Canvas / Background** | `#FAFAF7` (`#F9F9F6`) | Warm off-white paper substrate replacing digital stark white |
| **Surface Container (Card)** | `#FFFFFF` | Pure white cards, play slips, dialog sheets |
| **Supporting Surface (Lavender)** | `#E8E5FF` | Muted column banners, neutral chips, inactive grid cells |
| **Primary Navy** | `#20243A` (`#0B0F24`) | Structural foundation, high-contrast typography, dividers, dark action pills |
| **Primary Coral** | `#FF6B5E` (`#FC695C`) | Interaction spark, BINGO call button, active daub markers, win states |
| **Soft Yellow / Gold** | `#FFD166` (`#EDC157`) | Reward accents, star ratings, coin/chip rewards, current ball glow |
| **Ready Green** | `#22C55E` (`#16A34A`) | Subtle accessible green for player ready status |
| **Surface Variant** | `#E2E3E0` | Neutral structural outlines and borders |
| **Text Primary** | `#1A1C1B` | High emphasis text |
| **Text Supporting / Muted** | `#46464D` / `#77767D` | Secondary body text, field labels, metadata |

### Typography

The type system is powered exclusively by Google Font **Outfit**:

* **Display Hero**: Outfit 48px, Weight 800, Line Height 52px, Letter Spacing -0.03em
* **Display Hero Mobile**: Outfit 36px, Weight 800, Line Height 40px, Letter Spacing -0.02em
* **Headline Lg**: Outfit 32px, Weight 700, Line Height 38px, Letter Spacing -0.02em
* **Headline Lg Mobile**: Outfit 26px, Weight 700, Line Height 32px, Letter Spacing -0.01em
* **Headline Md**: Outfit 22px, Weight 700, Line Height 28px
* **Headline Sm**: Outfit 18px, Weight 600, Line Height 24px
* **Bingo Ball Call**: Outfit 32px, Weight 800, Line Height 32px
* **Bingo Number (Board Cells)**: Outfit 24px, Weight 800, Line Height 24px (Tabular Figures)
* **Body Lg**: Outfit 16px, Weight 500, Line Height 24px
* **Body Md**: Outfit 14px, Weight 400, Line Height 20px
* **Body Sm**: Outfit 12px, Weight 500, Line Height 16px
* **Label Lg**: Outfit 14px, Weight 700, Line Height 18px, Letter Spacing 0.04em (Uppercase)
* **Label Md**: Outfit 12px, Weight 700, Line Height 16px, Letter Spacing 0.05em (Uppercase)
* **Label Sm**: Outfit 10px, Weight 700, Line Height 12px, Letter Spacing 0.06em (Uppercase)

### Shapes & Geometry

* **Base Cards & Modules**: `Rounded 8px - 16px` (`rounded-xl` / `rounded-2xl`)
* **Bingo Board Cells**: `10px` corner radii (curved square pocket)
* **Action Buttons & Chips**: Full pill capsules (`border-radius: 9999px`)
* **Ball Units**: 48px circles with 2px stroke border

### Elevation Hierarchy

* **Level 0 (Floor)**: Canvas in `#FAFAF7`
* **Level 1 (Card Matrix & Board Tiles)**: `#FFFFFF` resting on `#FAFAF7` with 1.5px structural border tinted to `#20243A` at 8% opacity
* **Level 2 (Active Floating Tokens & Cells)**: Crisp 2px downward edge displacement with zero blur (`box-shadow: 0px 3px 0px rgba(32, 36, 58, 0.12)`)
* **Level 3 (Modal Sheets & Celebration Overlays)**: Scrim with `#20243A` at 40% opacity, framed in `#20243A` (1.5px stroke)

---

## Screen Inventory (All 16 Screens)

### 1. Splash Screen
* **Stitch Screen ID**: `97875f5450c745e9afb99ca9389aa94d`
* **Title in Stitch**: `BINGO Splash Screen`
* **Design Dimensions**: 780 × 1768 px (Mobile 390 × 884 pt)
* **Reference Screenshot**: `assets/images/screenshots/splash_screen.jpg` (retrieved via `projects/1917718787847945379/files/3814591164886320873`)
* **HTML Code File**: `projects/1917718787847945379/files/14576943151040872575`
* **Main Components**:
  - Ambient gradient decorative blurs (top-left navy `#20243A`/30, bottom-right coral `#FF6B5E`/40)
  - 5×5 preview card with winning diagonal strikethrough line vector and celebratory sparkles
  - Shared lettered BINGO logo with micro daub dot in the 'O'
  - Curated tagline: *"Pick • Mark • Strike • Win"*
  - Animated 3-dot bouncing loading indicator
  - Connecting status text: *"Preparing your game" / "Welcome to BINGO"*
* **Navigation Destination**:
  - If authenticated session active: `/home`
  - If unauthenticated / first launch: `/auth`
* **Shared Components Reused**: `BingoLogo`, `AppCard`, `AppLoadingIndicator`
* **Assets**: Embedded SVG strikethrough vector, Outfit typography

---

### 2. Create Account / Sign In
* **Stitch Screen ID**: `152948b85345400fb54e55f8ba807a09`
* **Title in Stitch**: `BINGO Authentication & Registration`
* **Design Dimensions**: 390 × 884 px
* **Reference Screenshot**: *Limitation*: The screenshot entry in Stitch API was empty (`screenshot: {}`); however, the complete source HTML file was successfully retrieved and inspected (`projects/1917718787847945379/files/6364115196983693120`).
* **HTML Code File**: `projects/1917718787847945379/files/6364115196983693120`
* **Main Components**:
  - Top header with centered `BingoLogo`
  - Welcome pill badge: *"WELCOME TO BINGO"*
  - Hero header: *"Let's get you started!"*
  - Miniature 2D 5×5 sample board preview (cells 01–25)
  - Pill segmented switcher: `[Create Account] | [Sign In]`
  - **Register View**: Name field (0/20 counter), Email field with validation check, Password field with 3-tier strength indicator, Confirm password field, Terms & conditions checkbox, Coral pill button (`CREATE ACCOUNT`)
  - **Sign In View**: Email field, Password field with toggle visibility, Remember me checkbox, Forgot password button, Coral pill button (`SIGN IN`)
  - **Forgot Password View**: Email input, Send Reset Link button, Return to Sign In
  - Registration success confirmation modal with codename snapshot
* **Navigation Destination**: `/home` upon successful auth
* **Shared Components Reused**: `BingoLogo`, `AppTextField`, `PrimaryButton`, `AppCard`, `StatusBadge`
* **Assets**: Material Symbols Outlined icons (`person`, `mail`, `lock`, `visibility`, `check_circle`, `stars`)

---

### 3. Home Screen
* **Stitch Screen ID**: `587a408834c84cee91acba026d408bad`
* **Title in Stitch**: `BINGO Home Screen`
* **Design Dimensions**: 780 × 2152 px (Mobile 390 × 1076 pt)
* **Reference Screenshot**: `assets/images/screenshots/home_screen.jpg` (retrieved via `projects/1917718787847945379/files/4651052828792353324`)
* **HTML Code File**: `projects/1917718787847945379/files/5337800023186688840`
* **Main Components**:
  - Top app bar with player avatar, display name, level chip, and profile navigation trigger
  - Central `BingoLogo`
  - Single Player game card (with difficulty badge, AI opponent indicator, CTA "PLAY SINGLE PLAYER")
  - Multiplayer game card (with room creation, join code, live lobby indicator, CTA "PLAY MULTIPLAYER")
  - Quick Personal Stats summary card (Total matches, Win rate %, Streak)
* **Navigation Destinations**:
  - Single Player card tap: `/single-player/difficulty`
  - Multiplayer card tap: `/multiplayer`
  - Profile header tap: `/profile`
* **Shared Components Reused**: `BingoLogo`, `PlayerAvatar`, `AppCard`, `PrimaryButton`, `SecondaryButton`, `StatusBadge`
* **Assets**: Profile avatar graphic, game mode illustration cards

---

### 4. Single Player Difficulty Selection
* **Stitch Screen ID**: `f8a803af8b374c2eb8b32f5d8716186d`
* **Title in Stitch**: `BINGO Difficulty Selection`
* **Design Dimensions**: 780 × 1768 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/8070590463976985455`)
* **HTML Code File**: `projects/1917718787847945379/files/12187285007626893096`
* **Main Components**:
  - Back navigation button and page title
  - Three distinct difficulty cards:
    - **Easy**: Random number calls, relaxed pace
    - **Medium**: Regular line checks, balanced AI
    - **Hard**: Strategic number selection, optimal winning line pursuit
  - AI Opponent card preview with avatar
  - Primary button: *"CONTINUE TO BOARD"*
* **Navigation Destination**: `/single-player/board-preparation`
* **Shared Components Reused**: `AppCard`, `PrimaryButton`, `StatusBadge`
* **Assets**: Difficulty badge icons, AI bot avatar

---

### 5. Single Player Board Preparation
* **Stitch Screen ID**: `c059f8f36a2f4a808b71bfa6cd36131e`
* **Title in Stitch**: `BINGO Board Preparation`
* **Design Dimensions**: 780 × 1768 px
* **Reference Screenshot**: `assets/images/screenshots/board_preparation.png` (retrieved via `projects/1917718787847945379/screens/c059f8f36a2f4a808b71bfa6cd36131e/fileEntries/screenshot`)
* **HTML Code File**: `projects/1917718787847945379/files/c059f8f36a2f4a808b71bfa6cd36131e:download`
* **Main Components**:
  - Screen title: *"Set Up Your Board"*
  - Board instructions: *"Place numbers 1–25 or use Quick Shuffle"*
  - 5×5 interactive grid with cell states (placed, empty, draggable)
  - Quick action bar: Shuffle button, Clear button
  - Number picker palette (numbers remaining to be placed)
  - Primary button: *"CONFIRM & START GAME"* (locked until exactly 25 numbers are placed)
* **Navigation Destination**: `/single-player/game/:gameId`
* **Shared Components Reused**: `BingoBoardGrid`, `BingoCell`, `PrimaryButton`, `SecondaryButton`
* **Assets**: Tabular numeric fonts, grid action icons

---

### 6. Single Player Gameplay
* **Stitch Screen ID**: `c35c79a49c804f4aad87a3ae72090e66`
* **Title in Stitch**: `BINGO Single Player Gameplay`
* **Design Dimensions**: 780 × 1768 px
* **Reference Screenshot**: `assets/images/screenshots/single_player_gameplay.jpg` (retrieved via `projects/1917718787847945379/files/6187365388199392858`)
* **HTML Code File**: `projects/1917718787847945379/files/1125203774541546632`
* **Main Components**:
  - Top HUD with current turn indicator: *"Your Turn"* vs *"Computer Thinking..."*
  - Called Ball Carousel: Last called number magnified with yellow glow, history track
  - B-I-N-G-O Letter Progress Bar: 5 letter badges showing awarded letters
  - 5×5 Interactive Board with cell states:
    - Available (white)
    - Called (lavender ring)
    - Unclaimed Line (pulsing border)
    - Claimed (coral daub with stamp ring)
  - Primary Action: *"CLAIM LINE"* / *"BINGO!"* button
  - Opponent Mini Progress chip
* **Navigation Destination**: `/single-player/result/:gameId` upon match conclusion
* **Shared Components Reused**: `BingoBoardGrid`, `BingoCell`, `BingoProgressLetters`, `PrimaryButton`
* **Assets**: Ball unit styling, daub stamp SVG asset

---

### 7. Single Player Game Result
* **Stitch Screen ID**: `979d94b99a954acab4e6135aa5f5b520`
* **Title in Stitch**: `BINGO Game Result`
* **Design Dimensions**: 780 × 2258 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/13730414288087026726`)
* **HTML Code File**: `projects/1917718787847945379/files/10557835058350627089`
* **Main Components**:
  - Victory or Defeat header banner with celebratory confetti accents
  - Final letter progress snapshot (completed B-I-N-G-O)
  - Match statistics card: Total calls, Lines completed, Time taken, AI progress
  - Action buttons:
    - Primary: *"PLAY AGAIN"* (starts new round)
    - Secondary: *"MAIN MENU"* (returns home)
* **Navigation Destinations**:
  - Play Again: `/single-player/board-preparation`
  - Main Menu: `/home`
* **Shared Components Reused**: `BingoLogo`, `AppCard`, `PrimaryButton`, `SecondaryButton`, `BingoProgressLetters`
* **Assets**: Trophy icon, victory ribbon

---

### 8. Multiplayer Menu
* **Stitch Screen ID**: `f4d100bf68cf4088a4dc49448549ce41`
* **Title in Stitch**: `BINGO Multiplayer Menu`
* **Design Dimensions**: 780 × 1980 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/screenshot_00065f0f5dfcdb2903749aadb911802d`)
* **HTML Code File**: `projects/1917718787847945379/files/f4d100bf68cf4088a4dc49448549ce41`
* **Main Components**:
  - Header with Back button and player profile pill
  - **Create Private Room** card (Host your game, customize rules)
  - **Join with Room Code** card (Enter 6-character code)
  - How Multiplayer Works info accordion
* **Navigation Destinations**:
  - Create Room: `/multiplayer/create-room`
  - Join Room: `/multiplayer/join-room`
* **Shared Components Reused**: `AppCard`, `PrimaryButton`, `SecondaryButton`, `StatusBadge`
* **Assets**: Private room lock icon, multiplayer group icon

---

### 9. Create Room Settings
* **Stitch Screen ID**: `44f9713e773b4977b628d9679a0f371c`
* **Title in Stitch**: `BINGO Create Room Settings`
* **Design Dimensions**: 780 × 2232 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/screenshot_00065f0f66399a370392cadb5d178963`)
* **HTML Code File**: `projects/1917718787847945379/files/44f9713e773b4977b628d9679a0f371c`
* **Main Components**:
  - Room name input field
  - Player capacity selector pill toggle: `[2 Players] | [3 Players] | [4 Players]`
  - Board preparation timer selector: `[30s] | [45s] | [60s]`
  - Turn time limit toggle: `[15s] | [20s] | [30s]`
  - Host info card
  - Primary button: *"CREATE ROOM & INVITE"*
* **Navigation Destination**: `/multiplayer/room/:roomId/lobby`
* **Shared Components Reused**: `AppTextField`, `AppCard`, `PrimaryButton`
* **Assets**: Settings slider icons, clock icon

---

### 10. Join Room
* **Stitch Screen ID**: `d221a3db42c344d3b8e705d9a6614e29`
* **Title in Stitch**: `BINGO Join Room`
* **Design Dimensions**: 780 × 2248 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/12775656265963922272`)
* **HTML Code File**: `projects/1917718787847945379/files/7090661893258110260`
* **Main Components**:
  - 6-character room code input with auto-spaced segmented character boxes
  - Numeric & uppercase keypad
  - Status feedback text (Validating room...)
  - Recent rooms joined quick-access list
  - Primary button: *"JOIN ROOM"*
* **Navigation Destination**: `/multiplayer/room/:roomId/lobby`
* **Shared Components Reused**: `AppTextField`, `PrimaryButton`, `AppCard`
* **Assets**: Keypad icons, room code badge

---

### 11. Multiplayer Waiting Room (Lobby)
* **Stitch Screen ID**: `a584bd1bc3194df098024d3a9ab8c59d`
* **Title in Stitch**: `BINGO Multiplayer Waiting Room`
* **Design Dimensions**: 780 × 1928 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/3003348417266626496`)
* **HTML Code File**: `projects/1917718787847945379/files/3861960660988487671`
* **Main Components**:
  - Room Code pill with one-tap copy button and share link
  - Player slots grid (2–4 player cards):
    - Host badge, avatar, name, and connection status
    - Joined players with ready toggle indicator
    - Empty slots with *"Invite Player"* button
  - Room settings summary (Preparation time, turn duration)
  - Host action: *"START GAME"* (enabled when minimum players are ready)
  - Non-host action: *"TOGGLE READY"* button
* **Navigation Destination**: `/multiplayer/room/:roomId/board-preparation`
* **Shared Components Reused**: `PlayerAvatar`, `StatusBadge`, `RoomBadge`, `PrimaryButton`, `SecondaryButton`
* **Assets**: Copy clipboard icon, crown icon for host

---

### 12. Multiplayer Board Preparation
* **Stitch Screen ID**: `e8593d7a83924868a0b75fad83f69012`
* **Title in Stitch**: `BINGO Multiplayer Board Preparation`
* **Design Dimensions**: 780 × 2494 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/screenshot_00065f0fb65d1c6907c4e2a3191cebeb`)
* **HTML Code File**: `projects/1917718787847945379/files/e8593d7a83924868a0b75fad83f69012`
* **Main Components**:
  - Synchronized server deadline countdown timer header
  - Board configuration 5×5 grid
  - Quick Shuffle button
  - Player ready status bar (e.g., *"3/4 Players Ready"*)
  - Confirmation lock toggle: *"LOCK BOARD & READY"*
  - Host extension control (if timer runs out and players are unready)
* **Navigation Destination**: `/multiplayer/room/:roomId/game`
* **Shared Components Reused**: `BingoBoardGrid`, `BingoCell`, `PrimaryButton`, `SecondaryButton`, `StatusBadge`
* **Assets**: Timer circular progress indicator, lock icon

---

### 13. Multiplayer Gameplay
* **Stitch Screen ID**: `99e26fda63c3428a82b9702145ca87f5`
* **Title in Stitch**: `BINGO Multiplayer Gameplay`
* **Design Dimensions**: 780 × 1990 px
* **Reference Screenshot**: `assets/images/screenshots/multiplayer_gameplay.jpg` (retrieved via `projects/1917718787847945379/files/17633984618423624532`)
* **HTML Code File**: `projects/1917718787847945379/files/15302236355134360386`
* **Main Components**:
  - Active turn player banner: *"Sabit's Turn (12s)"*
  - Synchronized Called Ball Ribbon with magnified latest call
  - Player's private 5×5 Bingo Board with interactive states
  - B-I-N-G-O progress letter badges (personal)
  - Opponent Presence Chips: Avatar, username, and mini BINGO progress (e.g., `B-I-N`)
  - Primary CTA: *"CLAIM COMPLETED LINE"*
* **Navigation Destination**: `/multiplayer/room/:roomId/result`
* **Shared Components Reused**: `BingoBoardGrid`, `BingoCell`, `BingoProgressLetters`, `PlayerAvatar`, `PrimaryButton`
* **Assets**: Live turn indicator glow, stamp ring daub effect

---

### 14. Multiplayer Match Result and Room Leaderboard
* **Stitch Screen ID**: `d92bc16a2a7b4b6393c8e8f0c9b871af`
* **Title in Stitch**: `BINGO Multiplayer Match Result & Leaderboard`
* **Design Dimensions**: 780 × 3884 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/9106221939682467791`)
* **HTML Code File**: `projects/1917718787847945379/files/16101061057795612716`
* **Main Components**:
  - Winner announcement hero card (supports simultaneous multiple winners)
  - Podium standings (1st, 2nd, 3rd, 4th) with avatars and completed letters
  - Round summary metrics
  - Rematch vote button: *"PLAY ANOTHER ROUND"*
  - Detailed room statistics button
  - Leave room confirmation
* **Navigation Destinations**:
  - Rematch: `/multiplayer/room/:roomId/board-preparation`
  - View Room Stats: `/multiplayer/room/:roomId/statistics`
  - Leave Room: `/home`
* **Shared Components Reused**: `PlayerAvatar`, `AppCard`, `PrimaryButton`, `SecondaryButton`, `BingoProgressLetters`
* **Assets**: Podium graphics, celebration confetti

---

### 15. Detailed Room Statistics
* **Stitch Screen ID**: `3d876d713b4f4007a8ca42fcf502e534`
* **Title in Stitch**: `BINGO Detailed Room Leaderboard & Match History`
* **Design Dimensions**: 780 × 1924 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/screenshot_00065f0ffb234f1e07c4d95b9f358457`)
* **HTML Code File**: `projects/1917718787847945379/files/3d876d713b4f4007a8ca42fcf502e534`
* **Main Components**:
  - Room Title & Session header
  - Persistent Room Scoreboard:
    - Player rankings across all rounds in this session
    - Rounds won, draws, losses, and win percentage
    - Current and best winning streak in this room
  - Round-by-round timeline log:
    - Round number, winner, numbers called, time elapsed
  - Return to Lobby button
* **Navigation Destination**: `/multiplayer/room/:roomId/lobby`
* **Shared Components Reused**: `AppCard`, `PlayerAvatar`, `SecondaryButton`
* **Assets**: Medal icons, streak flame icon

---

### 16. Player Profile and Personal Statistics
* **Stitch Screen ID**: `5e7e8a333408412990869a864a7b06f2`
* **Title in Stitch**: `BINGO Player Profile & Personal Statistics`
* **Design Dimensions**: 780 × 4060 px
* **Reference Screenshot**: Available in Stitch (`projects/1917718787847945379/files/4853984950241854757`)
* **HTML Code File**: `projects/1917718787847945379/files/12729587974455696280`
* **Main Components**:
  - Profile header with large editable avatar and display name
  - Email address and membership date
  - Lifetime Career Statistics:
    - Total matches played
    - Total wins, draws, losses
    - Overall win percentage
    - Current streak and all-time highest streak
  - Achievements / Badges collection grid
  - Account security & preference controls
  - Sign Out button
* **Navigation Destinations**:
  - Back: `/home`
  - Sign Out: `/auth`
* **Shared Components Reused**: `PlayerAvatar`, `AppCard`, `PrimaryButton`, `SecondaryButton`, `StatusBadge`
* **Assets**: Achievement badge icons, edit profile icon

---

## Shared Component Inventory

1. **`BingoLogo`**: Canonical 5-letter brand component (`B` Midnight Navy, `I` Coral, `N` Midnight Navy, `G` Soft Yellow, `O` Midnight Navy with Coral daub center dot, plus optional uppercase tagline *"Pick • Mark • Strike • Win"*).
2. **`PrimaryButton`**: Coral pill button (`#FF6B5E`) with white uppercase Outfit typography, tactile 2px push-down behavior.
3. **`SecondaryButton`**: Midnight navy pill button (`#20243A`) with light text (`#FAFAF7`).
4. **`AppCard`**: Rounded white container (`#FFFFFF`) with 1.5px subtle border (`#20243A` at 8% opacity) and 8–16px radii.
5. **`AppTextField`**: Minimalist low-surface input field (`#F4F4F1`) with Outfit body typography, clear focus states, and leading icon support.
6. **`PlayerAvatar`**: Circular player identity token with border outline and optional rank/host indicator.
7. **`StatusBadge`**: Pill container for room status, ready states, and game tags.
8. **`BingoCell`**: Individual 5×5 grid cell supporting the four official states: *Available*, *Called*, *Completed Unclaimed Line*, and *Claimed*.
9. **`BingoBoardGrid`**: Responsive 5×5 square grid wrapper with 4–6px spacing gaps and touch-optimized tap targets.
10. **`BingoProgressLetters`**: 5 letter badges for `B-I-N-G-O` tracking claimed lines.
11. **`RoomBadge`**: Pill displaying room code with one-tap copy and player count.
12. **`AppLoadingIndicator`**: Three-dot animated bouncing indicator using brand colors.
13. **`ConfirmationDialog`**: Centered modal sheet with scrim backdrop for match exit, resign, or kick confirmation.

---

## Asset Retrieval & Limitations Documentation

* **Screenshots**: Screenshots were directly extracted from Stitch MCP files for Splash Screen, Home Screen, Single Player Gameplay, Multiplayer Gameplay, and Board Preparation, and saved under `assets/images/screenshots/`.
* **Auth Screen Screenshot**: As reported by the Stitch MCP `get_screen` call on `projects/1917718787847945379/screens/152948b85345400fb54e55f8ba807a09`, the screenshot object is empty (`screenshot: {}`). The complete HTML code file (`6364115196983693120`) was retrieved and used as the source of truth for all layout, dimensions, and components.
* **Branding**: The BINGO logo is defined as a vector/Flutter code component adhering to the exact letter color sequence and inner daub dot in the 'O', ensuring zero visual degradation and instant responsiveness across all DPIs.
