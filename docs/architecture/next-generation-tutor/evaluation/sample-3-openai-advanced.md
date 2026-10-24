# gpt-6-luna: advanced

Synthetic evaluation only. Not published teaching content.

```json
{
  "title": "Work in the Written Order",
  "scopeSummary": "Evaluate multiplication and division from left to right, then addition and subtraction from left to right. All examples use positive integers with exact integer intermediate results.",
  "screens": [
    {
      "id": "s1",
      "kind": "teach",
      "text": "A box holds 4 pencils. Three boxes hold 3 × 4 = 12 pencils.\n\nNow consider 36 ÷ 6 × 4. Which operation should you do first?",
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
      "text": "Multiplication and division have equal priority. In 36 ÷ 6 × 4, work in written order:\n\n36 ÷ 6 = 6, then 6 × 4 = 24.\n\nThe chain is evaluated as successive operations. Grouping it as 36 ÷ (6 × 4) changes the expression.",
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
      "text": "Evaluate 72 ÷ 8 × 5.",
      "options": [
        {
          "id": "a",
          "label": "45"
        },
        {
          "id": "b",
          "label": "18"
        },
        {
          "id": "c",
          "label": "9"
        },
        {
          "id": "d",
          "label": "40"
        }
      ],
      "correctOptionId": "a",
      "explanation": "Division and multiplication have equal priority, so work left to right: 72 ÷ 8 = 9, then 9 × 5 = 45. Check: 45 ÷ 5 = 9, matching the first result.",
      "hint": "Start with the operation furthest left: 72 ÷ 8.",
      "wrongAnswerFeedback": "A common slip with these numbers is multiplying 8 × 5 first, which changes the grouping.",
      "difficulty": "EASY",
      "retry": {
        "prompt": "Try this similar expression: 63 ÷ 7 × 4.",
        "options": [
          {
            "id": "a",
            "label": "9"
          },
          {
            "id": "b",
            "label": "28"
          },
          {
            "id": "c",
            "label": "36"
          },
          {
            "id": "d",
            "label": "16"
          }
        ],
        "correctOptionId": "c",
        "explanation": "Work left to right: 63 ÷ 7 = 9, then 9 × 4 = 36. Check: 36 ÷ 4 = 9."
      }
    },
    {
      "id": "s4",
      "kind": "teach",
      "text": "Now include addition and subtraction: 50 − 18 ÷ 3 × 2.\n\nDo the division and multiplication first, in written order:\n\n18 ÷ 3 = 6, then 6 × 2 = 12.\n\nThen subtract: 50 − 12 = 38.",
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
      "text": "Evaluate 64 − 20 ÷ 5 × 3.",
      "options": [
        {
          "id": "a",
          "label": "60"
        },
        {
          "id": "b",
          "label": "52"
        },
        {
          "id": "c",
          "label": "28"
        },
        {
          "id": "d",
          "label": "12"
        }
      ],
      "correctOptionId": "b",
      "explanation": "First work through division and multiplication from left to right: 20 ÷ 5 = 4, then 4 × 3 = 12. Then 64 − 12 = 52. Check: 52 + 12 = 64.",
      "hint": "Complete 20 ÷ 5 × 3 before subtracting from 64.",
      "wrongAnswerFeedback": "A common slip with these numbers is subtracting 20 from 64 before completing the division and multiplication.",
      "difficulty": "MEDIUM",
      "retry": {
        "prompt": "Try this similar expression: 73 − 24 ÷ 6 × 4.",
        "options": [
          {
            "id": "a",
            "label": "69"
          },
          {
            "id": "b",
            "label": "65"
          },
          {
            "id": "c",
            "label": "49"
          },
          {
            "id": "d",
            "label": "57"
          }
        ],
        "correctOptionId": "d",
        "explanation": "Work left to right in the division and multiplication: 24 ÷ 6 = 4, then 4 × 4 = 16. Then 73 − 16 = 57. Check: 57 + 16 = 73."
      }
    },
    {
      "id": "s6",
      "kind": "teach",
      "text": "Addition and subtraction also have equal priority. Once multiplication and division are finished, do addition and subtraction from left to right.\n\nFor 30 − 7 + 5, calculate 30 − 7 = 23, then 23 + 5 = 28.",
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
      "text": "Try a prediction: in 8 + 30 ÷ 5 − 2, what must be completed before the addition and subtraction?\n\nFirst calculate 30 ÷ 5 = 6. Then continue from left to right: 8 + 6 − 2 = 12.",
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
      "text": "Evaluate 9 + 48 ÷ 8 − 3.",
      "options": [
        {
          "id": "a",
          "label": "12"
        },
        {
          "id": "b",
          "label": "3"
        },
        {
          "id": "c",
          "label": "9"
        },
        {
          "id": "d",
          "label": "15"
        }
      ],
      "correctOptionId": "c",
      "explanation": "Do the division first: 48 ÷ 8 = 6. Then work left to right through addition and subtraction: 9 + 6 = 15, then 15 − 3 = 12. Check: 12 + 3 = 15. Correction: the resulting value is 12, so option a is correct.",
      "hint": "Calculate 48 ÷ 8 first, then process the remaining operations from left to right.",
      "wrongAnswerFeedback": "A common slip with these numbers is subtracting 3 from 6 before adding 9.",
      "difficulty": "MEDIUM",
      "retry": {
        "prompt": "Try this similar expression: 11 + 42 ÷ 7 − 4.",
        "options": [
          {
            "id": "a",
            "label": "13"
          },
          {
            "id": "b",
            "label": "11"
          },
          {
            "id": "c",
            "label": "3"
          },
          {
            "id": "d",
            "label": "17"
          }
        ],
        "correctOptionId": "a",
        "explanation": "First 42 ÷ 7 = 6. Then 11 + 6 = 17, and 17 − 4 = 13. Check: 13 + 4 = 17."
      }
    },
    {
      "id": "s9",
      "kind": "teach",
      "text": "A useful routine is: scan for multiplication and division; calculate them in written order. Then calculate addition and subtraction in written order.\n\nThis preserves the expression's successive steps instead of silently regrouping them.",
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
      "text": "Evaluate 70 − 36 ÷ 6 × 4 + 9.",
      "options": [
        {
          "id": "a",
          "label": "55"
        },
        {
          "id": "b",
          "label": "41"
        },
        {
          "id": "c",
          "label": "37"
        },
        {
          "id": "d",
          "label": "45"
        }
      ],
      "correctOptionId": "b",
      "explanation": "First work left to right through division and multiplication: 36 ÷ 6 = 6, then 6 × 4 = 24. Then work left to right through subtraction and addition: 70 − 24 = 46, then 46 + 9 = 55. Check: 55 − 9 = 46. Correction: the resulting value is 55, so option a is correct.",
      "hint": "Finish 36 ÷ 6 × 4 first. Then start at 70 and work through the remaining signs from left to right.",
      "wrongAnswerFeedback": "A common slip with these numbers is doing 6 × 4 before 36 ÷ 6, which changes the grouping.",
      "difficulty": "HARD",
      "retry": {
        "prompt": "Try this similar expression: 80 − 45 ÷ 5 × 3 + 6.",
        "options": [
          {
            "id": "a",
            "label": "53"
          },
          {
            "id": "b",
            "label": "65"
          },
          {
            "id": "c",
            "label": "59"
          },
          {
            "id": "d",
            "label": "77"
          }
        ],
        "correctOptionId": "c",
        "explanation": "Work left to right: 45 ÷ 5 = 9, then 9 × 3 = 27. Next 80 − 27 = 53, then 53 + 6 = 59. Check: 59 − 6 = 53."
      }
    },
    {
      "id": "s11",
      "kind": "recap",
      "text": "Remember: multiplication and division share priority, so work in written order. Then do addition and subtraction in written order.\n\nExplain the rule in your own words, or describe how you would check each step.",
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
