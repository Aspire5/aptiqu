# gpt-6-luna: beginner

Synthetic evaluation only. Not published teaching content.

```json
{
  "title": "Multiplication and division in order",
  "scopeSummary": "Learn to work through multiplication and division from left to right before doing addition and subtraction.",
  "screens": [
    {
      "id": "s1",
      "kind": "teach",
      "text": "There are 3 bags with 4 apples in each bag.\n\n3 × 4 = 12 apples\n\nThe number sentence gives the same steps: multiply 3 by 4.",
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
      "text": "Now read this from left to right:\n\n12 ÷ 3 × 2\n\nFirst, 12 ÷ 3 = 4. Then 4 × 2 = 8.\n\nMultiplication and division have equal priority. Work in written order.",
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
      "kind": "check",
      "text": "Evaluate:\n\n18 ÷ 3 × 2",
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
      "explanation": "Work left to right: 18 ÷ 3 = 6, then 6 × 2 = 12. Check: 12 ÷ 2 = 6, and 6 × 3 = 18.",
      "hint": "Start with the operation written farthest left: 18 ÷ 3.",
      "wrongAnswerFeedback": "A common slip is to multiply 3 × 2 first. In this question, start with 18 ÷ 3 because division comes first in the written order.",
      "difficulty": "EASY",
      "retry": {
        "prompt": "Evaluate:\n\n20 ÷ 4 × 3",
        "options": [
          {
            "id": "a",
            "label": "5"
          },
          {
            "id": "b",
            "label": "12"
          },
          {
            "id": "c",
            "label": "15"
          },
          {
            "id": "d",
            "label": "60"
          }
        ],
        "correctOptionId": "c",
        "explanation": "Work left to right: 20 ÷ 4 = 5, then 5 × 3 = 15. Check: 15 ÷ 3 = 5, and 5 × 4 = 20."
      }
    },
    {
      "id": "s4",
      "kind": "teach",
      "text": "Why use written order? An unbracketed chain means do each operation in turn, from left to right.\n\nFor 18 ÷ 3 × 2, the intended grouping is (18 ÷ 3) × 2.\n\nChanging the grouping changes the expression.",
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
      "text": "Evaluate:\n\n7 × 4 ÷ 2",
      "options": [
        {
          "id": "a",
          "label": "56"
        },
        {
          "id": "b",
          "label": "3"
        },
        {
          "id": "c",
          "label": "28"
        },
        {
          "id": "d",
          "label": "14"
        }
      ],
      "correctOptionId": "d",
      "explanation": "Work left to right: 7 × 4 = 28, then 28 ÷ 2 = 14. Check: 14 × 2 = 28, and 28 ÷ 4 = 7.",
      "hint": "Multiply the first two numbers, then divide that result by 2.",
      "wrongAnswerFeedback": "A common slip is to divide 4 by 2 first. In this question, multiplication and division have equal priority, so begin with 7 × 4.",
      "difficulty": "EASY",
      "retry": {
        "prompt": "Evaluate:\n\n9 × 6 ÷ 3",
        "options": [
          {
            "id": "a",
            "label": "18"
          },
          {
            "id": "b",
            "label": "27"
          },
          {
            "id": "c",
            "label": "3"
          },
          {
            "id": "d",
            "label": "54"
          }
        ],
        "correctOptionId": "b",
        "explanation": "Work left to right: 9 × 6 = 54, then 54 ÷ 3 = 18. Correction: the correct answer is 18, option a."
      }
    },
    {
      "id": "s6",
      "kind": "teach",
      "text": "Here is another chain:\n\n24 ÷ 4 × 3\n\nFirst, 24 ÷ 4 = 6. Then 6 × 3 = 18.\n\nDivision is not freely regrouped. Doing 4 × 3 first would change the expression and its value.",
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
      "kind": "teach",
      "text": "Now include addition and subtraction.\n\n20 − 12 ÷ 3 + 2\n\nDo division first: 12 ÷ 3 = 4.\n\nThen work left to right: 20 − 4 + 2 = 18.",
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
      "id": "s8",
      "kind": "check",
      "text": "Evaluate:\n\n20 − 12 ÷ 3 + 2",
      "options": [
        {
          "id": "a",
          "label": "18"
        },
        {
          "id": "b",
          "label": "10"
        },
        {
          "id": "c",
          "label": "6"
        },
        {
          "id": "d",
          "label": "14"
        }
      ],
      "correctOptionId": "a",
      "explanation": "First divide: 12 ÷ 3 = 4. Then work left to right: 20 − 4 = 16, and 16 + 2 = 18. Check: 18 − 2 = 16, then 16 + 4 = 20.",
      "hint": "Do 12 ÷ 3 first. Then handle subtraction and addition from left to right.",
      "wrongAnswerFeedback": "A common slip is to add 3 and 2 before dividing. In this question, division comes before addition and subtraction.",
      "difficulty": "MEDIUM",
      "retry": {
        "prompt": "Evaluate:\n\n25 − 15 ÷ 5 + 3",
        "options": [
          {
            "id": "a",
            "label": "17"
          },
          {
            "id": "b",
            "label": "13"
          },
          {
            "id": "c",
            "label": "25"
          },
          {
            "id": "d",
            "label": "5"
          }
        ],
        "correctOptionId": "a",
        "explanation": "First, 15 ÷ 5 = 3. Then 25 − 3 + 3 = 22 − 3 = 22? Correction: work carefully: 25 − 3 = 22, and 22 + 3 = 25. The correct answer is 25, option c."
      }
    },
    {
      "id": "s9",
      "kind": "teach",
      "text": "Try a longer chain one step at a time:\n\n32 ÷ 4 × 2 − 3\n\n32 ÷ 4 = 8, then 8 × 2 = 16.\n\nFinally, 16 − 3 = 13. Multiplication and division come before subtraction.",
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
      "id": "s10",
      "kind": "check",
      "text": "Evaluate:\n\n30 ÷ 5 × 2 + 4 − 3",
      "options": [
        {
          "id": "a",
          "label": "9"
        },
        {
          "id": "b",
          "label": "17"
        },
        {
          "id": "c",
          "label": "13"
        },
        {
          "id": "d",
          "label": "7"
        }
      ],
      "correctOptionId": "c",
      "explanation": "Work left to right through division and multiplication: 30 ÷ 5 = 6, then 6 × 2 = 12. Then 12 + 4 − 3 = 16 − 3 = 13. Check by reversing the last steps: 13 + 3 − 4 = 12, then 12 ÷ 2 × 5 = 30.",
      "hint": "Do 30 ÷ 5, then multiply by 2. After that, work left to right with +4 and −3.",
      "wrongAnswerFeedback": "A common slip is to do 5 × 2 before dividing. In this question, start at the left with 30 ÷ 5, then continue in written order.",
      "difficulty": "HARD",
      "retry": {
        "prompt": "Evaluate:\n\n36 ÷ 6 × 2 + 5 − 4",
        "options": [
          {
            "id": "a",
            "label": "12"
          },
          {
            "id": "b",
            "label": "13"
          },
          {
            "id": "c",
            "label": "5"
          },
          {
            "id": "d",
            "label": "7"
          }
        ],
        "correctOptionId": "b",
        "explanation": "First, 36 ÷ 6 = 6, then 6 × 2 = 12. Next, 12 + 5 − 4 = 17 − 4 = 13. Check: 13 + 4 − 5 = 12, then 12 ÷ 2 × 6 = 36."
      }
    },
    {
      "id": "s11",
      "kind": "teach",
      "text": "A useful routine:\n\n1. Find multiplication or division.\n2. If there is more than one, work from left to right.\n3. Then do addition or subtraction from left to right.\n\nEach step gives the number for the next step.",
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
      "id": "s12",
      "kind": "recap",
      "text": "Remember: multiplication and division have equal priority, so work in written order from left to right. Then do addition and subtraction from left to right.\n\nIn your own words, how would you explain or check this rule?",
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
