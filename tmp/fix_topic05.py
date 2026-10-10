import json
from pathlib import Path
root=Path('books/SubTopics/SBT-RSA-05-Square_Roots_and_Cube_Roots')
sp=root/'subtopics.json'
subs=json.loads(sp.read_text(encoding='utf-8-sig').rstrip('\\n'))
subs[8]['script_scope']=subs[8]['script_scope'].replace("Explain that odd-number cube roots retain the sign of a negative radicand if negatives arise, while the chapter's main examples use positive numbers. ",'')
sp.write_text(json.dumps(subs,ensure_ascii=False,indent=2),encoding='utf-8')
p=root/'Scripts/src-09-cube-roots-perfect-cube-structure.json'
d=json.loads(p.read_text(encoding='utf-8').rstrip('\\n'))
d['metadata']['sourceScope']=d['metadata']['sourceScope'].replace("Explain that odd-number cube roots retain the sign of a negative radicand if negatives arise, while the chapter's main examples use positive numbers. ",'')
d['nodes']['teach_1']['content']['text']='By definition, ∛a is the number whose cube equals a. Since 14³=2,744, ∛2,744=14. Use cubing to check a proposed integer root.'
d['nodes']['remedy_3']['content']['text']='Check which whole number cubed gives the radicand. Use nearby cubes to narrow the candidate, then verify by cubing your answer. Try the fresh value below.'
d['nodes']['retry_remedy_4']['content']['text']='Compare the radicand with nearby cubes, then verify the candidate by cubing it. Carry the groups-of-three rule into the next section.'
p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
