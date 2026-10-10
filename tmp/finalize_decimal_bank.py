import json
from pathlib import Path
p=Path(r'C:\Users\Shagun\Desktop\aptiqu\books\SubTopics\SBT-RSA-03-Decimal_Fractions\Extracted Question Json\decimal_fractions_topic_3_question_bank_206.json')
a=json.loads(p.read_text(encoding='utf-8')); q={int(x['externalQuestionKey'][-3:]):x for x in a}
def item(n,prompt=None,opts=None,expl=None,sub=None,pattern=None):
 x=q[n]
 if prompt is not None:x['prompt']=prompt
 if opts is not None:x['options']=[{'id':chr(65+i),'text':v} for i,v in enumerate(opts)]
 if expl is not None:x['explanation']=expl
 if sub:x['externalSubtopicKey']=sub
 if pattern:x['pattern']=pattern
item(1,'What is 42/10,000 written as a decimal?')
item(2,'Write the mixed fraction 101 27/100,000 as a decimal.')
item(4,'What is the place value of 9 in 0.06945?')
item(6,'If 47.2506 = 4A + 7/B + 2C + 5/D + 6E, find 5A + 3B + 6C + D + 3E.')
item(7,'Express 1999/2111 as a decimal; select the closest listed value.',expl='1999 ÷ 2111 ≈ 0.94647, so to three decimal places the value is 0.946 (option C). The quotient is recurring; the listed decimal is a rounded display, not an exact equality.',sub='df-06-decimal-approximation-rounding',pattern='DECIMAL_APPROXIMATION_ESTIMATION')
item(10,'Which listed sequence of fractions is in ascending order?')
item(11,'Which listed sequence of fractions is in descending order?')
item(16,'Which listed sequence of fractions is in ascending order?')
item(17,'Which of the following fractions is smallest?')
item(19,'Which fraction is less than 7/8 and greater than 1/3?')
item(22,'Which fraction lies between 2/3 and 3/5?')
item(23,'Which fraction is less than 1/5?')
item(24,'Which fraction is nearest to 2/5?')
item(27,expl='Add by place value: 0.3+3+3.33+3.3+3.03+333=345.96. That value is absent from the options, so choose “None of these” (E).')
item(28,expl='Add the aligned decimals: 636.66+366.36+363.33=1366.35. Since 1366.35 is not listed, choose “None of these” (E).')
item(29,expl='24.424+5.656+1.131+0.089=31.300=31.3, option B. Writing the result as 31.300 makes the final place-value addition clear.')
item(31,expl='444+44.04+4+4.44+0.4=496.88, which matches option C.')
item(32,expl='999.99+99.99+9.99=1109.97. Since that value is not among the choices, choose “None of these” (E).')
item(34,expl='Write 48.95 as 48.950, then subtract by aligned place values: 48.950−32.006=16.944 (D).')
item(41,'Which equality is incorrect?',[
 '9/4 + 1.75 = 4','9/5 + 2.2 = 4','6/5 + 2.8 = 4','3/2 + 1.5 = 4'],
 'Evaluate the sums: 9/4+1.75=4; 9/5+2.2=4; 6/5+2.8=4; but 3/2+1.5=3. Therefore D is the incorrect equality.')
item(43,expl='The four values are 0.0081, 0.09, 0.01 and 0.19. The one closest to zero is (0.09)^2=0.0081, option A.',sub='df-06-decimal-approximation-rounding',pattern='DECIMAL_APPROXIMATION_ESTIMATION')
item(44,expl='0.01 cm is 0.01/100,000 km because 1 km=100,000 cm. This equals 0.0000001 km (A).',sub='df-07-decimal-applications-measurement')
item(45,'What digit replaces the question mark in the source equation 54.(?)^3 + 543 + 5.43 = 603.26?')
item(46,'Which number equals 3.14 × 10^6?',expl='Multiplication by 10^6 moves the decimal point six places right: 3.14×10^6=3,140,000 (C).')
item(47,'Write 518,000,000 in normalized scientific notation.',[
 '51.8 × 10^6','51.8 × 10^7','5.18 × 10^8','5.18 × 10^9'],
 'Move the decimal point eight places left to make the coefficient 5.18. Compensate with 10^8: 518,000,000=5.18×10^8 (C).')
item(48,'Write 0.000006723 in normalized scientific notation.',[
 '6723 × 10^-5','67.23 × 10^-7','6.723 × 10^-6','None of these'],
 'Move the decimal point six places right to make 6.723, then use the compensating factor 10^-6. The normalized form is 6.723×10^-6 (C).')
item(49,'If 1.125 × 10^k = 0.001125, find k.',expl='0.001125/1.125=0.001=10^-3, so k=−3 (B).')
item(50,'Evaluate 0.1 × 0.01 × 0.001 × 10^7.',expl='The first three factors equal 10^-6. Then 10^-6×10^7=10, option C.')
item(60,'Express (0.00625 × 23/5) as a vulgar fraction.',[
 '23/80','23/800','23/8000','125/23'])
item(68,'The quotients are (1) 368.39÷17, (2) 170.50÷62 and (3) 875.65÷83. Arrange them in decreasing order.')
item(77,'((0.05/0.25)+(0.25/0.05))^3 = ?',expl='Evaluate the ratios first: 0.05/0.25=0.2 and 0.25/0.05=5. Their sum is 5.2, and 5.2^3=140.608, which rounds to 140.6 (C).')
item(87,'If 144/0.144 = 14.4/x, find x.')
item(96,'A tailor has 37.5 m of cloth and makes 8 pieces from each metre. How many pieces can be made?')
item(98,'A total of ₹6.25 consists of 80 coins, each either 10 paise or 5 paise. How many coins of each kind are there?')
item(99,'Express 0.121212… (repeating block 12) as p/q.',expl='Let x=0.121212…; then 100x=12.121212…. Subtract to get 99x=12, so x=12/99=4/33 (D).',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(100,'Convert 0.125125… (repeating block 125) to a fraction.',expl='For a pure 3-digit repeating block, 0.125125…=125/999. This is option C.',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(101,'Convert 0.474747… to a fraction in lowest terms.',expl='The two-digit period gives 0.474747…=47/99, option D.',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(102,'Express 0.363636… as p/q.',expl='The repeating block 36 gives 0.363636…=36/99=4/11, option A.',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(103,'Which is the least: 0.2, 1÷0.2, 0.2222… or (0.2)^2?',expl='Compute or compare: 0.2, 5, 0.2222…, and 0.04. The least is (0.2)^2=0.04, option D.',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(104,'Convert 1.272727… to p/q.',expl='Separate the whole number: 1.272727…=1+27/99=1+3/11=14/11 (B).',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(105,'Convert 0.4232323… (the block 23 repeats after the initial 4) to a fraction.',[
 '94/99','49/99','491/990','419/990'],
 'For the mixed recurring decimal 0.4(23), subtract the non-repeating prefix: (423−4)/990=419/990 (D).',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(106,'Express 0.29565656… (the block 56 repeats after 29) as a fraction.',[
 '2956/1000','2956/10000','2927/9900','None of these'],
 'Use the mixed-period subtraction: (2956−29)/9900=2927/9900 (C).',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(107,'F=0.84181818… (81 repeats). In lowest terms, by how much does the denominator exceed the numerator?',expl='Convert the mixed recurring decimal: (84181−841)/99000=83340/99000=463/550. The denominator exceeds the numerator by 550−463=87 (D).',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(108,'Find the fraction equal to 4.12222… (2 repeats).',[
 '4 11/90','4 11/99','371/900','None of these'],
 'The repeating tail is 0.02222…=2/90. Thus 4.12222…=4+11/90, option A.',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(109,'Convert 2.8768768… (repeating block 768 after the initial 8) to a mixed fraction.',[
 '2 878/999','2 9/10','2 292/333','2 4394/4995'],
 'For 2.8(768), the fractional part is (8768−8)/9990=8760/9990=292/333. Therefore the mixed number is 2 292/333 (C).',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(110,'Evaluate 0.2222… + 0.3333… + 0.323232… .',expl='Convert the repeating parts to fractions: 2/9+1/3+32/99=87/99=29/33≈0.8788. The closest listed value is 0.87 (D).',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(111,'Evaluate 0.142857142857… ÷ 0.285714285714… .',expl='The repeating blocks are 142857 and 285714; the second is twice the first. Their quotient is 1/2 (A).',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(112,'3.878787… − 2.595959… = ?',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(113,'3.363636… − 2.050505… + 1.333333… = ?',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(114,'0.090909… × 7.3333… = ?',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(115,'0.346767… + 0.133333… = ?',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(116,'8.31111… + 0.6666… + 0.002222… = ?',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(117,'2.757575… + 3.787878… = ?',sub='df-05-recurring-decimals',pattern='RECURRING_DECIMALS')
item(118,'If 547.527/0.0082=x, what is 547527/82?',expl='Multiply numerator and denominator of 547.527/0.0082 by 1000 to get 547527/8.2; scaling the denominator to 82 changes the quotient by a factor of 1/10. Thus the requested value is x/10 (A).')
item(121,'If 1/6.198=0.16134, find 1/0.0006198.')
item(125,'(5.3472×324.23)/(3.489×5.42) is equivalent to which listed expression?')
item(126,'((96.54−89.63)/(96.54+89.63)) ÷ ((965.4−896.3)/(9.654+8.963)) = ?',expl='The second quotient has a numerator ten times the first difference and a denominator one tenth of the first sum, so it is 100 times the first quotient. Their ratio is 1/100=10^-2 (A).')
item(127,'Given 1^3+2^3+…+9^3=2025, estimate (0.11)^3+(0.22)^3+…+(0.99)^3.',expl='Factor 0.11^3 from each term: the sum is 0.11^3(1^3+2^3+…+9^3)=0.001331×2025=2.695275, about 2.695 (C).')
item(128,'Evaluate 1/4 + 1/(4×5) + 1/(4×5×6), correct to four decimal places.')
item(129,'Evaluate [1 + 1/(1×2) + 1/(1×2×4) + 1/(1×2×4×8) + 1/(1×2×4×8×16)] to four decimal places.')
item(130,'Find the sum of the first 20 terms: 1/(5×6)+1/(6×7)+1/(7×8)+…')
item(131,'Find the last digit of (1/5)^2000.')
item(132,'Which of the following expressions equals 1?')
item(133,'Evaluate 3/4 + 5/36 + 7/144 + … + 17/5184 + 19/8100.')
item(134,'If 1.5x=0.04y, find (y−x)/(y+x).')
item(135,'Evaluate 35.7 − (3 + 1/(3+1/3)) − (2 + 1/(2+1/2)).')
item(136,'((0.1667×0.8333×0.3333)/(0.2222×0.6667×0.1250)) is approximately equal to what?')
item(137,'(3.5×1.4)/0.7 = ?')
item(138,'(1.6×3.2)/0.08 = ?')
item(139,'(4.41×0.16)/(2.1×1.6×0.21) is simplified to what?')
item(140,'(.625×.0729×28.9)/(.0081×.025×1.7) = ?')
item(141,'(3.6×0.48×2.50)/(0.12×0.09×0.5) = ?')
item(142,'(0.0203×2.92)/(0.0073×14.5×0.7) = ?')
item(143,'Estimate (3.157×4126×3.198)/(63.972×2835.121) to the closest option.',sub='df-06-decimal-approximation-rounding',pattern='DECIMAL_APPROXIMATION_ESTIMATION')
item(144,'Estimate (489.1375×0.0483×1.956)/(0.0873×92.581×99.749) to the closest option.',sub='df-06-decimal-approximation-rounding',pattern='DECIMAL_APPROXIMATION_ESTIMATION')
item(145,'Estimate (241.6×0.3814×6.842)/(0.4618×38.25×73.65) to the closest option.',sub='df-06-decimal-approximation-rounding',pattern='DECIMAL_APPROXIMATION_ESTIMATION')
item(146,'(0.2×0.2+0.01) × (0.1×0.1+0.02)^−1 = ?')
item(147,'(5×1.6−2×1.4)/1.3 = ?')
item(148,'Evaluate 4.7×13.26+4.7×9.43+4.7×77.31.')
item(149,'(0.2×0.2+0.2×0.02)/0.044 = ?')
item(150,'(8.6×5.3+8.6×4.7)/(4.3×9.7−4.3×8.7) = ?')
item(151,'(.896×.763+.896×.237)/(.7×.064+.7×.936) = ?')
item(152,'(1.25)^3−2.25(1.25)^2+3.75(0.75)^2−(0.75)^3 = ?')
item(153,'(78.95)^2−(43.35)^2 = ?')
item(154,'((75.8)^2−(55.8)^2)/20 = ?')
item(155,'((3.63)^2−(2.37)^2)/(3.63+2.37) = ?')
item(156,'((36.54)^2−(3.46)^2)/? = 40')
item(157,'((67.542)^2−(32.458)^2)/(75.458−40.374) = ?')
item(158,'(1.49×14.9−0.51×5.1)/(14.9−5.1) = ?')
item(159,'(4.2×4.2−1.9×1.9)/(2.3×6.1) = ?')
item(160,'(5.32×56+5.32×44)/((7.66)^2−(2.34)^2) = ?')
item(161,'((0.6)^4−(0.5)^4)/((0.6)^2+(0.5)^2) = ?')
item(162,'(7.5×7.5+37.5+2.5×2.5) = ?')
item(163,'(0.2×0.2+0.02×0.02−0.4×0.02)/0.36 = ?')
item(164,'(99.75)^2−2250.0625 = ?')
item(165,'(55.25)^2−637.5625 = ?')
item(166,'(3.25×3.20−3.20×3.05)/0.064 = ?')
item(167,'(0.98)^3+(0.02)^3+3×0.98×0.02−1 = ?')
item(168,'For which x is 11.98×11.98+11.98×x+0.02×0.02 a perfect square?')
item(169,'((2.697−0.498)^2+(2.697+0.498)^2)/(2.697^2+0.498^2) = ?')
item(170,'((0.137+0.098)^2−(0.137−0.098)^2)/(0.137×0.098) = ?')
item(171,'(0.051^3+0.041^3)/(0.051^2−0.051×0.041+0.041^2) = ?')
item(172,'(5.71^3−2.79^3)/(5.71^2+5.71×2.79+2.79^2) = ?')
item(173,'(0.943^2−0.943×0.057+0.057^2)/(0.943^3+0.057^3) = ?')
item(174,'(0.125+0.027)/(0.5×0.5+0.09−0.15) = ?')
item(175,'(10.3^3+1)/(10.3^2−10.3+1) = ?')
item(176,'[8×(3.75)^3+1]/[(7.5)^2−6.5] = ?')
item(177,'(0.1^3+0.02^3)/(0.2^3+0.04^3) = ?')
item(182,'What fraction is equivalent to (2/5)%?',expl='Convert percent to a fraction over 100: (2/5)%=(2/5)/100=1/250 (option C).')
item(183,'Convert 0.393939… (repeating block 39) to a vulgar fraction.',expl='For a pure two-digit period, 0.393939…=39/99=13/33 (D).')
item(186,'Solve: 1 1/8 + 1 6/7 + 3 3/5 = ?')
item(187,'2 + 1.5/5 + 2 + 1/6 − 1 − 3.5/15 = (∛x)/4 + 1 + 7/30. Find x.',
 expl='The mixed terms give 2.3+2 1/6−1.2333…=3.2333…. Subtract 1 7/30=1.2333… to get (∛x)/4=2; hence ∛x=8 and x=512 (C).')
item(189,'Solve: 1 1/2 + 2 2/7 = 3 1/2 + ?')
item(191,'Solve: 4 2/3 + 3 1/2 − 1 2/3 = ?')
item(193,'1599÷39.99+(4/5)×2449−120.05 = ?',expl='Estimate with convenient nearby values: 1599/39.99≈1600/40=40; (4/5)×2449≈1960; and 120.05≈120. The result is about 1880 (D).')
item(194,'1576÷45.02+23.99×√255 = ?',expl='Approximate 1576/45.02 by 1575/45=35 and √255 by 16, so 23.99×√255≈384. The total is about 419; the nearest choice is 420 (B).')
item(195,'3899÷11.99−2379÷13.97 = ?',expl='Use nearby convenient divisors: 3900/12−2380/14=325−170=155, option C.',sub='df-06-decimal-approximation-rounding',pattern='DECIMAL_APPROXIMATION_ESTIMATION')
item(196,'Solve: 2 2/9 + 4 1/18 − 1 1/2 = ?')
item(197,'(294÷14×5+11)/? = 8^2÷5+1.7')
item(199,'√197×6.99+626.96 = ?')
item(200,'Which of 3/2, 7/3, 5/4 and 7/2 is largest?',[ '7/3','5/4','7/2','3/2'])
item(201,'Find x if x/529=329/x.')
item(202,'A fraction’s numerator is decreased by 25% and its denominator increased by 250%. The resulting fraction is 6/5. Find the original fraction.',[
 '22/5','24/5','27/6','28/5','30/11'])
item(203,'21.5/5+21/6−13.5/15=(∛x)/4+17/30. Find x.')
item(204,'(18/4)^2×(455/19)÷(61/799) = ?')
item(205,'5/9 of a first number is 25% of a second. The second is 1/4 of a third, and the third is 2960. Find 30% of the first number.',[
 '99.9','88.8','77.7','None of these'])
item(206,'7 1/2−[2 1/4+{1 1/4−(1/2)(1 1/2−1/3−1/6)}] = ?')
# Route the chapter's worked series/cyclic-pattern items to the approved integrated scope.
for n in [128,129,130,131,133,134,135]:q[n]['externalSubtopicKey']='df-09-integrated-decimal-fractions-practice'
for x in a:
 if x['externalSubtopicKey']=='df-09-integrated-decimal-fractions-practice':pass
p.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('finalized',len(a),'questions')
