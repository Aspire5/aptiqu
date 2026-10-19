export class PvpError extends Error {
  constructor(message: string, public readonly code: string, public readonly status = 409, public readonly retryAfterSeconds?: number) { super(message); }
}
