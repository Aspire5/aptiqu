import { LessonNode } from '../interfaces/script-dsl.interface';

const text = (value: unknown): string | undefined => typeof value === 'string' ? value : undefined;
const options = (value: unknown) => Array.isArray(value)
  ? value.filter(option => option && typeof option.id === 'string' && typeof option.label === 'string')
    .map(option => ({ id: option.id, label: option.label }))
  : [];

// Construct the public display/input tree; never copy transition conditions, arbitrary option
// payloads, answer keys, feedback or variation objects from a stored script.
export function publicLessonNode(node: LessonNode): LessonNode {
  const result: any = {
    id: text(node.id),
    type: text(node.type),
    content: {
      text: text(node.content?.text) ?? '',
      mediaUrl: text(node.content?.mediaUrl),
      avatarPersona: text(node.content?.avatarPersona),
    },
    interruptible: typeof node.interruptible === 'boolean' ? node.interruptible : undefined,
    transitions: [],
  };
  if (node.input) {
    result.input = {
      type: text(node.input.type),
      placeholder: text(node.input.placeholder),
      options: options(node.input.options),
    };
  }
  if (node.questionReference) {
    const ref = node.questionReference;
    result.questionReference = {
      mode: text(ref.mode), questionId: text(ref.questionId), externalId: text(ref.externalId),
    };
    if (ref.inlineData) {
      const question = ref.inlineData;
      result.questionReference.inlineData = {
        prompt: text(question.prompt),
        options: options(question.options),
        hints: Array.isArray(question.hints) ? question.hints.filter(hint => typeof hint === 'string') : [],
        xp: typeof question.xp === 'number' && Number.isFinite(question.xp) ? question.xp : undefined,
        difficulty: text(question.difficulty),
        questionType: text(question.questionType),
        pyq: text(question.pyq),
      };
    }
  }
  return JSON.parse(JSON.stringify(result));
}
