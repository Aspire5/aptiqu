from pathlib import Path
import json, math, re
ROOT=Path('books/SubTopics/SBT-RSA-14-Partnership'); SRC='R. S. Aggarwal, Quantitative Aptitude, Chapter 14: Partnership (printed pp. 476–492).'
SPECS={
'ps-01-partnership-capital-time-model':('Capital and time jointly determine the weight of an investment.','The weight is capital × months invested. Equal durations cancel, leaving the simple capital ratio; unequal durations require the full product.','A invests ₹40,000 for 12 months and B ₹60,000 for 8 months. Their weights are both ₹480,000-months, so the profit ratio is 1:1.','A partner joining later has fewer months; a partner withdrawing earlier contributes only through the withdrawal date.','Check every investment period against the business timeline and convert years to months before comparing.','Profit allocation follows contribution over time, not the amount deposited at a single snapshot.','Keep capital and time visible as separate columns before multiplying.'),
'ps-02-equal-time-capital-ratios-and-shares':('When partners invest for the same length of time, capital alone determines their relative shares.','If all durations equal t, then C₁t:C₂t simplifies to C₁:C₂; the common time factor cancels.','Capitals ₹45,000 and ₹70,000 reduce to 9:14. Out of ₹46,000 profit, one part is ₹2,000, so the second partner gets ₹28,000.','Do not multiply by a duration twice when it is equal for everyone; do not divide by only one partner’s capital.','The ratio parts must sum to the total profit, and each calculated share must add back to that total.','Capital ratios can be encoded as fractions, percentages, sums, or differences; translate those conditions before allocation.','Reduce the capital ratio once, then use total parts to find the amount per part.'),
'ps-03-capital-time-weighted-shares':('For unequal investment periods, compare the capital-time products rather than the deposits alone.','For partner i, use Cᵢtᵢ. A common currency or common time unit is required; a common multiplier may be removed after all products are formed.','A invests ₹38,000 for 12 months; B invests ₹55,000 for 7 months. Their weights are 456,000 and 385,000, so the ratio is 456:385.','Do not compare capital amounts alone when durations differ, and do not use the date someone joined as their duration.','The resulting share ratio should match the direction of the capital-time products: a larger product earns the larger share.','If a total profit is given, divide it according to the reduced weighted ratio; if only a ratio is asked, stop before inventing a total.','Write each partner’s amount and months in a table before multiplying.'),
'ps-04-entry-exit-and-investment-duration':('A timeline turns phrases such as “joined after five months” into a precise investment duration.','For a T-month business, joining after x months means investing for T−x months; leaving after x months means investing for x months.','In a 12-month business, A invests all year and B joins after month 4. Their durations are 12 and 8 months, not 4 and 12.','The entry delay and the duration are complementary quantities; confusing them reverses the profit ratio.','Draw month 0 and month T, then mark every entry and exit. Confirm all durations lie between 0 and T.','For equal profit shares, the two capital-time products must be equal; this gives an equation for an unknown joining date.','Label whether x means elapsed time or time invested every time it appears.'),
'ps-05-capital-changes-by-time-segment':('Each addition or withdrawal changes the capital-time weight from that date onward.','Split the timeline at every change. Multiply the capital present in each interval by that interval’s length, then add those interval products for that partner.','A begins with ₹20,000; after 5 months the capital becomes ₹15,000. Over 12 months the weight is 20,000×5+15,000×7=₹205,000-months.','Do not count the original capital for the full year and then add the change as a second full-year investment.','Segment durations must be non-overlapping and sum to the partner’s active period. Check the final capital after each change.','A percentage increase is applied to the stated base, often original capital; write the new amount before building segments.','Use a ledger with start, end, capital during interval, and capital-months.'),
'ps-06-solving-unknown-duration-from-profit-ratio':('A stated profit ratio reveals a relationship between capital-time products.','If A:B profit is p:q, then C_A t_A:C_B t_B=p:q. When one duration is unknown, isolate it and distinguish duration from the join delay.','A invests ₹76,000 for 12 months. B invests ₹57,000 and receives half of A’s share. B’s duration solves 76,000×12:57,000×t=2:1, giving t=8 months.','Do not equate the money investments to the profit ratio unless durations match. Keep p paired with A and q paired with B.','Substitute the solved duration back into both weighted contributions and reduce; verify it fits the business term.','If asked when B joined a 12-month business, convert 8 months invested into joining after 4 months.','Set the proportion before cross-multiplying so the ratio order stays visible.'),
'ps-07-solving-unknown-capital-from-shares':('When a partner’s capital is unknown, the known profit ratio determines its missing capital-time weight.','Use C₁t₁:C₂t₂=p:q, then solve for the missing capital. If capital changes during the year, first calculate the partner’s total segmented weight.','A invests ₹20,000 for 12 months. B invests x for 8 months and their profit ratio is 3:2. Then 240,000:8x=3:2, so x=₹20,000.','A share fraction alone does not determine the capital unless the comparison partner’s weight or the total ratio is known.','Check the positive capital and substitute it into the weighted ratio; if other partners exist, include their weights when interpreting a total share.','If the profit share is given as a fraction of total profit, convert it to a ratio against the remaining partners.','Separate the ratio step from the arithmetic step to avoid dropping a duration.'),
'ps-08-allocating-profit-loss-and-known-shares':('Once partnership weights are known, profit or loss is allocated by ratio parts.','For weights r₁:r₂:…:rₙ and total P, partner i receives P·rᵢ/(Σr). The same allocation rule works for a distributable loss when the agreement assigns it proportionally.','For a 5:6:3 capital ratio and ₹2,800 remaining profit, the total is 14 parts; the shares are ₹1,000, ₹1,200, and ₹600.','A ratio gives relative portions, not rupee amounts. The total is needed to find a numerical share.','Add all shares back to P and check that the partner with more weight receives the larger amount.','If one share is known, divide by its ratio fraction to recover P before finding other shares.','Reduce the ratio first to keep the part calculation manageable.'),
'ps-09-reverse-sharing-and-difference-problems':('A difference between two shares can determine the total when their ratio weights are known.','If the two weights are a and b out of total W, their share difference is P·|a−b|/W. Solve for P only after confirming both shares use the same distributable pool.','With weights 456:385, a share gap of ₹1,857 is approximately P×71/841; solving gives P≈₹22,000, subject to the stated rounding.','Do not subtract the ratio terms and call the result a money amount; it is only a number of parts.','Substitute the recovered total and compute both shares; their difference should reproduce the given amount.','A difference between one partner’s capital and another’s is a separate condition and must not be confused with a difference in profit shares.','Write each share as a fraction of P before taking their difference.'),
'ps-10-working-partner-management-allowance':('A working partner may receive a management allowance before the remaining profit is divided by investment.','Calculate the allowance from its stated base, subtract it from total profit, divide only the balance by capital-time weights, then add the allowance to the working partner’s share.','On ₹8,800 profit, a 12.5% management allowance is ₹1,100. The ₹7,700 balance is divided 5:6: the working partner’s investment share is ₹3,500, so the final receipt is ₹4,600.','Do not apply the capital ratio to the entire profit and then add the allowance; that counts the allowance twice.','The final receipts must sum to the original profit, and the allowance must equal the agreed percentage.','If remuneration is stated as a fixed amount, subtract that amount rather than applying a percentage.','Keep “management allowance,” “balance,” “investment share,” and “final receipt” as separate lines.'),
'ps-11-mixed-profit-sharing-agreements':('Some agreements divide profit in stages, such as a common equal portion and a remainder based on investment.','Translate the agreement into separate pools. Apply charity or a prior allowance first, split any equal pool, then allocate the remaining pool by capital-time ratio.','For ₹10,000 profit, a 5% charity deduction leaves ₹9,500. If 20% of that balance is shared equally by two partners, each first receives ₹950; allocate the remaining ₹7,600 by the agreed ratio.','Percentages may refer to the original total or to a remaining balance. Follow the exact stated base at each stage.','Check that charity, equal shares, and proportional shares together use the full original profit exactly once.','“Interest on capital” in these questions means a specified portion allocated by capital unless a rate/time calculation is explicitly stated.','Draw a pool-flow diagram before assigning any amounts.'),
'ps-12-rent-and-shared-resource-allocation':('Shared costs are assigned according to the relevant amount of use, not automatically by partnership capital.','A usage weight can be people×time, animals×time, or an equivalent quantity×time. Convert different resource types only when the problem gives a valid equivalence.','A grazes 15 cows for 4 months, giving 60 cow-months; C grazes 18 cows for 6 months, giving 108 cow-months. C’s rent share is 108/60 times A’s.','Do not use capital-time weights in a rent problem unless capital is the stated basis; identify the resource that drives the cost.','If use occurs in different periods, allocate each interval to the people present then; total assigned rent must equal the bill.','For mixed animals, first convert each type to a common feeding equivalent, then multiply by time.','Write the unit of the weight (for example, cow-months) to keep the model meaningful.'),
'ps-13-deriving-capital-ratios-from-conditions':('Word relationships must be converted into a common algebraic scale before profit shares can be found.','Assign one variable to the simplest stated capital, express all partners in terms of it, and reduce the resulting ratio. Apply time weights only after capital ratios are established.','If C=x, B=4x, and 2A=3B, then A=6x and A:B:C=6:4:1. With equal durations, B receives 4 of 11 profit parts.','When a condition says “twice A equals three times B,” do not read it as A:B=2:3; solve the equation first.','Substitute the proposed capitals into every original condition, then check the ratio order.','A fixed difference creates an equation in x; it is not itself a ratio unless another relation determines scale.','Label the variable and write each translated equation before simplifying.'),
'ps-14-multi-stage-partnerships':('Complex partnership questions become manageable when every event is placed on one common timeline.','For each partner, list each capital level and the months it remains active. Sum the segment products, then compare partners’ totals; never compare just one segment.','A ₹30,000 investment for 4 months followed by ₹45,000 for 8 months contributes 30,000×4+45,000×8=₹480,000-months.','Missing a single interval can change the share ratio even when every individual multiplication is correct.','Check that intervals cover the active period without gaps or overlap and that each new capital equals old capital plus/minus the stated change.','For a multi-year partnership, years and months can be used, but convert all partners to the same unit first.','A timeline plus a partner-by-partner ledger is more reliable than mental date arithmetic.'),
'ps-15-integrated-partnership-data-sufficiency':('Capstone problems require choosing the right partnership model, and data-sufficiency questions require testing uniqueness.','For sufficiency, test Statement I alone, Statement II alone, and both together. A statement is enough only if it fixes the requested value uniquely, not merely a ratio or one unknown relation.','If A:B:C=2:4:7 and Nitin’s share (7 parts) is known, Gagan’s 4-part share is fixed. The ratio alone without any total or one share cannot give a rupee amount.','Do not assume an unstated investment duration or total profit. In capstones, write the needed timeline and profit pool before calculating.','For each data condition, ask whether a free scale factor remains; use counterexamples to prove insufficiency.','When multiple statement combinations work, report the exact sufficiency category rather than choosing the first plausible one.','Finish by checking both the numerical result and whether the supplied information really determines it.')}

def fmt(x, money=False):
 if abs(x-round(x))<1e-9:s=str(int(round(x)))
 else:s=f'{x:.2f}'.rstrip('0').rstrip('.')
 return ('₹' if money else '')+s

def ratio(nums):
 g=math.gcd(*[abs(int(x)) for x in nums]);return ':'.join(str(int(x)//g) for x in nums)

def normweights(vals):
 g=math.gcd(*[int(x) for x in vals]);return [int(x)//g for x in vals]

def question(case):
 kind,p,r=case
 def calc(v):
  if kind in ('share','rent'):
   caps,times,total,idx=v;weights=[a*b for a,b in zip(caps,times)];parts=normweights(weights);val=total*parts[idx]/sum(parts)
   names=['A','B','C','D']
   if kind=='share':prompt=f"Partners {', '.join(names[:len(caps)])} invest capitals {', '.join(fmt(x,True) for x in caps)} for {', '.join(str(x) for x in times)} months respectively. Divide the profit of {fmt(total,True)}; find partner {names[idx]}'s share."
   else:prompt=f"Shared rent of {fmt(total,True)} is divided by usage weights {', '.join(str(x) for x in weights)}. Find user {names[idx]}'s share."
   ans=fmt(val,True);exp='Their capital-time weights are '+', '.join(f'{a}×{b}={a*b}' for a,b in zip(caps,times))+f". Reduced weights are {':'.join(map(str,parts))}, totaling {sum(parts)} parts. One part is {fmt(total/sum(parts),True)}; partner {names[idx]} receives {ans}. The other shares sum with this one to the stated total."
   return prompt,ans,exp,'Use capital × months for each partner, then divide by the sum of all weighted parts.',f"Find partner {names[idx]}'s reduced weight out of {sum(parts)} total parts.", 'HARD' if len(caps)>2 or any(x!=times[0] for x in times) else 'MEDIUM'
  if kind=='join':
   T,ca,cb,pa,pb=v;bdur=ca*T*pb/(cb*pa);joined=T-bdur;ans=fmt(joined)
   prompt=f"A invests ₹{ca} for a {T}-month business. B invests ₹{cb} and joins later. If A:B profit shares are {pa}:{pb}, how many months after the start did B join?"
   exp=f"A's capital-time is {ca}×{T}={ca*T}. For ratio {pa}:{pb}, B's required weight is {ca*T*pb/pa:g}; at ₹{cb} per month B's duration is {ca*T*pb/(pa*cb):g} months. Thus B joined after {T}−{bdur:g}={ans} months. Verify by substituting both weights."
   return prompt,ans,exp,'Distinguish B’s months invested from the delay before B joined.',f"First solve B's duration from C_A T : C_B t = {pa}:{pb}; subtract that duration from {T}.",'HARD'
  if kind=='unknowncap':
   ca,ta,tb,pa,pb=v;cb=ca*ta*pb/(tb*pa);ans=fmt(cb,True)
   prompt=f"A invests ₹{ca} for {ta} months; B invests for {tb} months. If their profit shares are {pa}:{pb}, find B's capital."
   exp=f"Set ({ca}×{ta}):(C_B×{tb})={pa}:{pb}. Hence C_B={ca}×{ta}×{pb}/({pa}×{tb})={cb:g}, so B's capital is {ans}. Substitute to confirm the capital-time ratio."
   return prompt,ans,exp,'The profit ratio compares capital-time products, not capital alone.',f"Solve C_B from ({ca}×{ta}):(C_B×{tb})={pa}:{pb}.",'HARD'
  if kind=='segments':
   segs,total,idx=v;weights=[sum(c*t for c,t in person) for person in segs];parts=normweights(weights);val=total*parts[idx]/sum(parts);ans=fmt(val,True);names=['A','B','C','D']
   prompt=f"A, B and C change their capital during a 12-month business. Their capital-month totals are formed from these segments: A {segs[0]}, B {segs[1]}, C {segs[2]}. Divide profit {fmt(total,True)}; find {names[idx]}'s share."
   exp='Compute each partner’s contribution by adding segment products: '+ '; '.join(f"{names[i]}: "+' + '.join(f'{c}×{t}' for c,t in s)+f"={weights[i]}" for i,s in enumerate(segs))+f". Reduced weights are {':'.join(map(str,parts))}; total parts={sum(parts)}. The requested share is {ans}."
   return prompt,ans,exp,'Every capital change starts a new time segment; do not apply one amount to the entire year.',f"Add each capital×duration segment for {names[idx]}, then divide by all partners’ total weight.",'HARD'
  if kind=='diff':
   a,b,gap=v;total=gap*(a+b)/abs(a-b);ans=fmt(total,True)
   prompt=f"Two partners’ capital-time weights are in the ratio {a}:{b}. Their profit shares differ by {fmt(gap,True)}. Find the total profit."
   exp=f"The share difference is |{a}−{b}|={abs(a-b)} parts out of {a+b}. Thus {abs(a-b)}/{a+b} of total profit equals {fmt(gap,True)}. Total={fmt(gap,True)}×{a+b}/{abs(a-b)}={ans}."
   return prompt,ans,exp,'The share gap corresponds to the difference of their ratio parts, not the total number of parts.',f"Set gap/total=|{a}−{b}|/({a}+{b}).",'MEDIUM'
  if kind=='manager':
   total,pct,weights,idx=v;allow=total*pct/100;remaining=total-allow;parts=normweights(weights);val=remaining*parts[idx]/sum(parts)+(allow if idx==0 else 0);ans=fmt(val,True);names=['A','B','C']
   prompt=f"A is the working partner and receives {pct}% of total profit {fmt(total,True)} for management; the balance is divided by capital-time weights {':'.join(map(str,weights))}. Find partner {names[idx]}'s total receipt."
   exp=f"Management allowance={pct}%×{fmt(total,True)}={fmt(allow,True)}; distributable balance={fmt(remaining,True)}. Reduced investment weights are {':'.join(map(str,parts))} ({sum(parts)} parts). Partner {names[idx]}'s investment share is {fmt(remaining*parts[idx]/sum(parts),True)}"+(f"; adding A's allowance gives {ans}." if idx==0 else f", so total receipt is {ans}.")
   return prompt,ans,exp,'Remove the management allowance before allocating the remaining pool; add it back only to A.',f"Calculate {pct}% of total first, then divide the remainder by the stated weights.",'HARD'
  if kind=='mixed':
   total,charity,equalpct,weights,idx=v;after=total*(1-charity/100);equalpool=after*equalpct/100;rem=after-equalpool;parts=normweights(weights);val=equalpool/len(weights)+rem*parts[idx]/sum(parts);ans=fmt(val,True)
   prompt=f"From profit {fmt(total,True)}, {charity}% goes to charity. Of what remains, {equalpct}% is shared equally by {len(weights)} partners; the rest is divided by capital ratio {':'.join(map(str,weights))}. Find partner {['A','B','C'][idx]}'s receipt."
   exp=f"Charity={fmt(total*charity/100,True)}, leaving {fmt(after,True)}. Equal pool={equalpct}% of that={fmt(equalpool,True)}, giving each {fmt(equalpool/len(weights),True)}. Proportional pool={fmt(rem,True)}; partner's part is {parts[idx]}/{sum(parts)}={fmt(rem*parts[idx]/sum(parts),True)}. Total receipt={ans}."
   return prompt,ans,exp,'Respect the sequence and percentage base; here both portions are based on the post-charity balance.',f"Subtract charity first, split the equal pool, then allocate the remaining pool by capital ratio.",'HARD'
  if kind=='derive':
   c,ratioTerms,total,idx=v;parts=normweights(ratioTerms);val=total*parts[idx]/sum(parts);ans=fmt(val,True);names=['A','B','C']
   prompt=f"Capitals satisfy C={c}x, B=4x, and 2A=3B. They invest for equal times and earn {fmt(total,True)}. Find partner {names[idx]}'s share."
   exp=f"From C={c}x and B=4x, while 2A=3B gives A=6x. Thus A:B:C=6:4:{c}; reduced parts are {':'.join(map(str,parts))}. Total parts={sum(parts)}, so {names[idx]}'s share is {ans}."
   return prompt,ans,exp,'Translate each relation into the same variable before forming the capital ratio.',f"Use B=4x and 2A=3B to find A, then append C={c}x.",'MEDIUM'
  if kind=='manual':
   prompt,ans,exp,diag,hint,diff=v;return prompt,ans,exp,diag,hint,diff
  if kind=='ds':
   prompt,ans,exp,diag,hint=v;return prompt,ans,exp,diag,hint,'HARD'
  raise ValueError(kind)
 main=calc(p);retry=calc(r)
 return main,retry
# Source-shaped teaching sequence: 15 nodes build from model to transfer and self-check.
def lessons(scope,key):
 concept,rule,worked,pitfall,check,transfer,ledger=SPECS[key]
 return [
  f"{scope['name']} asks you to decide what determines each partner’s share. {scope['description']} We will build the model from the agreement, calculate a representative case, and test the result against the original conditions.",
  f"Start with the quantity the agreement actually rewards. In ordinary partnership profit sharing, that is the capital made available to the business over time. {concept} Write the partner names and the stated basis before you choose an operation.",
  f"The core model is: each partner’s weight = capital × time invested. This follows by comparing equal units of capital-month: twice the capital for the same duration contributes twice as much, and the same capital held twice as long also contributes twice as much.",
  f"{rule} Keep the capital amount and its time period in separate columns first. Only multiply once both are expressed in compatible units; this makes the origin of every ratio term visible.",
  f"Worked reasoning: {worked} Notice that the ratio comes from relative contribution, not from the order in which partners are named or from who manages the business. Preserve the labels until the final allocation.",
  f"When the total profit is known, add the reduced ratio terms to find total parts. Divide the distributable profit by those parts for one part, then multiply by the requested partner’s parts. Do not treat a ratio term itself as a rupee amount.",
  f"Use the timeline or agreement to identify intervals before doing arithmetic. {ledger} If a partner’s capital changes, record the new amount only from the date it takes effect; if a time factor is common to everyone, cancel it only after forming the ratio.",
  f"A second way to check the model is to rebuild each partner’s contribution independently. {check} If the resulting ratio reverses a known relationship—for example, a larger weighted contribution receiving a smaller share—inspect the partner labels and ratio order.",
  f"Watch for this error: {pitfall} Another frequent slip is to use elapsed time instead of invested time. Mark the start and end of each interval; for a late entrant in a T-month business, invested duration is T minus the delay.",
  f"A useful worked check is to allocate the full pool and add the receipts. For partner i, the share is total profit × (i’s weight / all partners’ weights). This fraction must be between 0 and 1 for positive weights, and all partner fractions must sum to 1.",
  f"Translate special wording before calculation. A percentage increase may refer to original capital, a withdrawal may be partial, and an allowance may be removed before investment-based sharing. {transfer} Underline the base of each percentage and state whether the pool is original or remaining profit.",
  f"If an unknown amount or date is requested, set up the relationship before solving. Equate the capital-time products in the stated profit ratio, or write a share as its fraction of total profit. Keep unknowns tied to their partner labels and check that a date remains within the business term.",
  f"If your first answer seems wrong, revisit the model rather than repeating the arithmetic. Ask: did I use the right basis, include every interval, convert all time units, and use the right total pool? Then substitute the candidate into the original data and recompute the ratio.",
  f"For a timed exam, use a compact ledger: partner; capital in each interval; months in that interval; weighted contribution; share fraction. Reduce large products by common factors only after they are formed, and keep exact fractions until the final currency amount.",
  f"Mastery check: explain why the chosen weights represent the agreement, show one intermediate calculation, and verify the final share or sufficiency conclusion. You should now be able to solve the approved scope for {scope['name'].lower()} without relying on a memorized answer pattern."
 ]

BANKS={
'ps-01-partnership-capital-time-model':[
('share',([40000,60000],[12,8],12000,0),([30000,50000],[12,6],12600,1)),
('share',([25000,40000,50000],[12,12,12],23000,1),([30000,45000,75000],[12,12,12],30000,2)),
('share',([45000,60000],[12,9],18000,0),([36000,48000],[12,6],12000,1)),
('share',([20000,24000,30000],[10,10,10],12800,2),([28000,35000,42000],[8,8,8],16800,1)),
('share',([16000,24000,32000],[12,8,6],25200,1),([21000,28000,35000],[10,9,6],18000,2)),
('share',([50000,40000,30000],[6,6,6],18000,0),([60000,45000,30000],[9,9,9],21600,1)),
('share',([42000,56000],[12,9],14000,1),([36000,54000],[10,8],16000,0)),
('share',([24000,36000,48000],[12,8,6],19800,2),([30000,45000,60000],[9,8,6],22500,0))],
'ps-02-equal-time-capital-ratios-and-shares':[
('share',([45000,70000],[12,12],46000,1),([36000,54000],[10,10],27000,0)),
('share',([32000,48000,64000],[12,12,12],28800,1),([25000,40000,65000],[8,8,8],26000,2)),
('share',([42000,56000],[12,12],19600,0),([32000,48000],[9,9],24000,1)),
('share',([27000,81000,72000],[12,12,12],20000,1),([12000,48000,36000],[6,6,6],16000,2)),
('share',([15000,25000,40000],[12,12,12],24000,0),([22000,33000,55000],[12,12,12],33000,1)),
('share',([60000,45000],[12,12],21000,0),([72000,48000],[8,8],24000,1)),
('share',([28000,42000,70000],[12,12,12],28000,2),([36000,60000,84000],[12,12,12],36000,1)),
('share',([25000,40000],[12,12],13000,0),([35000,50000],[12,12],17000,1))],
'ps-03-capital-time-weighted-shares':[
('share',([38000,55000],[12,7],22000,0),([45000,60000],[8,6],24000,1)),
('share',([60000,35000,50000],[12,8,6],30800,1),([42000,54000,36000],[10,7,12],26000,2)),
('share',([25000,40000],[12,9],21000,1),([36000,48000],[8,10],18000,0)),
('share',([32000,48000,60000],[9,6,4],19600,0),([25000,35000,45000],[12,8,6],21000,1)),
('share',([50000,75000],[6,4],15000,0),([40000,60000],[9,6],18000,1)),
('share',([24000,36000,48000],[12,8,6],16800,2),([30000,45000,60000],[10,8,5],20000,1)),
('share',([42000,56000],[10,9],19000,0),([36000,54000],[7,8],17000,1)),
('share',([25000,50000,75000],[12,6,4],22000,1),([28000,42000,56000],[9,8,6],18000,0))],
'ps-04-entry-exit-and-investment-duration':[
('join',(12,76000,57000,2,1),(12,60000,60000,2,1)),('join',(12,80000,40000,3,1),(12,50000,50000,2,1)),('join',(12,60000,90000,2,1),(12,90000,60000,3,1)),('join',(12,50000,50000,3,2),(12,70000,35000,3,2)),
('share',([50000,40000,30000],[12,8,6],22000,1),([60000,45000,30000],[10,8,6],18000,2)),('share',([24000,36000],[12,9],18000,1),([30000,45000],[10,8],16000,0)),('share',([42000,56000,70000],[12,10,6],21000,0),([36000,48000,60000],[9,8,6],24000,2)),('share',([25000,40000],[12,6],14000,0),([32000,48000],[10,5],15000,1))],
'ps-05-capital-changes-by-time-segment':[
('segments',([[(20000,5),(15000,7)],[(20000,5),(16000,7)],[(20000,5),(26000,7)]],69900,0),([[(30000,4),(45000,8)],[(25000,12)],[(40000,6),(50000,6)]],36000,2)),
('segments',([[(10000,6),(15000,6)],[(20000,12)],[(30000,4),(24000,8)]],24000,1),([[(18000,3),(24000,9)],[(30000,5),(20000,7)],[(25000,12)]],28000,0)),
('segments',([[(24000,4),(36000,8)],[(30000,12)],[(18000,6),(27000,6)]],30000,2),([[(15000,5),(22500,7)],[(20000,4),(26000,8)],[(32000,12)]],36000,1)),
('segments',([[(40000,3),(30000,9)],[(25000,12)],[(20000,6),(30000,6)]],25000,0),([[(35000,8),(28000,4)],[(24000,5),(30000,7)],[(26000,12)]],31200,2)),
('segments',([[(50000,4),(75000,8)],[(40000,12)],[(30000,6),(45000,6)]],36000,1),([[(22000,3),(33000,9)],[(28000,6),(21000,6)],[(25000,12)]],24000,0)),
('segments',([[(18000,6),(27000,6)],[(30000,4),(24000,8)],[(36000,12)]],33000,2),([[(25000,12)],[(20000,5),(30000,7)],[(40000,3),(32000,9)]],28000,1)),
('segments',([[(32000,3),(24000,9)],[(36000,12)],[(20000,4),(30000,8)]],30000,0),([[(28000,5),(35000,7)],[(25000,12)],[(30000,6),(36000,6)]],35000,2)),
('segments',([[(45000,6),(30000,6)],[(36000,3),(42000,9)],[(25000,12)]],42000,1),([[(30000,12)],[(22000,4),(33000,8)],[(40000,5),(30000,7)]],40000,0))],
'ps-06-solving-unknown-duration-from-profit-ratio':[
('join',(12,80000,60000,2,1),(12,50000,75000,2,1)),('join',(12,60000,80000,3,2),(12,40000,60000,2,1)),('join',(12,90000,60000,3,1),(12,72000,48000,3,1)),('join',(12,64000,32000,3,1),(12,45000,60000,3,2)),
('share',([24000,30000],[12,8],16800,0),([35000,50000],[10,6],18000,1)),('share',([42000,56000],[9,6],18000,1),([36000,48000],[8,6],21000,0)),('share',([25000,40000,50000],[12,9,6],26000,2),([30000,45000,60000],[10,8,5],19000,1)),('share',([32000,48000],[12,8],20000,1),([40000,60000],[9,6],18000,0))],
'ps-07-solving-unknown-capital-from-shares':[
('unknowncap',(20000,12,8,3,2),(30000,10,6,5,3)),('unknowncap',(36000,10,8,3,2),(24000,12,9,4,3)),('unknowncap',(25000,12,6,5,2),(40000,9,6,4,3)),('unknowncap',(45000,8,12,2,3),(30000,10,8,3,2)),
('share',([24000,36000],[12,8],18000,1),([35000,50000],[9,6],19500,0)),('unknowncap',(32000,9,6,3,2),(28000,12,8,7,3)),('unknowncap',(18000,10,6,2,3),(42000,8,12,5,3)),('share',([30000,45000,60000],[12,8,6],21000,2),([25000,40000,50000],[10,9,6],18000,1))],
'ps-08-allocating-profit-loss-and-known-shares':[
('share',([45000,70000],[12,7],46000,1),([36000,54000,60000],[10,8,6],27000,0)),('share',([36000,54000,90000],[12,12,12],30000,1),([18000,36000,54000],[8,8,8],21600,2)),('share',([42000,56000],[12,8],19600,0),([32000,48000],[9,6],24000,1)),('share',([27000,81000,72000],[12,12,12],20000,1),([12000,48000,36000],[6,6,6],16000,2)),('share',([15000,25000,40000],[12,9,6],24000,0),([22000,33000,55000],[12,8,6],33000,1)),('share',([60000,45000],[12,8],21000,0),([72000,48000],[8,6],24000,1)),('share',([28000,42000,70000],[12,8,6],28000,2),([36000,60000,84000],[12,8,6],36000,1)),('share',([25000,40000],[12,6],13000,0),([35000,50000],[8,6],17000,1))],
'ps-09-reverse-sharing-and-difference-problems':[
('diff',(456,385,1857),(5,3,2000)),('diff',(7,5,800),(9,5,1200)),('diff',(12,7,1500),(11,8,900)),('diff',(9,4,2500),(13,7,1800)),('diff',(8,5,1200),(14,9,1600)),('diff',(15,11,800),(10,7,900)),('diff',(17,12,1250),(16,9,1400)),('diff',(11,6,1500),(19,14,1100))],
'ps-10-working-partner-management-allowance':[
('manager',(880,12.5,[5,6],0),(1200,10,[3,5],0)),('manager',(10000,8,[4,3],1),(15000,10,[5,4],0)),('manager',(18000,5,[3,2,1],0),(12000,12,[2,3,1],1)),('manager',(25000,8,[7,5],0),(20000,10,[4,6],0)),('manager',(32000,6,[5,3,2],2),(24000,8,[3,5,4],1)),('manager',(5600,5,[13,14,10],1),(7400,5,[13,14,10],1)),('manager',(22000,10,[7,5],0),(18000,10,[5,6],1)),('manager',(36000,7.5,[4,3,2],0),(28000,5,[6,5,3],2))],
'ps-11-mixed-profit-sharing-agreements':[
('mixed',(10000,5,20,[5,3],0),(12000,10,25,[2,3],1)),('mixed',(24000,8,30,[3,2,1],1),(18000,5,20,[4,5,3],0)),('mixed',(15000,0,40,[7,5],1),(20000,10,25,[3,4,5],2)),('mixed',(28000,5,15,[5,4,3],0),(32000,8,20,[6,5,4],1)),('mixed',(18000,0,25,[2,3,4],2),(22000,5,30,[7,5,3],0)),('mixed',(42000,5,10,[5,6],1),(36000,10,15,[3,2,4],2)),('mixed',(16500,0,20,[4,3,2],0),(27500,10,25,[5,3,2],1)),('mixed',(30000,5,30,[3,5,4],2),(24000,8,20,[4,3,2],0))],
'ps-12-rent-and-shared-resource-allocation':[
('rent',([24,10,35,21],[3,5,4,3],3250,0),([15,12,18,16],[4,2,6,5],4624,0)),('rent',([15,12,18,16],[4,2,6,5],4624,2),([21,15,15],[3,2,6],6000,1)),('rent',([8,12,14],[8,12,14],578,2),([12,15,9],[5,4,8],840,0)),('rent',([30,25,20],[6,8,10],1800,1),([18,24,30],[5,7,4],2100,2)),('rent',([12,18,20],[10,6,4],2400,0),([25,15,10],[4,8,12],1650,1)),('rent',([16,20,24],[3,5,4],3200,2),([14,21,28],[6,4,3],2700,0)),('rent',([40,30,20],[2,3,4],1900,1),([10,20,30],[12,6,4],2800,2)),('rent',([22,18,16],[5,8,6],2500,0),([28,14,21],[4,7,5],2100,1))],
'ps-13-deriving-capital-ratios-from-conditions':[
('derive',(1,[6,4,1],22000,1),(2,[6,4,2],30000,2)),('derive',(3,[6,4,3],33000,0),(5,[6,4,5],24000,1)),('derive',(2,[6,4,2],18000,2),(1,[6,4,1],21000,0)),('derive',(4,[6,4,4],28000,1),(3,[6,4,3],30000,2)),('derive',(5,[6,4,5],40000,0),(2,[6,4,2],24000,1)),('derive',(3,[6,4,3],27000,1),(4,[6,4,4],36000,0)),('derive',(2,[6,4,2],35000,2),(6,[6,4,6],32000,1)),('derive',(1,[6,4,1],25000,0),(3,[6,4,3],42000,2))],
'ps-14-multi-stage-partnerships':[
('segments',([[(30000,4),(45000,8)],[(25000,6),(35000,6)],[(40000,3),(30000,9)]],48000,0),([[(28000,5),(36000,7)],[(30000,4),(42000,8)],[(24000,12)]],36000,1)),
('segments',([[(50000,6),(40000,6)],[(30000,3),(45000,9)],[(25000,4),(35000,8)]],54000,2),([[(45000,4),(60000,8)],[(38000,5),(30000,7)],[(50000,12)]],60000,0)),
('segments',([[(22000,2),(33000,5),(40000,5)],[(30000,12)],[(25000,4),(35000,4),(45000,4)]],72000,1),([[(28000,3),(42000,4),(50000,5)],[(36000,6),(24000,6)],[(30000,12)]],42000,2)),
('segments',([[(35000,4),(28000,4),(42000,4)],[(40000,8),(30000,4)],[(25000,12)]],60000,0),([[(30000,12)],[(22000,5),(33000,7)],[(38000,4),(48000,8)]],48000,1)),
('segments',([[(40000,3),(50000,5),(45000,4)],[(32000,7),(42000,5)],[(30000,6),(36000,6)]],66000,2),([[(25000,5),(35000,7)],[(40000,4),(30000,8)],[(28000,6),(42000,6)]],52000,0)),
('segments',([[(18000,4),(27000,4),(36000,4)],[(22000,6),(33000,6)],[(30000,12)]],39000,1),([[(40000,12)],[(25000,4),(37500,8)],[(36000,3),(48000,9)]],54000,2)),
('segments',([[(50000,3),(40000,9)],[(25000,4),(35000,8)],[(30000,5),(45000,7)]],75000,0),([[(30000,7),(45000,5)],[(24000,6),(36000,6)],[(40000,4),(50000,8)]],64000,1)),
('segments',([[(24000,5),(36000,7)],[(30000,12)],[(20000,4),(30000,8)]],33000,2),([[(32000,4),(48000,8)],[(40000,5),(30000,7)],[(28000,12)]],42000,0))],
'ps-15-integrated-partnership-data-sufficiency':[
('ds',
 ('Ravi, Gagan, and Nitin share a partnership profit. Is Gagan’s amount known? I: Their investment ratio is 2:4:7. II: Nitin’s profit share is ₹8,750.','Both statements together','I gives only a ratio and no rupee scale. II gives one partner’s share but no relation to Gagan. Together, 7 parts=₹8,750, so Gagan receives 4/7×₹8,750=₹5,000.','A ratio and a known partner share are both needed to establish a rupee amount.','Test each statement alone, then combine them.'),
 ('Three partners share profit. Is Gagan’s amount known? I: Their ratio is 3:5:7. II: Nitin’s share is ₹14,000.','Both statements together','A ratio alone has no rupee scale, and a single share alone gives no ratio to Gagan. Together, 7 parts=₹14,000, so Gagan receives 5 parts=₹10,000.','Relative parts do not set a currency scale by themselves.','Check whether one statement supplies the ratio and the other supplies one share.')),
('ds',
 ('A and B share annual profit ₹23,800. Find A’s share. I: B’s investment is 112.5% more than A’s. II: A invested ₹120,000.','Statement I alone','If A=x, then B=(1+1.125)x=2.125x=17x/8, so A:B=8:17. A receives 8/25×₹23,800=₹7,616. II alone gives no B investment or ratio.','A percent “more than” means the original 100% plus the stated increase.','Translate 112.5% more into 212.5% of A, then use the known profit total.'),
 ('A and B share annual profit ₹30,000. Find A’s share. I: B’s investment is 50% more than A’s. II: A invested ₹60,000.','Statement I alone','I gives A:B=2:3, so A receives 2/5×₹30,000=₹12,000. II alone does not reveal B’s capital.','A relative capital ratio determines the share even without the rupee capital amount.','Convert 50% more into the ratio 2:3 and allocate the profit.')),
('ds',
 ('A and B earned ₹20,000 after one year. Find A’s share. I: A invested ₹50,000. II: B withdrew capital after 8 months.','Neither statement, even together','I supplies A’s capital but no B capital. II gives B’s time but not the amount. Together the capital-time ratio remains unknown, so A’s share cannot be uniquely determined.','The two statements leave B’s capital unspecified.','Ask whether a free capital scale remains after combining both statements.'),
 ('At the end of a two-year partnership, find Neeta’s share of ₹43,600 profit. I: Neeta invested ₹85,000. II: Seeta and Geeta joined after six months with capitals in ratio 3:5. III: Their combined capital was ₹250,000.','All three statements','I supplies Neeta’s capital; II supplies the other partners’ ratio and 18-month duration; III sets their capital scale. Seeta=₹93,750 and Geeta=₹156,250. Weighted ratio=2,040,000:1,687,500:2,812,500=272:225:375. Neeta receives 272/872×₹43,600=₹13,600. Each statement is necessary.','Without I Neeta’s weight is unknown; without II the two partners’ relative weights are unknown; without III their scale is unknown.','Use each statement to find one missing piece, then calculate all three capital-time weights.')),
('ds',
 ('Three equal-time partners invest ₹18,000 total and earn ₹3,600. Find A’s share. I: A=2B. II: B=3C. III: A=6C.','Any two statements','Each pair gives A:B:C=6:3:1. Therefore A receives 6/10×₹3,600=₹2,160; the third relation is redundant.','Check each pair; any two establish the same unique capital ratio.','Translate the statements into equations and compare the three pairings.'),
 ('Three equal-time partners invest ₹24,000 total and earn ₹4,800. Find A’s share. I: A=2B. II: B=2C. III: A=4C.','Any two statements','Each pair gives A:B:C=4:2:1, so A receives 4/7×₹4,800≈₹2,742.86; any two statements establish the ratio.','One relation alone leaves the three-way ratio incomplete.','Test all pairs and then allocate the known profit.')),
('ds',
 ('Find the percentage share of Y in an equal-time partnership. I: X, Y, and Z invest for two years. II: Total profit equals 30% of total capital. III: Y invested as much as X and Z together.','Statement III alone','Statement III gives Y’s capital equal to X+Z, so Y has half the total capital. Equal durations make the profit ratio match capital, so Y receives 50%. I and II do not specify Y’s relative capital.','A statement can determine a percentage share without giving any rupee amounts.','Use Y=X+Z to compare Y with the combined total.'),
 ('Find A’s percentage share in an equal-time partnership. I: A invested 40% of the total capital. II: Total profit was ₹18,000. III: B invested twice as much as C.','Statement I alone','With equal periods, A’s capital fraction is A’s profit fraction: 40%. II gives only the scale and III only compares B with C; neither changes A’s known fraction.','A percentage share asks for a fraction, not a rupee amount.','Check whether the capital fraction is already known.')),
('segments',([[(25000,4),(40000,8)],[(30000,12)],[(20000,6),(30000,6)]],36000,0),([[(20000,3),(35000,9)],[(25000,4),(35000,8)],[(30000,12)]],44600,1)),
('manager',(15000,8,[7,5],0),(20000,5,[4,6],0)),
('manual',
 ('A and B start with capitals in ratio 3:5. After 4 months A increases capital by 50%; after 6 months B withdraws one-fifth of original capital. Year-end profit is ₹34,000. Find B’s share.','₹18,000','Let starting capitals be 3x and 5x. A’s weight=3x×4+4.5x×8=48x. B’s weight=5x×6+4x×6=54x. Ratio=8:9, so B receives 9/17×₹34,000=₹18,000.','The stated increase applies to A’s original capital; B’s reduced amount applies only after month 6.','Build separate interval products, simplify 48:54 to 8:9, then allocate the total.','HARD'),
 ('A and B start with capitals 4:6. After 3 months A increases capital by 50%; after 8 months B withdraws one-third of original capital. Year-end profit is ₹19,500. Find B’s share.','₹9,600','A’s weight=4x×3+6x×9=66x. B’s weight=6x×8+4x×4=64x. Thus A:B=33:32 and B receives 32/65×₹19,500=₹9,600.','Do not apply either changed amount retroactively to the whole year.','Split the year at months 3 and 8 and add each partner’s weighted segments.','HARD'))]

}
def wrongs(answer):
 if answer in {'Statement I alone','Statement II alone','Statement III alone','Either statement alone','Both statements together','Neither statement, even together','Any two statements','All three statements','Insufficient even with all three'}:
  pool=['Statement I alone','Statement II alone','Statement III alone','Either statement alone','Both statements together','Neither statement, even together','Any two statements','All three statements','Insufficient even with all three']
  return [x for x in pool if x!=answer][:3]
 if answer=='Either III alone, or I and II together':return ['All three statements','Statement III alone','Insufficient even with all three']
 if answer=='Statements I and II together':return ['Statement I alone','Statement II alone','All three statements']
 if ':' in answer and '₹' not in answer:
  try:terms=list(map(int,answer.split(':')))
  except ValueError:terms=[]
  if terms:
   options=[]
   for i in range(len(terms)):
    for delta in (1,-1):
     altered=terms.copy();altered[i]=max(1,altered[i]+delta);candidate=':'.join(map(str,altered))
     if candidate!=answer and candidate not in options:options.append(candidate)
   return options[:3]
 m=re.fullmatch(r'(₹)?(-?\d[\d,]*(?:\.\d+)?)(.*)',answer)
 if m:
  prefix=m.group(1) or '';x=float(m.group(2).replace(',',''));suffix=m.group(3)
  out=[]
  for val in (x+100,x-100,x*2,x/2,x+500,x+1000):
   if val<0:continue
   text=(f'{val:,.2f}' if abs(val-round(val))>1e-8 else f'{int(round(val)):,}')
   candidate=prefix+text+suffix
   if candidate!=answer and candidate not in out:out.append(candidate)
  return out[:3]
 return ['None of these','Cannot be determined','Insufficient information']

PRIMARY=['abcdabcd','bcadadcb','cdabcbda','dabcadbc','acbdcadb','bdacdbca','cadbabcd','dbacbcad','badccabd','acbdcadb','bcadadcb','dcabcbad','cabdadbc','adcbcdab','bdacdbca']
RETRY=['badcbadc','cabdcbad','dbacdcab','abcdcbad','bdacdbca','cadbadcb','dbacbcad','acbdcadb','cbadadcb','bdacdbca','cabdcbad','adcbcbda','dbacbcad','bacdadcb','cdabbdac']

def node(nid,kind,text,targets):
 return {'id':nid,'type':kind,'content':{'text':text,'avatarPersona':'TUTOR'},'transitions':[{'targetNodeId':t} for t in targets]}
def positioned(q,pos):
 prompt,answer,explanation,diagnosis,hint,difficulty=q
 options=[answer]+wrongs(answer)
 if len(options)!=4 or len(set(options))!=4:raise ValueError((prompt,options))
 correct=options.pop(0);options.insert(pos,correct)
 opts=[{'id':'abcd'[i],'label':label} for i,label in enumerate(options)]
 return prompt,opts,'abcd'[pos],explanation,diagnosis,hint,difficulty

rows=json.loads((ROOT/'subtopics.json').read_text(encoding='utf8'))
if len(rows)!=15 or set(x['externalSubTopicKey'] for x in rows)!=set(SPECS)==set(BANKS):
 raise ValueError('Approved scopes, teaching profiles, and question banks must match one-to-one.')
for si,scope in enumerate(rows):
 key=scope['externalSubTopicKey'];cases=BANKS[key]
 if len(cases)!=8 or any(pattern.count(char)!=2 for pattern in (PRIMARY[si],RETRY[si]) for char in 'abcd'):
  raise ValueError(f'{key}: expected eight paired practices and balanced answer positions')
 ns={'start':node('start','CONTENT',f"{scope['name']}: {scope['description']} This lesson builds a partnership model, explains each step, works through examples, and offers fresh practice with targeted recovery.",['teach_1'])}
 for j,txt in enumerate(lessons(scope,key),1):
  ns[f'teach_{j}']=node(f'teach_{j}','CONTENT',txt,[f'teach_{j+1}' if j<15 else 'focus_1'])
 for i,case in enumerate(cases,1):
  main,retry=question(case)
  focus=f'focus_{i}';qid=f'q_{i}';rem=f'remedy_{i}';rid=f'retry_{i}';rrem=f'retry_remedy_{i}';nxt=f'focus_{i+1}' if i<8 else 'complete'
  prompt,opts,cid,exp,diag,hint,diff=positioned(main,'abcd'.index(PRIMARY[si][i-1]))
  ns[focus]=node(focus,'CONTENT',f"Model the named partners and the profit pool before calculating. {diag} Keep every capital, duration, and change attached to its partner.",[qid])
  qn=node(qid,'CHOICE',prompt,[nxt,rem]);qn['transitions']=[{'targetNodeId':nxt,'condition':{'field':'isCorrect','operator':'EQUALS','value':True}},{'targetNodeId':rem,'condition':{'field':'isCorrect','operator':'EQUALS','value':False}}]
  qn['input']={'type':'CHOICE','options':opts};qn['questionReference']={'mode':'INLINE','inlineData':{'questionType':'PRACTICE','prompt':prompt,'options':opts,'correctOptionId':cid,'difficulty':diff,'xp':{'EASY':10,'MEDIUM':15,'HARD':20}[diff],'hints':[diag,hint],'explanation':exp}};ns[qid]=qn
  ns[rem]=node(rem,'CONTENT',f"Let’s repair the specific idea: {diag} {hint} Rebuild the capital-time weights or profit pools with partner labels. Before retrying, substitute your setup into the original conditions and make sure the weights and total use compatible units.",[rid])
  rp,ropts,rcid,rexp,rdiag,rhint,rdiff=positioned(retry,'abcd'.index(RETRY[si][i-1]))
  rn=node(rid,'CHOICE',rp,[nxt,rrem]);rn['transitions']=[{'targetNodeId':nxt,'condition':{'field':'isCorrect','operator':'EQUALS','value':True}},{'targetNodeId':rrem,'condition':{'field':'isCorrect','operator':'EQUALS','value':False}}]
  rn['input']={'type':'CHOICE','options':ropts};rn['questionReference']={'mode':'INLINE','inlineData':{'questionType':'PRACTICE','prompt':rp,'options':ropts,'correctOptionId':rcid,'difficulty':rdiff,'xp':{'EASY':10,'MEDIUM':15,'HARD':20}[rdiff],'hints':[rdiag,rhint],'explanation':rexp}};ns[rid]=rn
  ns[rrem]=node(rrem,'CONTENT',f"Revisit the step that caused difficulty: {rdiag} For this attempt, {rexp} Verify that the result fits the stated timeline and that all shares come from the correct profit pool.",[nxt])
 ns['complete']=node('complete','CONTENT',f"You have completed {scope['name']}. Explain the model you used, state one assumption it requires, and verify that the resulting ratio or allocation satisfies the original partnership agreement.",[])
 doc={'schemaVersion':'1.0','scriptId':key,'version':1,'sourceType':'MANUAL','entryNodeId':'start','metadata':{'title':scope['name'],'description':scope['description'],'teachingApproach':'Develop the capital-time model step by step; use timelines and segment ledgers; show intermediate calculations, unit and share checks, and topic-specific remedial feedback. Practice uses fresh values aligned to the approved scope.','targetDurationMinutes':45,'sourceScope':SRC+' Approved scope: '+scope['script_scope']},'nodes':ns}
 out=ROOT/'Scripts'/f'{key}.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(f'Generated {len(rows)} scripts with 15 teaching nodes and 8 paired practice/retry questions each.')



