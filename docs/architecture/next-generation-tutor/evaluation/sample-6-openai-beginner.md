# gpt-6-luna: beginner

Synthetic evaluation only. Not published teaching content.

```json
{
  "title": "Multiplication, Division, Addition, and Subtraction",
  "scopeSummary": "Learn to work through multiplication and division in written order, then addition and subtraction, using positive integers and exact whole-number results.",
  "screens": [
    {
      "id": "s1",
      "kind": "teach",
      "text": "Imagine 18 apples shared equally among 3 bowls. Then put 2 such groups of bowls on the table.\n\nWe can write the calculation as 18 ÷ 3 × 2.",
      "options": [],
      "correctOptionId": "",
      "explanation": "",
      "hint": "",
      "wrongAnswerFeedback": "",
      "difficulty": "",
      "retry": {
        "prompt": "",
        "options": [],
        "correctOptionId": "",
        "explanation": ""
      }
    },
    {
      "id": "s2",
      "kind": "teach",
      "text": "Multiplication and division have equal priority. When both appear, work from left to right, in the written order.\n\nAn unbracketed chain means doing one operation, then the next. A different grouping can change the expression and its value.",
      "options": [],
      "correctOptionId": "",
      "explanation": "",
      "hint": "",
      "wrongAnswerFeedback": "",
      "difficulty": "",
      "retry": {
        "prompt": "",
        "options": [],
        "correctOptionId": "",
        "explanation": ""
      }
    },
    {
      "id": "s3",
      "kind": "teach",
      "text": "Predict the value of this expression.\n\n18 ÷ 3 × 2\n\nWhat should you calculate first?",
      "options": [],
      "correctOptionId": "",
      "explanation": "",
      "hint": "",
      "wrongAnswerFeedback": "",
      "difficulty": "",
      "retry": {
        "prompt": "",
        "options": [],
        "correctOptionId": "",
        "explanation": ""
      }
    },
    {
      "id": "s4",
      "kind": "teach",
      "text": "Start with the left operation, then use its result.\n\n18 ÷ 3 = 6\n6 × 2 = 12\n\nSo the value is 12. Doing 3 × 2 first would use a different grouping: 18 ÷ (3 × 2) = 3.",
      "options": [],
      "correctOptionId": "",
      "explanation": "",
      "hint": "",
      "wrongAnswerFeedback": "",
      "difficulty": "",
      "retry": {
        "prompt": "",
        "options": [],
        "correctOptionId": "",
        "explanation": ""
      }
    },
    {
      "id": "s5",
      "kind": "check",
      "text": "Evaluate the expression from left to right.",
      "options": [
        {
          "id": "a",
          "label": "3"
        },
        {
          "id": "b",
          "label": "12"
        },
        {
          "id": "c",
          "label": "6"
        },
        {
          "id": "d",
          "label": "18"
        }
      ],
      "correctOptionId": "b",
      "explanation": "Divide first, then multiply:\n18 ÷ 3 = 6\n6 × 2 = 12\n\nCheck: 12 ÷ 2 = 6, and 6 × 3 = 18.",
      "hint": "Start with the division on the left. Use that answer in the multiplication.",
      "wrongAnswerFeedback": "A common slip is to multiply 3 × 2 first. Keep the written order: divide 18 by 3, then multiply by 2.",
      "difficulty": "EASY",
      "retry": {
        "prompt": "Try this fresh expression. Evaluate from left to right.",
        "options": [
          {
            "id": "a",
            "label": "12"
          },
          {
            "id": "b",
            "label": "4"
          },
          {
            "id": "c",
            "label": "21"
          },
          {
            "id": "d",
            "label": "84"
          }
        ],
        "correctOptionId": "a",
        "explanation": "Work from the left:\n28 ÷ 7 = 4\n4 × 3 = 12\n\nCheck: 12 ÷ 3 = 4, and 4 × 7 = 28."
      }
    },
    {
      "id": "s6",
      "kind": "teach",
      "text": "Now look at two divisions in a row. Keep moving from left to right, using each answer for the next step.\n\n72 ÷ 6 ÷ 2\n72 ÷ 6 = 12\n12 ÷ 2 = 6\n\nA different grouping gives 72 ÷ (6 ÷ 2) = 24, so grouping matters here.",
      "options": [],
      "correctOptionId": "",
      "explanation": "",
      "hint": "",
      "wrongAnswerFeedback": "",
      "difficulty": "",
      "retry": {
        "prompt": "",
        "options": [],
        "correctOptionId": "",
        "explanation": ""
      }
    },
    {
      "id": "s7",
      "kind": "check",
      "text": "Evaluate the expression from left to right.",
      "options": [
        {
          "id": "a",
          "label": "36"
        },
        {
          "id": "b",
          "label": "12"
        },
        {
          "id": "c",
          "label": "16"
        },
        {
          "id": "d",
          "label": "4"
        }
      ],
      "correctOptionId": "d",
      "explanation": "Do the divisions in written order:\n48 ÷ 4 = 12\n12 ÷ 3 = 4\n\nCheck: 4 × 3 × 4 = 48.",
      "hint": "Divide 48 by 4 first. Then divide that result by 3.",
      "wrongAnswerFeedback": "A common slip is to divide by 4 and 3 together as one step. Instead, use the left-to-right results: first 48 ÷ 4, then divide by 3.",
      "difficulty": "MEDIUM",
      "retry": {
        "prompt": "Try this fresh expression. Evaluate from left to right.",
        "options": [
          {
            "id": "a",
            "label": "36"
          },
          {
            "id": "b",
            "label": "12"
          },
          {
            "id": "c",
            "label": "4"
          },
          {
            "id": "d",
            "label": "15"
          }
        ],
        "correctOptionId": "c",
        "explanation": "Work from the left:\n60 ÷ 5 = 12\n12 ÷ 3 = 4\n\nCheck: 4 × 3 × 5 = 60."
      }
    },
    {
      "id": "s8",
      "kind": "teach",
      "text": "Multiplication and division still have equal priority when they appear together. Follow their written order, even when multiplication comes first.\n\n7 × 6 ÷ 3\n7 × 6 = 42\n42 ÷ 3 = 14",
      "options": [],
      "correctOptionId": "",
      "explanation": "",
      "hint": "",
      "wrongAnswerFeedback": "",
      "difficulty": "",
      "retry": {
        "prompt": "",
        "options": [],
        "correctOptionId": "",
        "explanation": ""
      }
    },
    {
      "id": "s9",
      "kind": "check",
      "text": "Evaluate the expression from left to right.",
      "options": [
        {
          "id": "a",
          "label": "12"
        },
        {
          "id": "b",
          "label": "48"
        },
        {
          "id": "c",
          "label": "3"
        },
        {
          "id": "d",
          "label": "24"
        }
      ],
      "correctOptionId": "a",
      "explanation": "Multiply first because it is written first:\n6 × 8 = 48\n48 ÷ 4 = 12\n\nCheck: 12 × 4 = 48, and 6 × 8 = 48.",
      "hint": "The multiplication is on the left. Multiply 6 by 8, then divide the result by 4.",
      "wrongAnswerFeedback": "A common slip is to divide 8 by 4 before multiplying. Since the multiplication comes first in the written order, calculate 6 × 8 first.",
      "difficulty": "EASY",
      "retry": {
        "prompt": "Try this fresh expression. Evaluate from left to right.",
        "options": [
          {
            "id": "a",
            "label": "42"
          },
          {
            "id": "b",
            "label": "7"
          },
          {
            "id": "c",
            "label": "21"
          },
          {
            "id": "d",
            "label": "14"
          }
        ],
        "correctOptionId": "d",
        "explanation": "Work from the left:\n7 × 6 = 42\n42 ÷ 3 = 14\n\nCheck: 14 × 3 = 42, and 7 × 6 = 42."
      }
    },
    {
      "id": "s10",
      "kind": "teach",
      "text": "In a longer expression, do multiplication and division before addition and subtraction. Within each group, move from left to right.\n\n20 − 12 ÷ 3 × 2 + 4\n12 ÷ 3 = 4; 4 × 2 = 8\n20 − 8 + 4 = 16",
      "options": [],
      "correctOptionId": "",
      "explanation": "",
      "hint": "",
      "wrongAnswerFeedback": "",
      "difficulty": "",
      "retry": {
        "prompt": "",
        "options": [],
        "correctOptionId": "",
        "explanation": ""
      }
    },
    {
      "id": "s11",
      "kind": "check",
      "text": "Evaluate the expression. Do multiplication and division first, from left to right; then do addition and subtraction from left to right.",
      "options": [
        {
          "id": "a",
          "label": "29"
        },
        {
          "id": "b",
          "label": "17"
        },
        {
          "id": "c",
          "label": "23"
        },
        {
          "id": "d",
          "label": "8"
        }
      ],
      "correctOptionId": "c",
      "explanation": "First work through division and multiplication:\n24 ÷ 4 = 6\n6 × 2 = 12\n\nThen subtract and add in written order:\n30 − 12 = 18\n18 + 5 = 23\n\nCheck: 23 − 5 + 12 = 30.",
      "hint": "Find 24 ÷ 4, then multiply that result by 2. After that, calculate 30 − the result + 5 from left to right.",
      "wrongAnswerFeedback": "A common slip is to subtract 24 from 30 before doing the division and multiplication. Do the division and multiplication first, then subtract and add from left to right.",
      "difficulty": "MEDIUM",
      "retry": {
        "prompt": "Try this fresh expression. Follow the same operation order.",
        "options": [
          {
            "id": "a",
            "label": "36"
          },
          {
            "id": "b",
            "label": "24"
          },
          {
            "id": "c",
            "label": "20"
          },
          {
            "id": "d",
            "label": "10"
          }
        ],
        "correctOptionId": "b",
        "explanation": "First do division and multiplication:\n36 ÷ 6 = 6\n6 × 3 = 18\n\nThen subtract and add from left to right:\n40 − 18 = 22\n22 + 2 = 24\n\nCheck: 24 − 2 + 18 = 40."
      }
    },
    {
      "id": "s12",
      "kind": "recap",
      "text": "Remember: multiplication and division have equal priority, so work through them in written order. Then do addition and subtraction in written order.\n\nIn your own words, how would you explain this rule or check that you followed it?",
      "options": [],
      "correctOptionId": "",
      "explanation": "",
      "hint": "",
      "wrongAnswerFeedback": "",
      "difficulty": "",
      "retry": {
        "prompt": "",
        "options": [],
        "correctOptionId": "",
        "explanation": ""
      }
    }
  ]
}
```
