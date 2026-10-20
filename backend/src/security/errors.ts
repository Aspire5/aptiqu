export class PublicError extends Error {
  constructor(message: string, public code = 'INVALID_REQUEST', public status = 400, public retryAfterSeconds?: number) { super(message); }
}
