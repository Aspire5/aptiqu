export interface AiDoubtContext {
  userId: string;
  sessionId: string;
  scriptVersionId: string;
  nodeId: string;
  nodeText: string;
  userQuestion: string;
  recentAttempts?: Array<{
    prompt: string;
    userRawAnswer: string;
    isCorrect: boolean;
  }>;
}

export interface IAiGateway {
  answerDoubt(context: AiDoubtContext): Promise<string>;
  evaluateOpenText(prompt: string, answer: string, rubric?: string): Promise<{ score: number; feedback: string }>;
}
