import { GoogleGenAI } from '@google/genai';
import { ENV } from '../../config/env';

export class GeminiProvider {
  private static instance: GeminiProvider;
  private ai: GoogleGenAI | null = null;

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

  public async generateStructuredContent<T>(params: {
    systemInstruction: string;
    prompt: string;
    responseSchema: Record<string, any>;
    thinkingBudget?: number;
    timeoutMs?: number;
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
    } = params;

    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(
        () => reject(new Error(`Gemini request timed out after ${timeoutMs}ms`)),
        timeoutMs
      )
    );

    const config: Record<string, any> = {
      systemInstruction,
      responseMimeType: 'application/json',
      responseSchema,
      temperature: 0.2, // Low temperature for high mathematical accuracy
    };

    if (thinkingBudget > 0) {
      config.thinkingConfig = { thinkingBudget };
    }

    const callPromise = this.ai.models.generateContent({
      model: ENV.GEMINI_MODEL || 'gemini-3.5-flash-lite',
      contents: prompt,
      config,
    });

    const modelName = ENV.GEMINI_MODEL || 'gemini-3.5-flash-lite';
    const startTime = Date.now();
    console.log(
      `[GeminiProvider] Dispatching prompt to model "${modelName}" (length: ${prompt.length} chars, timeout: ${timeoutMs}ms, thinkingBudget: ${thinkingBudget})`
    );

    let response: any;
    try {
      response = await Promise.race([callPromise, timeoutPromise]);
    } catch (err: any) {
      const elapsed = Date.now() - startTime;
      console.error(`[GeminiProvider] Request to "${modelName}" failed after ${elapsed}ms:`, err.message);
      throw err;
    }

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
  }
}

export const geminiProvider = GeminiProvider.getInstance();
