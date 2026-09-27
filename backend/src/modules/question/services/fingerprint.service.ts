import crypto from 'crypto';
import { QuestionOption } from '../domain/question.types';

export class FingerprintService {
  /**
   * Normalizes text by lowercasing, stripping extra whitespace,
   * but preserving mathematical symbols (+, -, *, /, =, %, ^).
   */
  public static normalizeText(text: string): string {
    return text
      .toLowerCase()
      .replace(/[^\w\s+\-*\/=^%]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * Computes a deterministic SHA-256 fingerprint for a question prompt and its options.
   * Format: SHA-256(normalizedPrompt + ':::' + sortedNormalizedOptions.join('|||'))
   */
  public static computeFingerprint(prompt: string, options: QuestionOption[]): string {
    const normPrompt = this.normalizeText(prompt);
    const normOptions = options
      .map((opt) => this.normalizeText(opt.text))
      .sort()
      .join('|||');

    const rawPayload = `${normPrompt}:::${normOptions}`;
    return crypto.createHash('sha256').update(rawPayload).digest('hex');
  }
}
