import { z } from 'zod';
import { TIME_CONFIG } from '../../../config/inventory.config';

export const RawQuestionSchema = z.object({
  pattern: z.string().min(2).max(100),
  prompt: z.string().min(10).max(1000),
  options: z
    .array(
      z.object({
        id: z.enum(['A', 'B', 'C', 'D']),
        text: z.string().min(1).max(300),
      })
    )
    .length(4),
  correctAnswer: z.enum(['A', 'B', 'C', 'D']),
  difficulty: z.enum(['EASY', 'MEDIUM', 'HARD']),
  // Enforces global 30..120 seconds solving time window
  estimatedTimeSeconds: z
    .number()
    .int()
    .min(TIME_CONFIG.GLOBAL_MIN_SECONDS)
    .max(TIME_CONFIG.GLOBAL_MAX_SECONDS),
  calculationMode: z.enum(['MENTAL', 'LIGHT_PEN_AND_PAPER', 'PEN_AND_PAPER']),
  hints: z.array(z.string().min(5).max(300)).length(2),
  method: z.string().min(5).max(500),
  explanation: z.string().min(10).max(1000),
});

export type ValidatedRawQuestion = z.infer<typeof RawQuestionSchema>;

export function validateQuestionStructure(
  raw: unknown,
  isPvp = false
): { valid: true; data: ValidatedRawQuestion } | { valid: false; errors: string[] } {
  const result = RawQuestionSchema.safeParse(raw);
  if (!result.success) {
    return {
      valid: false,
      errors: result.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`),
    };
  }

  // Ensure all 4 option IDs are distinct (A, B, C, D)
  const optionIds = new Set(result.data.options.map((o) => o.id));
  if (optionIds.size !== 4) {
    return { valid: false, errors: ['Option IDs must be unique (A, B, C, D)'] };
  }

  // Ensure correctAnswer matches one of the option IDs
  if (!optionIds.has(result.data.correctAnswer)) {
    return { valid: false, errors: ['correctAnswer must be one of A, B, C, D'] };
  }

  // PvP additional time constraint: must be <= 60 seconds
  if (isPvp && result.data.estimatedTimeSeconds > TIME_CONFIG.PVP_MAX_SECONDS) {
    return {
      valid: false,
      errors: [`PvP questions must be solvable in <= ${TIME_CONFIG.PVP_MAX_SECONDS} seconds`],
    };
  }

  return { valid: true, data: result.data };
}
