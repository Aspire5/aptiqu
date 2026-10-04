import { GoogleGenAI } from '@google/genai';
import { ENV } from '../../config/env';

export class GeminiProvider {
  private static instance: GeminiProvider;
  private ai: GoogleGenAI | null = null;
  private lastCallTimestamp: number = 0;
  private minIntervalMs: number = 2500; // Minimum 2.5s between calls to stay well within 15 RPM

  private constructor() {
    if (ENV.GEMINI_API_KEY && ENV.GEMINI_API_KEY.trim().length > 0) {
      this.ai = new GoogleGenAI({ apiKey: ENV.GEMINI_API_KEY });
    }
  }

  public static getInstance(): GeminiProvider {
    if (!GeminiProvider.instance) {
      GeminiProvider.instance = new GeminiProvider();
    }
    return GeminiProvider.instance;
  }

  public isConfigured(): boolean {
    return this.ai !== null;
  }

  /**
   * Helper to parse retry delay from Google Gemini 429 / 503 error messages.
   */
  private extractRetryDelayMs(errorMsg: string): number | null {
    // 1. Try matching "retryDelay": "15s" or similar
    const jsonMatch = errorMsg.match(/retryDelay"?\s*:\s*"?(\d+)(?:\.\d+)?s?"?/i);
    if (jsonMatch && jsonMatch[1]) {
      return Math.ceil(parseFloat(jsonMatch[1])) * 1000;
    }

    // 2. Try matching "Please retry in 15.87s"
    const textMatch = errorMsg.match(/Please retry in\s+([\d.]+)\s*s/i);
    if (textMatch && textMatch[1]) {
      return Math.ceil(parseFloat(textMatch[1])) * 1000;
    }

    return null;
  }

  /**
   * Enforces minimum spacing between API calls to prevent RPM and burst token spikes.
   */
  private async throttle(): Promise<void> {
    const now = Date.now();
    const elapsed = now - this.lastCallTimestamp;
    if (elapsed < this.minIntervalMs) {
      const waitTime = this.minIntervalMs - elapsed;
      await new Promise((resolve) => setTimeout(resolve, waitTime));
    }
    this.lastCallTimestamp = Date.now();
  }

  public async generateStructuredContent<T>(params: {
    systemInstruction: string;
    prompt: string;
    responseSchema: Record<string, any>;
    thinkingBudget?: number;
    timeoutMs?: number;
    maxRetries?: number;
  }): Promise<T> {
    if (!this.ai) {
      throw new Error(
        'GEMINI_API_KEY is not configured on the server. Please set GEMINI_API_KEY in backend/.env'
      );
    }

    const {
      systemInstruction,
      prompt,
      responseSchema,
      thinkingBudget = ENV.GEMINI_THINKING_BUDGET || 1024,
      timeoutMs = 60000,
      maxRetries = 3,
    } = params;

    const modelName = ENV.GEMINI_MODEL || 'gemini-3.5-flash-lite';
    let lastError: any = null;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      await this.throttle();

      const config: Record<string, any> = {
        systemInstruction,
        responseMimeType: 'application/json',
        responseSchema,
        temperature: 0.2, // Low temperature for high mathematical accuracy
      };

      if (thinkingBudget > 0) {
        config.thinkingConfig = { thinkingBudget };
      }

      const timeoutPromise = new Promise<never>((_, reject) =>
        setTimeout(
          () => reject(new Error(`Gemini request timed out after ${timeoutMs}ms`)),
          timeoutMs
        )
      );

      const callPromise = this.ai.models.generateContent({
        model: modelName,
        contents: prompt,
        config,
      });

      const startTime = Date.now();
      if (attempt === 0) {
        console.log(
          `[GeminiProvider] Dispatching prompt to model "${modelName}" (length: ${prompt.length} chars, timeout: ${timeoutMs}ms, thinkingBudget: ${thinkingBudget})`
        );
      } else {
        console.log(
          `[GeminiProvider] Retrying prompt to model "${modelName}" (attempt ${attempt + 1}/${maxRetries + 1})...`
        );
      }

      try {
        const response: any = await Promise.race([callPromise, timeoutPromise]);
        const elapsed = Date.now() - startTime;
        const rawText = response.text?.trim();

        if (!rawText) {
          console.error(`[GeminiProvider] Empty response received from "${modelName}" after ${elapsed}ms.`);
          throw new Error('Empty response received from Gemini API.');
        }

        console.log(`[GeminiProvider] Successfully received response from "${modelName}" in ${elapsed}ms (${rawText.length} bytes).`);

        try {
          return JSON.parse(rawText) as T;
        } catch (err: any) {
          console.error(`[GeminiProvider] Failed to parse JSON response:`, err.message);
          throw new Error(
            `Failed to parse Gemini JSON output: ${err.message}. Raw output preview: ${rawText.slice(0, 200)}`
          );
        }
      } catch (err: any) {
        lastError = err;
        const elapsed = Date.now() - startTime;
        const errMsg = String(err.message || '');
        const isQuotaExceeded = errMsg.includes('429') || errMsg.includes('RESOURCE_EXHAUSTED') || errMsg.includes('quota');
        const isTemporaryUnavailable = errMsg.includes('503') || errMsg.includes('UNAVAILABLE') || errMsg.includes('high demand');

        console.error(
          `[GeminiProvider] Request to "${modelName}" failed after ${elapsed}ms: ${errMsg}`
        );

        if ((isQuotaExceeded || isTemporaryUnavailable) && attempt < maxRetries) {
          // Parse explicit retry delay from server if provided, otherwise exponential backoff
          const serverDelayMs = this.extractRetryDelayMs(errMsg);
          const backoffMs = serverDelayMs
            ? serverDelayMs + 2000 // Add safety jitter
            : Math.min(30000, Math.pow(2, attempt + 1) * 4000 + Math.floor(Math.random() * 2000));

          console.warn(
            `[GeminiProvider] Rate limit / high demand encountered. Backing off for ${Math.round(backoffMs / 1000)}s before retry ${attempt + 1}/${maxRetries}...`
          );
          await new Promise((resolve) => setTimeout(resolve, backoffMs));
          continue;
        }

        // If not retryable or retries exhausted, throw
        throw err;
      }
    }

    throw lastError;
  }
}

export const geminiProvider = GeminiProvider.getInstance();

