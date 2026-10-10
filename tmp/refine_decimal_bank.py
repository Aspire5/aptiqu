import json,re
from pathlib import Path
p=Path(r'C:\Users\Shagun\Desktop\aptiqu\books\SubTopics\SBT-RSA-03-Decimal_Fractions\Extracted Question Json\decimal_fractions_topic_3_question_bank_206.json')
a=json.loads(p.read_text(encoding='utf-8'))
by={int(x['externalQuestionKey'][-3:]):x for x in a}
def put(q,prompt=None,options=None,explanation=None,sub=None,cat=None):
 x=by[q]
 if prompt is not None:x['prompt']=prompt
 if options is not None:x['options']=[{'id':chr(65+i),'text':t} for i,t in enumerate(options)]
 if explanation is not None:x['explanation']=explanation
 if sub:x['externalSubtopicKey']=sub
 if cat:x['pattern']=cat
 if q in [7,43,136,143,144,145,193,194,195]:
  x['externalSubtopicKey']='df-06-decimal-approximation-rounding'
 if q==44:x['externalSubtopicKey']='df-07-decimal-applications-measurement'
 if q==126:x['externalSubtopicKey']='df-04-decimal-multiplication-division';x['pattern']='DECIMAL_OPERATIONS'
 if q in [134,135,185,186,187,189,191,196,201,202,203,204,205,206]:
  x['externalSubtopicKey']='df-09-integrated-decimal-fractions-practice'
 if q in [146,148,150,151,184]:
  x['externalSubtopicKey']='df-08-decimal-identities-shortcuts';x['pattern']='DECIMAL_IDENTITIES_SHORTCUTS'
 if q==182:x['externalSubtopicKey']='df-01-decimal-place-value-conversion';x['pattern']='PLACE_VALUE_CONVERSION'
 if q==200:x['externalSubtopicKey']='df-02-comparing-ordering-fractions';x['pattern']='FRACTION_COMPARISON_ORDERING'
 if q==7:
  x['prompt']='Express 1999/2111 as a decimal, choosing the closest listed value.'
  x['explanation']='Divide 1999 by 2111. The quotient is approximately 0.94647, so to three decimal places it is 0.946 (option C). The decimal is recurring; the listed value is a rounded display, not an exact equality.'
 if q==6:
  x['prompt']='If 47.2506 = 4A + 7/B + 2C + 5/D + 6E, find 5A + 3B + 6C + D + 3E.'
  x['explanation']='Match each term to the place value it contributes in 47.2506: A = 10, B = 1, C = 0.1, D = 100, and E = 0.0001. Then 5A + 3B + 6C + D + 3E = 50 + 3 + 0.6 + 100 + 0.0003 = 153.6003 (option C).'
 if q==1:x['explanation']='42/10,000 has four places after the decimal point, so 42/10,000 = 0.0042 (option A). Check by multiplying 0.0042 by 10,000 to recover 42.'
 if q==2:x['explanation']='101 27/100,000 = 101 + 0.00027 = 101.00027 (option C). The denominator has five zeros, so the fractional part occupies five decimal places.'
 if q==3:x['explanation']='0.36 = 36/100 = 9/25 after dividing numerator and denominator by 4. Their sum is 9 + 25 = 34 (option B).'
 if q==4:x['explanation']='In 0.06945, the 9 is in the thousandths place: 0.009 = 9/1000. Therefore its place value is 9/1000 (option D).'
 if q==5:x['explanation']='One hour is 3600 seconds, so one second is 1/3600 of an hour = 0.0002777… hours. Among the choices, 0.00027 is the intended decimal approximation (option C).'
 if q==8:x['explanation']='Compare by division: 0.1 ÷ 0.01 = 10. Thus 0.1 is 10 times as large as 0.01 (option B).'
 if q==9:
  x['prompt']='Among 3/7, 4/11, 5/9, 6/13 and 7/12, which fraction is the second largest?'
 if q==10:
  x['options']=[
   {'id':'A','text':'2/3, 3/5, 7/9, 9/11, 8/9'},
   {'id':'B','text':'3/5, 2/3, 9/11, 7/9, 8/9'},
   {'id':'C','text':'3/5, 2/3, 7/9, 9/11, 8/9'},
   {'id':'D','text':'8/9, 9/11, 7/9, 2/3, 3/5'},
   {'id':'E','text':'8/9, 9/11, 7/9, 3/5, 2/3'}]
  x['prompt']='Which listed sequence of fractions is in ascending order?'
  x['explanation']='Compare the values: 3/5 = 0.6, 2/3 ≈ 0.667, 7/9 ≈ 0.778, 9/11 ≈ 0.818 and 8/9 ≈ 0.889. They increase in exactly this order, which is option C.'
 if q==11:
  x['options']=[
   {'id':'A','text':'5/9, 7/11, 8/15, 11/17'},
   {'id':'B','text':'5/9, 8/15, 11/17, 7/11'},
   {'id':'C','text':'11/17, 7/11, 8/15, 5/9'},
   {'id':'D','text':'11/17, 7/11, 5/9, 8/15'}]
  x['prompt']='Which sequence lists the fractions in descending order?'
  x['explanation']='Use decimal equivalents to compare: 11/17 ≈ 0.647, 7/11 ≈ 0.636, 5/9 ≈ 0.556, and 8/15 ≈ 0.533. Descending order is 11/17, 7/11, 5/9, 8/15 (option D).'
 if q==16:
  x['options']=[{'id':'A','text':'11/14, 16/19, 19/21'},{'id':'B','text':'16/19, 11/14, 19/21'},{'id':'C','text':'16/19, 19/21, 11/14'},{'id':'D','text':'19/21, 11/14, 16/19'}]
 if q==21:
  x['options']=[{'id':'A','text':'2/−3, 5/−8, −7/10'},{'id':'B','text':'5/−8, −7/10, 2/−3'},{'id':'C','text':'−7/10, 5/−8, 2/−3'},{'id':'D','text':'−7/10, 2/−3, 5/−8'}]
 if q==25:
  x['options']=[{'id':'A','text':'117/300, 287/400'},{'id':'B','text':'95/300, 301/400'},{'id':'C','text':'99/300, 301/400'},{'id':'D','text':'97/300, 299/500'}]
 if q==26:
  x['options']=[{'id':'A','text':'4/25, 9/50, 17/100'},{'id':'B','text':'4/25, 17/100, 167/1000'},{'id':'C','text':'4/25, 9/50, 167/1000'},{'id':'D','text':'9/50, 17/100, 167/1000'}]
 if q==41:
  x['prompt']='Which one of the following equalities is wrong?'
  x['options']=[{'id':'A','text':'9/4 + 1.75 = 4'},{'id':'B','text':'9/5 + 2.2 = 4'},{'id':'C','text':'6/5 + 2.8 = 4'},{'id':'D','text':'3/2 + 1.5 = 4'}]
  x['explanation']='Evaluate each sum: 9/4+1.75=2.25+1.75=4; 9/5+2.2=1.8+2.2=4; 6/5+2.8=1.2+2.8=4; but 3/2+1.5=1.5+1.5=3. Thus D is the incorrect equality.'
 if q in [46,47,48,49,50]:
  x['prompt']=x['prompt'].replace('10 6','10^6').replace('10 7','10^7').replace('10 8','10^8').replace('10 9','10^9').replace('10– 5','10^-5').replace('10– 6','10^-6').replace('10 k','10^k').replace('107','10^7')
 if q==28:x['explanation']='Add in aligned decimal columns: 636.66 + 366.36 = 1003.02, and 1003.02 + 363.33 = 1366.35. This value is not among options A–D, so choose “None of these” (option E).'
 if q==29:x['explanation']='Align the decimal places and add: 24.424 + 5.656 = 30.080; adding 1.131 gives 31.211, and adding 0.089 gives 31.300 = 31.3 (option B).'
 if q==31:x['explanation']='Group by place value: 444 + 44.04 + 4 + 4.44 + 0.4 = 496.88. This matches option C.'
 if q==32:x['explanation']='Add the three terms: 999.99 + 99.99 = 1099.98, and 1099.98 + 9.99 = 1109.97. Since this is not listed, choose “None of these” (option E).'
 if q==34:x['explanation']='Write 48.95 as 48.950, then subtract 32.006 by place value: 48.950 − 32.006 = 16.944 (option D).'
 if q==43:x['externalSubtopicKey']='df-06-decimal-approximation-rounding';x['pattern']='DECIMAL_APPROXIMATION_ESTIMATION'
 if q==44:
  x['explanation']='One hundredth of a centimetre is 0.01 cm. Since 1 km = 100,000 cm, 0.01/100,000 = 0.0000001 km (option A).'
 if q==43:
  x['explanation']='Evaluate the magnitudes: (0.09)^2 = 0.0081; 0.09 = 0.09; (1−0.9)^2 = 0.01; and 1−(0.9)^2 = 0.19. The smallest distance from zero is 0.0081, option A.'
 if q==46:x['explanation']='Multiplying by 10^6 moves the decimal point six places right: 3.14×10^6 = 3,140,000, which is option C.'
 if q==47:x['explanation']='Place one nonzero digit before the decimal point: 518,000,000 = 5.18×10^8. The coefficient is in the normalized range [1,10), so option C.'
 if q==48:x['explanation']='Move the decimal six places right to get 6.723; compensate with 10^-6. Thus 0.000006723 = 6.723×10^-6, option C.'
 if q==50:x['explanation']='The first three factors multiply to 10^-6, and 10^-6×10^7=10. Therefore option C.'
 if q==126:x['explanation']='Each numerator/denominator pair has a factor-of-ten scale change: 965.4−896.3 = 10(96.54−89.63), while 9.654+8.963 = (96.54+89.63)/10. The ratio therefore scales by 1/100, giving 10⁻² (option A).'
 if q==126:x['prompt']='((96.54−89.63)/(96.54+89.63)) ÷ ((965.4−896.3)/(9.654+8.963)) = ?'
 if q==136:x['externalSubtopicKey']='df-06-decimal-approximation-rounding';x['pattern']='DECIMAL_APPROXIMATION_ESTIMATION'
 if q==136:
  x['prompt']='((0.1667×0.8333×0.3333)/(0.2222×0.6667×0.1250)) is approximately equal to what?'
  x['explanation']='Use nearby simple fractions: 0.1667≈1/6, 0.8333≈5/6, 0.3333≈1/3, 0.2222≈2/9, 0.6667≈2/3, and 0.1250=1/8. The ratio is approximately ((1/6)(5/6)(1/3))/((2/9)(2/3)(1/8))=2.5, option D.'
 if q==178:
  x['prompt']='((0.013)^3 + 0.000000343) / ((0.013)^2 − 0.000091 + 0.000049) = ?'
  x['explanation']='Since 0.000000343=(0.007)^3 and the denominator is (0.013)^2−(0.013)(0.007)+(0.007)^2, apply (a^3+b^3)/(a^2−ab+b^2)=a+b. The value is 0.013+0.007=0.020 (option B).'
 if q==179:
  x['prompt']='((2.3)^3 − (0.3)^3) / ((2.3)^2 + 0.69 + 0.09) = ?'
  x['explanation']='The denominator is a^2+ab+b^2 for a=2.3 and b=0.3. Using (a^3−b^3)/(a^2+ab+b^2)=a−b gives 2.3−0.3=2 (option C).'
 if q==180:
  x['prompt']='((0.06)^2+(0.47)^2+(0.079)^2) / ((0.006)^2+(0.047)^2+(0.0079)^2) = ?'
  x['explanation']='Each denominator term is one tenth of its matching numerator term before squaring. Squaring makes each denominator term 1/100 as large, so the denominator is 1/100 of the numerator and the ratio is 100 (option C).'
 if q==181:
  x['prompt']='((4.53−3.07)^3+(3.07−2.15)^3+(2.15−4.53)^3) / ((4.53−3.07)(3.07−2.15)(2.15−4.53)) = ?'
  x['explanation']='Let a=4.53−3.07, b=3.07−2.15, c=2.15−4.53. Then a+b+c=0. The identity a^3+b^3+c^3=3abc gives a ratio of 3 (option D).'
 if q==182:x['prompt']='What fraction is equivalent to (2/5)%?';x['explanation']='Convert percent to a fraction over 100: (2/5)%=(2/5)/100=2/500=1/250 (option C).'
 if q==183:x['prompt']='Express the recurring decimal 0.393939… as a vulgar fraction.';x['explanation']='Let x=0.393939…; then 100x=39.393939…. Subtract x to get 99x=39, so x=39/99=13/33 in lowest terms (option D).'
 if q==184:
  x['prompt']='((41.99)^2−(18.04)^2) ÷ ? = (13.11)^2−138.99'
  x['explanation']='Round the nearby values to expose the difference-of-squares pattern: ((42)^2−(18)^2)/? ≈ 13^2−139 = 30. Factor the numerator as (42+18)(42−18)=60×24=1440; then 1440/?=30, giving ?=48 (option A).'
 if q==187:
  x['prompt']='2(1.5/5)+2(1/6)−1(3.5/15) = (∛x)/4 + 1(7/30). Find x.'
  x['explanation']='Convert the mixed values to fractions and use a common denominator: the left side simplifies to 11.5/5+13/6−18.5/15=37/30. Subtract 7/30 to obtain (∛x)/4=1, so ∛x=8 and x=512 (option C).'
 if q==193:
  x['prompt']='1599 ÷ 39.99 + (4/5)×2449 − 120.05 = ?'
  x['explanation']='Use nearby convenient values as in the book’s estimation method: 1599/39.99≈1600/40=40; (4/5)×2449≈(4/5)×2450=1960; and 120.05≈120. The result is about 1880, option D.'
 if q==194:
  x['prompt']='1576 ÷ 45.02 + 23.99 × √255 = ?'
  x['explanation']='Use nearby values: 1576/45.02≈1575/45=35 and 23.99×√255≈24×16=384 because √255 is close to 16. The total is about 419, so the nearest listed value is 420 (option B).'
 if q==184:x['explanation']='Apply a²−b²=(a−b)(a+b) to the numerator and the square difference on the right. Simplify the known factors first, then isolate the missing divisor; the printed solution gives 48 (option A).'

for q in by:
 put(q)
# Correct page provenance according to the book's actual two-column page breaks.
ranges=[(1,12,74),(13,26,75),(27,50,76),(51,74,77),(75,98,78),(99,117,79),(118,136,80),(137,157,81),(158,177,82),(178,193,83),(194,206,84)]
for q,x in by.items():
 page=next(p for lo,hi,p in ranges if lo<=q<=hi)
 x['provenance']['pageRange']=f'p. {page}'
# Difficulty should follow actual work: long division/recurring quotient and close-to-zero are not rote place-value.
for q in [7,10,15,21,25,26,27,28,29,31,37,41,45,56,57,59,61,66,68,73,76,77,78,79,80,84,90,91,93,95,96,97,98,107,109,113,114,115,116,122,125,127,128,129,130,131,133,134,135,136,140,141,143,144,145,146,150,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,184,187,193,194,195,197,201,202,203,204,205,206]:
 by[q]['difficulty']='HARD';by[q]['calculationMode']='WRITTEN';by[q]['estimatedTimeSeconds']=90
for q in [1,2,3,4,5,8,13,18,22,23,34,42,44,46,47,48,49,52,53,58,62,69,70,71,72,82,85,86,87,94,99,100,101,102,103,104,105,106,110,111,117,118,119,120,121,123,124,137,138,182,183,192,200]:
 if by[q]['difficulty']!='HARD':by[q]['difficulty']='EASY';by[q]['calculationMode']='MENTAL';by[q]['estimatedTimeSeconds']=30
p.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('refined',len(a),'items')
