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
      timeoutMs = 25000,
    } = params;

    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(
        () => reject(new Error(`Gemini request timed out after ${timeoutMs}ms`)),
        timeoutMs
      )
    );

    const callPromise = this.ai.models.generateContent({
      model: ENV.GEMINI_MODEL || 'gemini-3.5-flash-lite',
      contents: prompt,
      config: {
        systemInstruction,
        thinkingConfig: {
          thinkingBudget,
        },
        responseMimeType: 'application/json',
        responseSchema,
        temperature: 0.2, // Low temperature for high mathematical accuracy
      },
    });

    const response = await Promise.race([callPromise, timeoutPromise]);
    const rawText = response.text?.trim();

    if (!rawText) {
      throw new Error('Empty response received from Gemini API.');
    }

    try {
      return JSON.parse(rawText) as T;
    } catch (err: any) {
      throw new Error(
        `Failed to parse Gemini JSON output: ${err.message}. Raw output preview: ${rawText.slice(0, 200)}`
      );
    }
  }
}

export const geminiProvider = GeminiProvider.getInstance();
