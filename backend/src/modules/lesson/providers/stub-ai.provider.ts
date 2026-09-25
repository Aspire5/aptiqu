import { IAiGateway, AiDoubtContext } from '../interfaces/ai-gateway.interface';

export class StubAiProvider implements IAiGateway {
  async answerDoubt(_context: AiDoubtContext): Promise<string> {
    return 'AI tutoring is not integrated yet. Please continue with your lesson!';
  }

  async evaluateOpenText(_prompt: string, _answer: string, _rubric?: string): Promise<{ score: number; feedback: string }> {
    return {
      score: 1.0,
      feedback: 'Response recorded successfully.',
    };
  }
}

export const defaultAiProvider: IAiGateway = new StubAiProvider();
