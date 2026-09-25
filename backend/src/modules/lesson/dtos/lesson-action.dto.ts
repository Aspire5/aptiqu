import { z } from 'zod';

export const SubmitActionDto = z.object({
  clientActionId: z.string().uuid('clientActionId must be a valid UUID'),
  stateVersion: z.number().int().min(1, 'stateVersion must be a positive integer'),
  currentNodeId: z.string().min(1, 'currentNodeId is required'),
  action: z.object({
    type: z.enum(['CHOICE', 'QUESTION_ANSWER', 'TEXT_SUBMISSION', 'CONTINUE']),
    actionId: z.string().optional(),
    answer: z.string().optional(),
    responseTimeMs: z.number().optional(),
  }),
});

export type SubmitActionInput = z.infer<typeof SubmitActionDto>;

export const InterruptDto = z.object({
  clientActionId: z.string().uuid('clientActionId must be a valid UUID'),
  currentNodeId: z.string().min(1, 'currentNodeId is required'),
  questionText: z.string().min(1).max(500, 'questionText cannot exceed 500 characters'),
});

export type InterruptInput = z.infer<typeof InterruptDto>;
