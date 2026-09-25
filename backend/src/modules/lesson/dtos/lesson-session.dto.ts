import { z } from 'zod';

export const StartSessionDto = z
  .object({
    scriptSlug: z.string().optional(),
    roadmapStepId: z.string().optional(),
    clientActionId: z.string().uuid('clientActionId must be a valid UUID'),
  })
  .refine((data) => data.scriptSlug || data.roadmapStepId, {
    message: 'Either scriptSlug or roadmapStepId must be provided',
  });

export type StartSessionInput = z.infer<typeof StartSessionDto>;

