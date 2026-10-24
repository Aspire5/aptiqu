# Offline evaluation checks

This checks a deliberately limited four-operation positive-integer grammar with exact rational arithmetic, never JavaScript eval. It is not the proposed production verifier or a teaching-quality certification.

## sample-2-openai-beginner.md

JSON parsed; 12 uniquely identified screens; 4 main checks.

| Item | Expression in prompt | Independently evaluated value | Stored key / labelled value | Result |
|---|---|---|---|---|
| s3 | 18 ÷ 3 × 2 | 12 | b / 12 | key agrees; prompt present |
| s3 retry | 20 ÷ 4 × 3 | 15 | c / 15 | key agrees; prompt present |
| s5 | 7 × 4 ÷ 2 | 14 | d / 14 | key agrees; prompt present |
| s5 retry | 9 × 6 ÷ 3 | 18 | b / 27 | BLOCK: answer mismatch; prompt present |
| s8 | 20 − 12 ÷ 3 + 2 | 18 | a / 18 | key agrees; prompt present |
| s8 retry | 25 − 15 ÷ 5 + 3 | 25 | a / 17 | BLOCK: answer mismatch; prompt present |
| s10 | 30 ÷ 5 × 2 + 4 − 3 | 13 | c / 13 | key agrees; prompt present |
| s10 retry | 36 ÷ 6 × 2 + 5 − 4 | 13 | b / 13 | key agrees; prompt present |

Stored answer positions across all eight items: A=2, B=3, C=2, D=1.

Other language, reasoning, scope, repetition, analogy and phone-layout findings require the manual review in document 12.

## sample-3-openai-advanced.md

JSON parsed; 11 uniquely identified screens; 4 main checks.

| Item | Expression in prompt | Independently evaluated value | Stored key / labelled value | Result |
|---|---|---|---|---|
| s3 | 72 ÷ 8 × 5 | 45 | a / 45 | key agrees; prompt present |
| s3 retry | 63 ÷ 7 × 4 | 36 | c / 36 | key agrees; prompt present |
| s5 | 64 − 20 ÷ 5 × 3 | 52 | b / 52 | key agrees; prompt present |
| s5 retry | 73 − 24 ÷ 6 × 4 | 57 | d / 57 | key agrees; prompt present |
| s8 | 9 + 48 ÷ 8 − 3 | 12 | c / 9 | BLOCK: answer mismatch; prompt present |
| s8 retry | 11 + 42 ÷ 7 − 4 | 13 | a / 13 | key agrees; prompt present |
| s10 | 70 − 36 ÷ 6 × 4 + 9 | 55 | b / 41 | BLOCK: answer mismatch; prompt present |
| s10 retry | 80 − 45 ÷ 5 × 3 + 6 | 59 | c / 59 | key agrees; prompt present |

Stored answer positions across all eight items: A=2, B=2, C=3, D=1.

Other language, reasoning, scope, repetition, analogy and phone-layout findings require the manual review in document 12.

## sample-6-openai-beginner.md

JSON parsed; 12 uniquely identified screens; 4 main checks.

| Item | Expression in prompt | Independently evaluated value | Stored key / labelled value | Result |
|---|---|---|---|---|
| s5 | MISSING; expected fixture: 18 ÷ 3 × 2 | 12 | b / 12 | key agrees; BLOCK: expression missing |
| s5 retry | MISSING; expected fixture: 28 ÷ 7 × 3 | 12 | a / 12 | key agrees; BLOCK: expression missing |
| s7 | MISSING; expected fixture: 48 ÷ 4 ÷ 3 | 4 | d / 4 | key agrees; BLOCK: expression missing |
| s7 retry | MISSING; expected fixture: 60 ÷ 5 ÷ 3 | 4 | c / 4 | key agrees; BLOCK: expression missing |
| s9 | MISSING; expected fixture: 6 × 8 ÷ 4 | 12 | a / 12 | key agrees; BLOCK: expression missing |
| s9 retry | MISSING; expected fixture: 7 × 6 ÷ 3 | 14 | d / 14 | key agrees; BLOCK: expression missing |
| s11 | MISSING; expected fixture: 30 − 24 ÷ 4 × 2 + 5 | 23 | c / 23 | key agrees; BLOCK: expression missing |
| s11 retry | MISSING; expected fixture: 40 − 36 ÷ 6 × 3 + 2 | 24 | b / 24 | key agrees; BLOCK: expression missing |

Stored answer positions across all eight items: A=2, B=2, C=2, D=2.

Other language, reasoning, scope, repetition, analogy and phone-layout findings require the manual review in document 12.

## Totals

24 main/retry items inspected; 4 stored-key/value mismatches; 8 prompts missing their expression. No sample is release-approved.
