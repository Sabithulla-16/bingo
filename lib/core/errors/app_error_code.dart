/// Standardized internal error codes categorized by domain.
enum AppErrorCode {
  // Authentication
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,
  invalidEmail,
  emailNotVerified,
  passwordResetFailure,
  sessionExpired,
  accountNotFound,
  tooManyAttempts,
  authServiceUnavailable,

  // Network & Backend
  networkUnavailable,
  connectionTrouble,
  timeout,
  serviceUnavailable,
  loadFailed,
  saveFailed,

  // Gameplay
  numberAlreadyCalled,
  notYourTurn,
  lineIncomplete,
  lineAlreadyClaimed,
  roundAlreadyEnded,
  gameplayActionFailed,
  invalidBoard,

  // Multiplayer
  roomNotFound,
  roomFull,
  roomExpired,
  connectionLost,
  reconnectionFailed,
  syncFailed,
  startGameFailed,
  playerRemoved,

  // Generic
  unknown,
}
