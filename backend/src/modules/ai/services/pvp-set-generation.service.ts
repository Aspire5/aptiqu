import { PublicError } from '../../../security/errors';

/** Playable PvP content is generated only inside a participant-owned preparation. */
export class PvpSetGenerationService {
  private static instance: PvpSetGenerationService;
  static getInstance() { return this.instance ??= new PvpSetGenerationService(); }
  async generatePvpQuestionSet(): Promise<never> {
    throw new PublicError('Start a match to prepare fresh questions. Standalone set seeding is disabled.', 'SESSION_PREPARATION_REQUIRED', 409);
  }
}
export const pvpSetGenerationService = PvpSetGenerationService.getInstance();
