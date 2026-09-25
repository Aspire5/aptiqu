import { z } from 'zod';

export const StartSessionDto = z.object({
  scriptSlug: z.string().optional(),
  roadmapStepId: z.string().optional(),
  clientActionId: z.string().uuid('clientActionId must be a valid UUID'),
});

export type StartSessionInput = z.infer<typeof StartSessionDto>;

