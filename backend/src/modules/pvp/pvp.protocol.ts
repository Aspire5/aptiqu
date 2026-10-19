import { z } from 'zod';

const empty = z.object({}).strict().optional();
export const pvpMessageSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('AUTH_INIT'), payload: z.object({ token: z.string().min(1).max(4096) }).strict() }).strict(),
  z.object({ type: z.literal('JOIN_MATCHMAKING'), payload: z.object({ rankedCapability: z.literal(1).optional() }).strict().optional() }).strict(),
  z.object({ type: z.literal('LEAVE_MATCHMAKING'), payload: empty }).strict(),
  z.object({ type: z.literal('RECONNECT_MATCH'), payload: z.object({ matchId: z.string().uuid() }).strict() }).strict(),
  z.object({ type: z.literal('SUBMIT_ANSWER'), payload: z.object({
    matchId: z.string().uuid(), questionIndex: z.number().int().min(0).max(9),
    selectedOptionId: z.string().trim().min(1).max(32).nullable(),
    // Compatibility telemetry only; this value never enters scoring.
    responseTimeMs: z.number().finite().min(0).max(60000).optional(),
  }).strict() }).strict(),
]);
export type PvpMessage = z.infer<typeof pvpMessageSchema>;
