import json,pathlib,re,ast,math,fractions,collections
R=pathlib.Path(__file__).resolve().parents[2];qs={}
for p in (R/'books/SubTopics').glob('SBT-RSA-0[1-3]*/**/*.json'):
 if 'Scripts' in p.parts or p.name=='subtopics.json':continue
 for q in json.loads(p.read_text()):qs[q['externalQuestionKey']]=q
F=fractions.Fraction
def val(s):
 s=s.replace('−','-').replace('×','*').replace('÷','/').replace('^','**').replace(',','').replace('²','**2').replace('³','**3').strip()
 if not re.fullmatch(r'[0-9\s.+*/()\-]+',s):raise ValueError()
 def ev(n):
  if isinstance(n,ast.Constant) and isinstance(n.value,(int,float)):return F(str(n.value))
  if isinstance(n,ast.UnaryOp):return (-1 if isinstance(n.op,ast.USub) else 1)*ev(n.operand)
  if isinstance(n,ast.BinOp):
   a,b=ev(n.left),ev(n.right)
   if isinstance(n.op,ast.Add):return a+b
   if isinstance(n.op,ast.Sub):return a-b
   if isinstance(n.op,ast.Mult):return a*b
   if isinstance(n.op,ast.Div):return a/b
   if isinstance(n.op,ast.Pow) and b.denominator==1 and abs(b)<5000:return a**int(b)
  raise ValueError()
 return ev(ast.parse(s,mode='eval').body)
def factor(n):
 d=2;out={}
 while d*d<=n:
  while n%d==0:out[d]=out.get(d,0)+1;n//=d
  d+=1
 if n>1:out[n]=out.get(n,0)+1
 return out
def exponent(n,p):
 total=0
 while n:n//=p;total+=n
 return total
checked=[];errors=[]
for k,q in qs.items():
 pat=q['pattern'];prompt=q['prompt'];expected=None;basis=''
 try:
  if pat=='COUNT_PRIME_FACTORS_WITH_MULTIPLICITY':
   terms=re.findall(r'(\d+)\^(\d+)',prompt)
   if terms:expected=sum(sum(factor(int(a)).values())*int(b) for a,b in terms);basis='factor composite bases, multiply exponents, then sum'
   else:
    m=re.search(r'does (\d+) have',prompt)
    if m:expected=sum(factor(int(m[1])).values());basis='independent prime factorisation'
  elif pat in ['UNIT_DIGIT_POWER_CYCLE','UNIT_DIGIT_SUM_OF_POWERS','UNIT_DIGIT_DIFFERENCE_OF_POWERS','UNIT_DIGIT_PRODUCT_POWERS']:
   m=re.search(r'unit digit of (.*?)\?',prompt)
   if m:expected=int(val(m[1]))%10;basis='compute integer power expression modulo 10'
  elif pat=='POWER_REMAINDER_MODULUS':
   m=re.search(r'when (\d+)\^(\d+) is divided by (\d+)',prompt)
   if m:expected=pow(int(m[1]),int(m[2]),int(m[3]));basis='modular exponentiation'
  elif pat=='SIMPLE_REMAINDER':
   m=re.search(r'when (\d+) is divided by (\d+)',prompt)
   if m:expected=int(m[1])%int(m[2]);basis='integer remainder'
  elif pat in ['TRAILING_ZEROS_FACTORIAL','COUNT_FACTORS_OF_5_IN_FACTORIAL']:
   m=re.search(r'(\d+)!',prompt)
   if m:expected=exponent(int(m[1]),5);basis='sum of floor quotients for powers of 5'
  elif pat=='HIGHEST_POWER_PRIME_IN_FACTORIAL':
   m=re.search(r'exponent of (\d+).*?of (\d+)!',prompt)
   if m:expected=exponent(int(m[2]),int(m[1]));basis='sum of floor quotients'
  if expected is None:
   m=re.fullmatch(r'(?:What is|Find|Evaluate|Simplify) (.+?)[?.]',prompt)
   if m:expected=val(m[1]);basis='exact fraction arithmetic'
  if expected is None and ('= ?' in prompt or '=?' in prompt):
   parts=re.split(r'=\s*\?',prompt,1)
   if not re.fullmatch(r'\s*(?:\([^)]*\))?\s*',parts[1]):continue
   candidate=parts[0].strip()
   try:expected=val(candidate);basis='exact arithmetic from the displayed expression'
   except (ValueError,SyntaxError):pass
  if expected is None:continue
  numeric=[]
  for o in q['options']:
   try:
    if val(o['text'])==expected:numeric.append(o['id'])
   except:pass
  answer=q['correctAnswer'];at=next(o['text'] for o in q['options'] if o['id']==answer)
  correct=(len(numeric)==1 and answer==numeric[0]) or (not numeric and re.fullmatch(r'None of these',at,re.I))
  checked.append(k)
  if not correct:errors.append({'key':k,'pattern':pat,'prompt':prompt,'expected':str(expected),'matchingOptions':numeric,'answer':answer,'options':q['options'],'basis':basis})
 except (ValueError,SyntaxError,TypeError,ZeroDivisionError,OverflowError):pass
report={'checkedCount':len(checked),'errors':errors,'scope':'Independent exact-arithmetic, prime-factor, factorial and modular checks for mechanically recognisable saved questions; not a full editorial review of every question.'};(R/'docs/content-recovery/2026-10-23/math-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
