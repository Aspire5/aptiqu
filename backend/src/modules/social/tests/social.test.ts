import { LiveCurriculumService } from '../../curriculum/services/live-curriculum.service';
import test from 'node:test';
import assert from 'node:assert/strict';
import { prisma } from '../../../config/prisma';
import { friendPair, lockUsers, publicUser } from '../friends.service';
import { friendlyResult, DuelsService } from '../duels.service';
import { socialTransport } from '../social.transport';
import { resolveDuelScope } from '../duel.selection';
import { XpService } from '../../xp/xp.service';
const A = '00000000-0000-4000-8000-000000000001';
const B = '00000000-0000-4000-8000-000000000002';

test('friendship identity is canonical and self-invitations are rejected', async () => {
  assert.deepEqual(friendPair(A, B), friendPair(B.toUpperCase(), A.toUpperCase()));
  assert.throws(() => friendPair(A, A.toUpperCase()), /yourself/);
  let values: unknown[] = [];
  await lockUsers({ $queryRaw: async (query: any) => { values = query.values; return []; } } as any, [B,A,A]);
  assert.deepEqual(values, [A,B]);
});
test('public profiles exclude email, Google identity, birthday and personal details', () => {
  const profile = publicUser({ id:A, email:'private@example.invalid', googleId:'private',
    profile:{ firstName:'Learner',lastName:'One',dob:'private',religion:'private',country:'private' }, progress:{totalXp:20n} });
  assert.equal(profile.level, 2); assert.equal(profile.name, 'Learner One');
  for(const key of ['email','googleId','dob','religion','country']) assert.equal(key in profile, false);
});
test('only accepted friendships can allocate friendly duel seats', async () => {
  const old = prisma.$transaction; const limit = socialTransport.limit; const oldFind = prisma.friendlyDuel.findUnique;
  const universe = LiveCurriculumService.getAllLiveCurriculumUniverse;
  const qFind=prisma.question.findMany,sFind=prisma.subtopic.findMany,lFind=prisma.lessonScript.findMany;
  let created = false;
  try {
    socialTransport.limit = async () => {};
    LiveCurriculumService.getAllLiveCurriculumUniverse = (async () => [{topicId:'number-system',topicName:'Number System',subtopics:[{id:'scope'}]}]) as any;
    prisma.question.findMany=(async()=>[{subtopicId:'scope',pattern:'ADD',prompt:'Find the sum.',options:['A','B','C','D'].map((id,i)=>({id,text:String(i)})),correctAnswer:'A',explanation:'Add the values.',method:'Addition'}]) as any;
    prisma.subtopic.findMany=(async()=>[{id:'scope',slug:'scope'}]) as any;
    prisma.lessonScript.findMany=(async()=>[]) as any;
    prisma.friendlyDuel.findUnique = (async () => null) as any;
    prisma.$transaction = (async (fn: any) => fn({ $queryRaw:async()=>[],
      friendlyDuel:{findUnique:async()=>null}, pvpMatchPlayer:{count:async()=>0},
      friendship:{findUnique:async()=>({status:'PENDING'})},
      friendlyDuelSeat:{createMany:async()=>{created=true;}} })) as any;
    const service = new DuelsService();
    await assert.rejects(service.invite(A,B,{requestKey:A,subtopicIds:['scope'],smartPicks:false,timerEnabled:false}), /Only friends/);
    prisma.friendlyDuel.findUnique = (async () => ({id:A,requesterId:A,recipientId:B,status:'PENDING'})) as any;
    await assert.rejects(service.respond('00000000-0000-4000-8000-000000000003', A, 'accept'), /not found/);
    await assert.rejects(service.respond(A, A, 'accept'), /not permitted/);
    assert.equal(created, false);
  } finally { prisma.$transaction=old; socialTransport.limit=limit; prisma.friendlyDuel.findUnique=oldFind; LiveCurriculumService.getAllLiveCurriculumUniverse=universe; prisma.question.findMany=qFind;prisma.subtopic.findMany=sFind;prisma.lessonScript.findMany=lFind; }
});
test('duel scope is restricted to pilot topics with usable original references', async () => {
  const oldUniverse=LiveCurriculumService.getAllLiveCurriculumUniverse;
  const oldQuestions=prisma.question.findMany, oldSub=prisma.subtopic.findMany,oldScripts=prisma.lessonScript.findMany;
  try {
    LiveCurriculumService.getAllLiveCurriculumUniverse=(async()=>[{topicId:'number-system',topicName:'Number System',subtopics:[{id:'scope'}]}]) as any;
    prisma.question.findMany=(async(args:any)=>{
      assert.deepEqual(args.where.sourceType.in,['MANUAL','AI_GENERATED']);
      return [{id:A,subtopicId:'scope',pattern:'ADDITION',prompt:'Find the sum of 10 and 5.',options:['A','B','C','D'].map((id,i)=>({id,text:String(i+10)})),correctAnswer:'A',explanation:'Add both numbers.',method:'Addition'}];
    }) as any;
    prisma.subtopic.findMany=(async()=>[{id:'scope',slug:'scope'}]) as any;
    prisma.lessonScript.findMany=(async()=>[]) as any;
    assert.deepEqual(await resolveDuelScope(['scope']),['scope']);
    await assert.rejects(resolveDuelScope(['other']),/unavailable/);
  } finally {LiveCurriculumService.getAllLiveCurriculumUniverse=oldUniverse;prisma.question.findMany=oldQuestions;prisma.subtopic.findMany=oldSub;prisma.lessonScript.findMany=oldScripts;}
});
test('both players must finish before exactly one 10 XP award per player; repeats do not reward', async () => {
  let status='ACTIVE'; let removed=0;
  const sessions=[{id:'s-a',userId:A,status:'COMPLETED'},{id:'s-b',userId:B,status:'ACTIVE'}];
  const tx:any={ friendlyDuel:{findUnique:async()=>({id:'duel',status,sessions}),update:async(args:any)=>{status=args.data.status;}},
    practiceSession:{update:async()=>{}},friendlyDuelSeat:{deleteMany:async()=>{removed++;}} };
  const xp=XpService.getInstance();const original=xp.awardXp;const awards:any[]=[];
  try{
    xp.awardXp=(async(input:any,client:any)=>{assert.equal(client,tx);awards.push(input);return {};}) as any;
    const service=new DuelsService();
    await service.finalizeInTransaction(tx,'duel');assert.equal(awards.length,0);
    sessions[1].status='COMPLETED';await service.finalizeInTransaction(tx,'duel');
    assert.equal(status,'COMPLETED');assert.equal(removed,1);assert.equal(awards.length,2);
    for(const award of awards){assert.equal(award.amount,10);assert.equal(award.sourceType,'FRIENDLY_DUEL');}
    assert.equal(new Set(awards.map(a=>a.idempotencyKey)).size,2);
    await service.finalizeInTransaction(tx,'duel');assert.equal(awards.length,2);
  }finally{xp.awardXp=original;}
});
test('XP awards serialize progress before the idempotency check, preventing lost concurrent increments', async () => {
  let progress=0n;const events=new Map();let tail=Promise.resolve();
  async function award(key:string,amount:number){
    let release=()=>{};
    const tx:any={
      $executeRaw:async()=>{},
      $queryRaw:async()=>{const before=tail;tail=new Promise<void>(r=>{release=r;});await before;return [{user_id:A}];},
      xpEvent:{findUnique:async()=>events.get(key),create:async(args:any)=>{events.set(key,args.data);}},
      userProgress:{findUnique:async()=>({userId:A,totalXp:progress,level:1}),update:async(args:any)=>{progress=args.data.totalXp;}},
      gameStats:{upsert:async()=>{}},
    };
    try{return await XpService.getInstance().awardXp({userId:A,amount,sourceType:'FRIENDLY_DUEL',idempotencyKey:key},tx);}
    finally{release();}
  }
  await Promise.all([award('one',10),award('two',20)]);
  assert.equal(progress,30n);assert.equal(events.size,2);
  await award('one',10);assert.equal(progress,30n);assert.equal(events.size,2);
});

test('an expired invitation releases its seats and cannot be accepted or select questions', async () => {
  const oldFind=prisma.friendlyDuel.findUnique, oldTx=prisma.$transaction;
  let status='PENDING', released=0;
  try {
    prisma.friendlyDuel.findUnique=(async()=>({id:A,requesterId:A,recipientId:B,status})) as any;
    prisma.$transaction=(async(fn:any)=>fn({
      $queryRaw:async(strings:TemplateStringsArray)=>{assert.match(strings.join('?'),/expires_at <= NOW\(\)/);status='EXPIRED';return [{requester_id:A,recipient_id:B}];},
      friendlyDuelSeat:{deleteMany:async()=>{released++;}},practiceSession:{updateMany:async()=>{}},
    })) as any;
    await assert.rejects(new DuelsService().respond(B,A,'accept'),/expired/);
    assert.equal(released,1);assert.equal(status,'EXPIRED');
  } finally { prisma.friendlyDuel.findUnique=oldFind;prisma.$transaction=oldTx; }
});

test('friendly results compare correctness, use time only when enabled, and never fabricate an unfinished winner', () => {
  const scores=[{userId:A,correctCount:7,totalTimeMs:120000},{userId:B,correctCount:7,totalTimeMs:90000}];
  assert.deepEqual(friendlyResult(scores,false,true),{winnerId:null,isTie:true});
  assert.deepEqual(friendlyResult(scores,true,true),{winnerId:B,isTie:false});
  assert.deepEqual(friendlyResult(scores,true,false),{winnerId:null,isTie:false});
  scores[0].correctCount=8;assert.equal(friendlyResult(scores,true,true).winnerId,A);
});
