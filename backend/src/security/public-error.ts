import { log, safeError } from '../observability/logger';
import { Response } from 'express';
import { ZodError } from 'zod';
import { PublicError } from './errors';
import { PvpError } from '../modules/pvp/pvp.errors';

export function publicFailure(res: Response, error: unknown): void {
  if (error instanceof PublicError || error instanceof PvpError) {
    const retryAfter = error.retryAfterSeconds ?? (error.status === 503 ? 3 : undefined);
    if (retryAfter) res.setHeader('Retry-After', String(retryAfter));
    res.status(error.status).json({ success: false, code: error.code, message: error.message });
  } else if (error instanceof ZodError) {
    res.status(400).json({ success: false, code: 'INVALID_REQUEST', message: 'Invalid request' });
  } else {
    // Avoid exception messages: ORM errors can embed SQL, bound values and file paths.
    log('error','request.failed',safeError(error));
    res.status(500).json({
      success: false, code: 'INTERNAL_SERVER_ERROR', message: 'Could not process this request. Please retry.',
    });
  }
}
