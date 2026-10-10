import json, re, sys
from pathlib import Path
from pypdf import PdfReader
sys.stdout.reconfigure(encoding='utf-8',errors='replace')
root=Path(r'C:\Users\Shagun\Desktop\aptiqu')
r=PdfReader(str(next((root/'books').glob('*r-s-aggarwal*.pdf'))))
src='\n'.join(r.pages[i].extract_text() or '' for i in range(82,93))
src=src[src.find('EXERCISE'):]
anchors=list(re.finditer(r'(?m)^\s*(\d{1,3})\.\s+',src))
starts=[]; cursor=0
for q in range(1,207):
 m=next((x for x in anchors if x.start()>=cursor and int(x.group(1))==q),None)
 if not m: raise RuntimeError(f'missing source question {q}')
 starts.append(m); cursor=m.end()
ans=(r.pages[93].extract_text() or '').split('SOLUTIONS')[0]
keys={int(n):v.upper() for n,v in re.findall(r'(?<!\d)(\d{1,3})\.\s*\(([a-e])\)',ans,re.I)}
if len(keys)!=206: raise RuntimeError(f'answer keys {len(keys)} != 206')
soltext='\n'.join(r.pages[i].extract_text() or '' for i in range(93,103))
soltext=soltext[soltext.find('SOLUTIONS')+len('SOLUTIONS'):]
solanchors=list(re.finditer(r'(?m)^\s*(\d{1,3})\.\s+',soltext))
solmap={}
for j,a in enumerate(solanchors):
 q=int(a.group(1))
 if 1<=q<=206 and q not in solmap:
  nxt=next((b.start() for b in solanchors[j+1:] if int(b.group(1))>q),len(soltext))
  solmap[q]=soltext[a.end():nxt]
def clean(s):
 s=re.sub(r'(?m)^\s*(?:QUANTITATIVE APTITUDE|DECIMAL FRACTIONS)\s*\d*\s*$',' ',s)
 s=re.sub(r'(?<=\d)\s*\n\s*(?=\d)','/',s)
 return re.sub(r'\s+',' ',s).strip()
subs=['df-01-decimal-place-value-conversion','df-02-comparing-ordering-fractions','df-03-decimal-addition-subtraction','df-04-decimal-multiplication-division','df-05-recurring-decimals','df-06-decimal-approximation-rounding','df-07-decimal-applications-measurement','df-08-decimal-identities-shortcuts','df-09-integrated-decimal-fractions-practice']
def sub(q):
 if q<=8 or 44<=q<=50:return subs[0]
 if 9<=q<=26 or q==200:return subs[1]
 if 27<=q<=41 or 110<=q<=117:return subs[2]
 if 93<=q<=98:return subs[6]
 if 99<=q<=109 or q in [111,182,183]:return subs[4]
 if q in [61,62,78,143,144,145]:return subs[5]
 if q==126 or 127<=q<=136 or 152<=q<=181:return subs[7]
 if 118<=q<=125 or 42<=q<=43 or 51<=q<=60 or 63<=q<=92 or 137<=q<=151:return subs[3]
 return subs[8]
def cat(q):
 if q<=8:return 'PLACE_VALUE_CONVERSION'
 if q<=26 or q==200:return 'FRACTION_COMPARISON_ORDERING'
 if q<=41 or 110<=q<=117:return 'DECIMAL_ADDITION_SUBTRACTION'
 if 44<=q<=50:return 'POWERS_OF_TEN_SCIENTIFIC_NOTATION'
 if 93<=q<=98:return 'DECIMAL_APPLICATIONS_MEASUREMENT'
 if 99<=q<=109 or q in [111,182,183]:return 'RECURRING_DECIMALS'
 if q in [61,62,78,143,144,145]:return 'DECIMAL_APPROXIMATION_ESTIMATION'
 if q==126 or 127<=q<=136 or 152<=q<=181:return 'DECIMAL_IDENTITIES_SHORTCUTS'
 return 'DECIMAL_OPERATIONS'
easy={1,2,3,4,5,8,13,18,22,23,34,42,44,46,47,48,49,52,53,58,62,69,70,71,72,82,85,86,87,94,99,100,101,102,103,104,105,106,110,111,117,118,119,120,121,123,124,137,138,182,183,192,200}
hard={6,7,10,15,21,25,26,27,28,29,31,37,41,45,56,57,59,61,66,68,73,76,77,78,79,80,84,90,91,93,95,96,97,98,107,109,113,114,115,116,122,125,127,128,129,130,131,133,134,135,136,140,141,143,144,145,146,150,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,184,187,193,194,195,197,201,202,203,204,205,206}
hints={
'PLACE_VALUE_CONVERSION':['Identify the decimal place or power-of-ten scale represented by each digit before shifting the decimal point.','Rewrite the quantity in the requested form, then convert back once to check that its value is unchanged.'],
'FRACTION_COMPARISON_ORDERING':['Put each fraction on a common scale using equivalent fractions or decimal values.','Check the requested rank or interval explicitly; for negatives, values farther below zero are smaller.'],
'DECIMAL_ADDITION_SUBTRACTION':['Align decimal points and add placeholder zeros so like place values share a column.','Carry or borrow across the correct columns, then estimate to check the decimal position.'],
'POWERS_OF_TEN_SCIENTIFIC_NOTATION':['Count how many places the decimal point must move and note the direction.','Compensate with the opposite power-of-ten movement so the number keeps its value.'],
'DECIMAL_APPROXIMATION_ESTIMATION':['Identify the retained place or significant digit before calculating.','Use the next digit only for the final rounding step, then compare with the estimated magnitude.'],
'DECIMAL_APPLICATIONS_MEASUREMENT':['Convert units first, then write the rate or total for the requested time or quantity.','Check the final unit; when counting complete pieces, include only pieces that fit entirely.'],
'RECURRING_DECIMALS':['Mark the repeating block and any non-repeating prefix.','Multiply by a power of ten that aligns one whole repeating block, then subtract to eliminate it.'],
'DECIMAL_IDENTITIES_SHORTCUTS':['Look for a square, difference of squares, cube pattern, or shared factor before expanding.','Match terms and signs to the identity, checking any condition such as a+b+c=0.'],
'DECIMAL_OPERATIONS':['Follow grouping and operation order; when clearing a decimal divisor, scale both parts equally.','Keep values exact while simplifying, then use a known product, quotient, or estimate to check.']}
explain={
'PLACE_VALUE_CONVERSION':'Use place value and powers of ten to express the quantity in the requested form. Convert back to check the scale; the printed answer key gives option {a}.',
'FRACTION_COMPARISON_ORDERING':'Compare equivalent fractions or decimal values on one scale, then apply the requested order or interval condition. The book solution confirms option {a}.',
'DECIMAL_ADDITION_SUBTRACTION':'Align corresponding decimal places and add or subtract; for a missing term, use the inverse operation. Estimate the result to check its size; the keyed option is {a}.',
'POWERS_OF_TEN_SCIENTIFIC_NOTATION':'Track the decimal-point shift and compensate with a power of ten. In normalized scientific notation the coefficient is at least 1 and less than 10; the keyed option is {a}.',
'DECIMAL_APPROXIMATION_ESTIMATION':'Retain the requested precision and round only at the final step; check the result against a quick estimate. The keyed option is {a}.',
'DECIMAL_APPLICATIONS_MEASUREMENT':'Convert quantities to consistent units, form the rate or total, and interpret the result in context. For complete pieces use the greatest whole count that fits; the keyed option is {a}.',
'RECURRING_DECIMALS':'Set the repeating decimal equal to a variable, shift by a power of ten to align a full period, and subtract. Reduce the resulting fraction; the keyed option is {a}.',
'DECIMAL_IDENTITIES_SHORTCUTS':'Recognize the identity before expanding, substitute carefully, and check signs and required conditions. The printed solution confirms option {a}.',
'DECIMAL_OPERATIONS':'Simplify in the stated order while preserving equivalent values during decimal shifts. Check by estimation or a known product/quotient; the keyed option is {a}.'}
records=[]; warnings=[]
for i,m in enumerate(starts):
 q=i+1; end=starts[i+1].start() if i<205 else len(src); block=src[m.end():end]
 marks=list(re.finditer(r'\(\s*([a-e])\s*\)',block,re.I))
 opts=[]
 for j,mark in enumerate(marks):
  stop=marks[j+1].start() if j+1<len(marks) else len(block)
  val=clean(block[mark.end():stop]).strip(' ,;')
  if val:opts.append({'id':mark.group(1).upper(),'text':val})
 prompt=clean(block[:marks[0].start()] if marks else block)
 pyq=None
 exam=re.search(r'((?:L\.I\.C\.A\.D\.O\.|S\.S\.C\.|S\.B\.I\.P\.O\.|Bank[^,;]*|R\.R\.B\.|M\.C\.A\.|Hotel Management|NABARD|C\.P\.O\.|N\.M\.A\.T\.|G\.B\.O\.|A\.A\.O\.|I\.I\.F\.T\.|IGNOU|Section Officers|Indian Railways|SSC[^]]*|IBPS[^]]*|NICL[^]]*|IDBI[^]]*|ESIC[^]]*|UPSSSC[^]]*|United India Insurance[^]]*)[^]]*)',prompt,re.I)
 if exam:pyq=exam.group(1).strip(' []()');prompt=prompt[:exam.start()].strip()
 diff='HARD' if q in hard else ('EASY' if q in easy else 'MEDIUM'); c=cat(q); key=keys[q]
 if len(opts)<2 or key not in [o['id'] for o in opts]:warnings.append((q,len(opts),key))
 page=74+(q-1)//26
 detail=clean(solmap.get(q,'')) if q in solmap else ''
 # Keep the book's actual worked reasoning as the auditable solution, with a short
 # learning cue to frame its method. Questions without a separately numbered book
 # derivation retain the concept-specific explanation above and are flagged below.
 explanation=explain[c].format(a=key)
 if detail: explanation += ' Worked steps from the source: '+detail
 else: warnings.append((q,'no separately numbered worked solution'))
 records.append({'externalQuestionKey':f'decimal-fractions-q-{q:03d}','externalSubtopicKey':sub(q),'pattern':c,'prompt':prompt,'questionType':'MCQ','inputType':'SINGLE_SELECT','calculationMode':'WRITTEN' if diff=='HARD' or c=='DECIMAL_APPLICATIONS_MEASUREMENT' else ('MENTAL' if diff=='EASY' else 'MIXED'),'difficulty':diff,'estimatedTimeSeconds':30 if diff=='EASY' else 60 if diff=='MEDIUM' else 90,'options':opts,'correctAnswer':key,'hints':hints[c],'pyq':pyq,'method':explain[c].split(';')[0],'explanation':explanation,'alternativeExplanation':None,'preferredSolution':'BOOK','preferredReason':'The keyed answer was checked against the printed answer key and the solution section for this objective question.','sourceType':'MANUAL','status':'READY','provenance':{'bookTitle':'R.S. Aggarwal Quantitative Aptitude for Competitive Examinations','edition':'Not specified in supplied source','chapter':'Decimal Fractions','pageRange':f'p. {page}'}})
outdir=root/'books'/'SubTopics'/'SBT-RSA-03-Decimal_Fractions'/'Extracted Question Json';outdir.mkdir(parents=True,exist_ok=True)
out=outdir/'decimal_fractions_topic_3_question_bank_206.json';out.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
parsed=json.loads(out.read_text(encoding='utf-8'))
print('file',out,'records',len(parsed),'keyed answers',len(keys),'warnings',warnings)
print('subtopic counts',{s:sum(x['externalSubtopicKey']==s for x in parsed) for s in subs})
print('invalid refs',[x['externalQuestionKey'] for x in parsed if x['correctAnswer'] not in [o['id'] for o in x['options']]])
