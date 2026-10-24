// Error messages from providers may contain credentials, prompts or user data.
// Only these fixed codes and explicitly safe metadata may leave the worker.
const codes = new Set([
  'LUNA_UNAVAILABLE', 'LUNA_AUTH_FAILED', 'LUNA_QUOTA_EXCEEDED', 'LUNA_RATE_LIMITED',
  'LUNA_REQUEST_FAILED', 'LUNA_REQUEST_TIMEOUT', 'LUNA_NETWORK_FAILURE', 'LUNA_INCOMPLETE_RESPONSE',
  'LUNA_OUTPUT_LIMIT', 'LUNA_REFUSAL', 'LUNA_INVALID_RESPONSE',
  'INVALID_MANIFEST', 'INVALID_SLOT_MAPPING', 'INVALID_REVIEW_MAPPING',
  'QUALITY_REVIEW_FAILED', 'INCOMPLETE_BATCH', 'REFERENCE_SCOPE_CHANGED',
  'ACTIVITY_CHANGED', 'PREPARATION_CALL_BUDGET', 'PREPARATION_OWNERSHIP_LOST',
  'PREPARATION_EXPIRED', 'WORKER_INTERRUPTED', 'QUEUE_UNAVAILABLE',
  'AI_UNAVAILABLE', 'AI_BUDGET_EXCEEDED', 'DATABASE_FAILURE',
]);
const providerCodes = new Set([
  'insufficient_quota', 'rate_limit_exceeded', 'invalid_api_key', 'model_not_found',
  'unsupported_parameter', 'invalid_value', 'context_length_exceeded',
  'invalid_json_schema', 'server_error', 'max_output_tokens', 'content_filter',
]);
const networkCodes = new Set(['ECONNREFUSED', 'ECONNRESET', 'ENOTFOUND', 'EAI_AGAIN', 'ETIMEDOUT', 'UND_ERR_CONNECT_TIMEOUT', 'UND_ERR_HEADERS_TIMEOUT', 'UND_ERR_SOCKET']);

export interface PreparationFailure {
  code: string;
  providerStatus?: number;
  providerCode?: string;
  causeCode?: string;
}

export class LunaFailure extends Error {
  constructor(readonly code: string, readonly providerStatus?: number, readonly providerCode?: string) {
    super(codes.has(code) ? code : 'QUALITY_OR_PROVIDER_FAILURE');
    this.name = 'LunaFailure';
  }
}

export function safeProviderCode(value: unknown): string | undefined {
  return typeof value === 'string' && providerCodes.has(value) ? value : undefined;
}

export function preparationFailure(error: unknown): PreparationFailure {
  const value = error && typeof error === 'object'
    ? error as { code?: unknown; message?: unknown; name?: unknown; providerStatus?: unknown; providerCode?: unknown; cause?: { code?: unknown } }
    : {};
  const known = [value.code, value.message].find(code => typeof code === 'string' && codes.has(code));
  if (typeof known === 'string') {
    return {
      code: known,
      ...(typeof value.providerStatus === 'number' && Number.isInteger(value.providerStatus) && value.providerStatus >= 100 && value.providerStatus <= 599
        ? { providerStatus: value.providerStatus } : {}),
      ...(safeProviderCode(value.providerCode) ? { providerCode: safeProviderCode(value.providerCode) } : {}),
    };
  }
  if (typeof value.code === 'string' && /^P\d{4}$/.test(value.code)) {
    return { code: 'DATABASE_FAILURE', causeCode: value.code };
  }
  const network = [value.code, value.cause?.code].find(code => typeof code === 'string' && networkCodes.has(code));
  if (typeof network === 'string') return { code: 'LUNA_NETWORK_FAILURE', causeCode: network };
  if (value.name === 'ZodError' || value.name === 'SyntaxError') return { code: 'LUNA_INVALID_RESPONSE' };
  if (value.name === 'AbortError' || value.name === 'TimeoutError') return { code: 'LUNA_REQUEST_TIMEOUT' };
  return { code: 'QUALITY_OR_PROVIDER_FAILURE' };
}
