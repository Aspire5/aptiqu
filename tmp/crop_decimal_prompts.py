import json,re,sys
from pathlib import Path
import pdfplumber
sys.stdout.reconfigure(encoding='utf-8',errors='replace')
root=Path(r'C:\Users\Shagun\Desktop\aptiqu')
bank=root/'books'/'SubTopics'/'SBT-RSA-03-Decimal_Fractions'/'Extracted Question Json'/'decimal_fractions_topic_3_question_bank_206.json'
a=json.loads(bank.read_text(encoding='utf-8'))
# (first question, last question, PDF page index, left/right column)
ranges=[(1,7,82,'L'),(8,12,82,'R'),(13,19,83,'L'),(20,26,83,'R'),(27,38,84,'L'),(39,50,84,'R'),(51,62,85,'L'),(63,74,85,'R'),(75,87,86,'L'),(88,97,86,'R'),(98,105,87,'L'),(106,117,87,'R'),(118,128,88,'L'),(129,136,88,'R'),(137,146,89,'L'),(147,157,89,'R'),(158,168,90,'L'),(169,177,90,'R'),(178,185,91,'L'),(186,193,91,'R'),(194,200,92,'L'),(201,206,92,'R')]
placements={}
for lo,hi,pg,side in ranges:
 for q in range(lo,hi+1):placements[q]=(pg,side)
p=next((root/'books').glob('*r-s-aggarwal*.pdf'))
def normal(s):
 s=re.sub(r'\s*\\n\s*','\n',s)
 s=re.sub(r'(?<=\d)\n(?=\d)','/',s)
 s=re.sub(r'\n+',' ',s)
 s=re.sub(r'\s+',' ',s).strip()
 s=s.replace('','(').replace('','(').replace('','(').replace('',')').replace('',')').replace('',')')
 s=s.replace('','...').replace('×','×').replace('÷','÷').replace('–','−')
 # Restore common mathematical superscripts omitted by the PDF text layer.
 s=re.sub(r'(?<=[A-Za-z)])([23])(?=\b)',r'^\1',s)
 s=re.sub(r'10\s+([−-]?\s*\d+|k)\b',lambda m:'10^'+m.group(1).replace(' ','').replace('−','-'),s)
 return s
with pdfplumber.open(p) as doc:
 for q,item in enumerate(a,1):
  pg,side=placements[q];page=doc.pages[pg]
  xl,xr=(25,300) if side=='L' else (300,585)
  words=page.extract_words()
  candidates=[w for w in words if w['text']==f'{q}.' and xl<=w['x0']<xr]
  if not candidates: print('missing coordinate',q);continue
  start=min(candidates,key=lambda w:w['top'])
  # Stop at the next actual objective question in this same column, not at
  # numerator/denominator digits or the adjacent column.
  next_q=q+1
  nxt=None
  if next_q in placements and placements[next_q]==(pg,side):
   z=[w for w in words if w['text']==f'{next_q}.' and xl<=w['x0']<xr and w['top']>start['top']]
   if z:nxt=min(z,key=lambda w:w['top'])
  y1=nxt['top']-1 if nxt else page.height-28
  raw=page.crop((xl,start['top']-1,xr,y1)).extract_text() or ''
  # Drop question number and retain the complete source question, including its
  # displayed options in the existing option records.
  raw=re.sub(r'^\s*'+str(q)+r'\.\s*','',raw)
  raw=re.sub(r'\n\([a-e]\).*','',raw,flags=re.I|re.S)
  prompt=normal(raw)
  if prompt:item['prompt']=prompt
# Restore stems that need semantic grouping after the source's stacked-fraction layout.
manual={
 9:'Among 3/7, 4/11, 5/9, 6/13 and 7/12, which fraction is the second largest?',
 10:'Which of the following sequences of fractions is in ascending order?',
 11:'Which of the following sequences of fractions is in descending order?',
 12:'What is the difference between the largest and smallest fractions among 2/3, 3/4, 4/5 and 5/6?',
 14:'Among 9/31, 3/17, 6/23, 4/11 and 7/25, which is the largest?',
 15:'The fractions 2/5, 3/8, 4/9, 5/13 and 6/11 are arranged in ascending order. Which fraction is fourth?',
 20:'Which number does not lie between 4/5 and 7/13?',
 21:'Arrange −7/10, 5/−8 and 2/−3 in ascending order.',
 22:'Which fraction lies between 2/3 and 3/5?',
 23:'Which fraction is less than 1/5?',
 24:'Which fraction is nearest to 2/5?',
 25:'Which pair of rational numbers lies between 1/3 and 3/4?',
 26:'Which listed set contains three rational numbers between 1/5 and 1/6?',
 41:'Which one of the following equalities is wrong?',
 126:'((96.54−89.63)/(96.54+89.63)) ÷ ((965.4−896.3)/(9.654+8.963)) = ?',
 178:'((0.013)^3 + 0.000000343) / ((0.013)^2 − 0.000091 + 0.000049) = ?',
 179:'((2.3)^3 − (0.3)^3) / ((2.3)^2 + 0.69 + 0.09) = ?',
 180:'((0.06)^2+(0.47)^2+(0.079)^2) / ((0.006)^2+(0.047)^2+(0.0079)^2) = ?',
 181:'((4.53−3.07)^3+(3.07−2.15)^3+(2.15−4.53)^3) / ((4.53−3.07)(3.07−2.15)(2.15−4.53)) = ?',
 182:'What fraction is equivalent to (2/5) percent?',
 183:'Express the recurring decimal 0.393939… as a vulgar fraction.',
 184:'((41.99)^2−(18.04)^2) ÷ ? = (13.11)^2−138.99',
 186:'Solve: 1 1/8 + 1 6/7 + 3 3/5 = ?',
 187:'2 1/5 + 2 1/6 − 1 3/15 = (∛x)/4 + 1 7/30. Find x.',
 189:'Solve: 1 1/2 + 2 2/7 = 3 1/2 + ?',
 191:'Solve: 4 2/3 + 3 1/2 − 1 2/3 = ?',
 193:'1599 ÷ 39.99 + (4/5)×2449 − 120.05 = ?',
 194:'1576 ÷ 45.02 + 23.99 × √255 = ?',
 196:'Solve: 2 1/2 + 1/9 − 2 4/18 = ?',
 200:'Which of 3/2, 7/3, 5/4 and 7/2 is the largest?',
 201:'Find x if x/529 = 329/x.',
 203:'21.5/5 + 21/6 − 13.5/15 = (∛x)/4 + 17/30. Find x.',
 204:'(18/4)^2 × (455/19) ÷ (61/799) = ?',
 206:'Evaluate the nested fraction expression shown in the source.'}
for q,s in manual.items():a[q-1]['prompt']=s
bank.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('cropped prompts',len(a))
