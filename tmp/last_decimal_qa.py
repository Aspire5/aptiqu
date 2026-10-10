import json,sys
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8',errors='replace')
p=Path(r'C:\Users\Shagun\Desktop\aptiqu\books\SubTopics\SBT-RSA-03-Decimal_Fractions\Extracted Question Json\decimal_fractions_topic_3_question_bank_206.json')
a=json.loads(p.read_text(encoding='utf-8')); q={int(x['externalQuestionKey'][-3:]):x for x in a}
q[45]['prompt']='54.?3 + 543 + 5.43 = 603.26. What digit replaces the question mark?'
q[45]['explanation']='Substitute each candidate digit into the decimal 54.?3. With 8, the sum is 54.83+543+5.43=603.26, so the answer is option C.'
q[112]['prompt']='3.(87) − 2.(59) = ? (each parenthesized two-digit block repeats).'
q[112]['explanation']='Write the repeating parts as fractions: 3+87/99−(2+59/99)=1+28/99=1.2828…. This matches the keyed option D.'
q[113]['prompt']='3.(36) − 2.(05) + 1.(33) = ? (each parenthesized block repeats).'
q[113]['explanation']='Convert the periods to fractions: 3.(36)=3+36/99, 2.(05)=2+5/99, and 1.(33)=1+33/99. The result is 2.64, option D.'
q[114]['prompt']='0.(09) × 7.(3) = ? (each parenthesized block repeats).'
q[114]['explanation']='0.(09)=9/99=1/11 and 7.(3)=22/3. Their product is 2/3=0.(6), which is option A.'
q[115]['prompt']='0.34(67) + 0.1(3) = ? (the parenthesized digits repeat).'
q[115]['explanation']='Convert the mixed periods: 0.34(67)=(3467−34)/9900 and 0.1(3)=(13−1)/90. Their sum is 4753/9900=0.4801… (option C).'
q[116]['prompt']='8.3(1) + 0.(6) + 0.00(2) = ? (the parenthesized digit repeats).'
q[116]['explanation']='Convert the repeating parts: 8.3(1)=8+14/45, 0.(6)=2/3, and 0.00(2)=1/450. Their sum is 8.98, represented by the keyed recurring-decimal option D.'
q[117]['prompt']='1.75 + 2.78 = ?'
q[117]['explanation']='Add the whole parts and decimal parts: 1+2=3 and 0.75+0.78=1.53. Carry 1 to the whole-number sum: 3+1.53=4.53 (option C).'
q[128]['explanation']='Use 1/[n(n+1)]=1/n−1/(n+1): 1/4+1/20+1/120=30/120+6/120+1/120=37/120=0.308333…, which rounds to 0.3083 (C).'
q[129]['explanation']='Rewrite each term as a power-of-two fraction: 1+1/2+1/8+1/64+1/1024=1681/1024=1.6416015625. To four decimal places this is 1.6416 (C).'
q[130]['explanation']='Each term satisfies 1/[n(n+1)]=1/n−1/(n+1), so the sum telescopes from n=5 through 24 to 1/5−1/25=4/25=0.16 (A).'
q[131]['explanation']='The last digits of successive powers of 1/5 cycle 2, 4, 8, 6 with period 4. Since 2000 is divisible by 4, the final digit is 6 (D).'
q[133]['explanation']='Use the telescoping decomposition shown in the book’s worked solution; consecutive terms cancel, leaving 99/100=0.99. This matches option C.'
q[134]['explanation']='From 1.5x=0.04y, y/x=1.5/0.04=37.5=75/2. Thus (y−x)/(y+x)=(75−2)/(75+2)=73/77 (B).'
q[135]['explanation']='Evaluate the nested terms: 3+1/(3+1/3)=3.3 and 2+1/(2+1/2)=2.4. Then 35.7−3.3−2.4=30 (A).'
q[187]['prompt']='2 + (1.5/5) + 2 + (1/6) − 1 − (3.5/15) = (∛x)/4 + 1 + 7/30. Find x.'
# Difficulty labels reflect operation length and reasoning load; label short identity recognitions as medium.
easy={1,2,3,4,5,8,13,18,22,23,27,28,29,30,32,33,34,38,44,46,47,48,49,50,52,53,54,58,59,62,69,70,71,72,74,75,82,85,86,87,93,94,95,96,99,100,101,102,103,104,105,106,110,111,117,118,119,120,121,123,124,137,138,182,183,192}
medium={6,7,9,10,11,12,14,15,16,17,19,20,21,24,25,26,31,35,36,37,39,40,41,42,43,45,51,55,56,57,60,61,63,64,65,66,67,68,73,76,77,78,79,80,81,83,88,89,90,91,92,97,98,107,108,109,112,113,114,115,116,122,125,126,127,128,129,130,131,132,133,134,135,136,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,184,193,194,195,196,197,198,200,202,205}
hard={84,187,201,203,204,206}
for n,x in q.items():
 x['difficulty']='HARD' if n in hard else ('EASY' if n in easy else 'MEDIUM')
 if x['difficulty']=='HARD':
  x['calculationMode']='WRITTEN';x['estimatedTimeSeconds']=90
 elif x['difficulty']=='EASY':
  x['calculationMode']='MENTAL';x['estimatedTimeSeconds']=30
 else:
  x['calculationMode']='MIXED';x['estimatedTimeSeconds']=60
p.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('final review pass applied')
