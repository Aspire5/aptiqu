const path=require('node:path');
const {loader,users,outsider,matchId}=require('./pvp-test-fixture.cjs');
function readFixture(){
 let now=Date.parse('2026-10-20T12:00:00Z');
 const state={rows:[],active:null,recent:null,friendly:0,users:new Map([...users,outsider].map(id=>[id,true])),seasons:new Map(),history:[],queries:[],transactions:[],fail:false};
 const matches=(r,w)=>(!w.userId||(typeof w.userId==='string'?r.userId===w.userId:r.userId<w.userId.lt))&&(!w.seasonId||(typeof w.seasonId==='string'?r.seasonId===w.seasonId:r.seasonId<w.seasonId.lt))&&(!w.played||r.played>w.played.gt)&&(!w.finalizedAt||r.finalizedAt!=null)&&(!w.qualifiedAt||r.qualifiedAt!=null)&&(!w.OR||w.OR.some(o=>(typeof o.rating==='object'?r.rating>o.rating.gt:r.rating===o.rating)&&(!o.userId||r.userId<o.userId.lt)));
 const db={
 questionPreparation:{count:async()=>0},
 user:{findUnique:async({where})=>state.users.has(where.id)?{isRegistrationComplete:state.users.get(where.id)}:null},
 rankedSeason:{findUnique:async({where})=>state.seasons.get(where.id)??null,findUniqueOrThrow:async({where})=>{const row=state.seasons.get(where.id);if(!row)throw new Error('Missing season');return row;}},
 rankedPlayerSeason:{
 findUnique:async({where})=>state.rows.find(r=>r.userId===where.seasonId_userId.userId&&r.seasonId===where.seasonId_userId.seasonId)??null,
 findFirst:async({where})=>state.rows.filter(r=>matches(r,where)).sort((a,b)=>b.seasonId.localeCompare(a.seasonId))[0]??null,
 findMany:async({where,take})=>state.rows.filter(r=>matches(r,where)).sort((a,b)=>b.seasonId.localeCompare(a.seasonId)).slice(0,take).map(r=>({...r,season:state.seasons.get(r.seasonId)})),
 count:async({where})=>state.rows.filter(r=>matches(r,where)).length,
 },
 pvpMatchPlayer:{findFirst:async({where})=>where.match.status==='COMPLETED'?state.recent:state.active,findMany:async()=>state.history,count:async()=>state.history.length},
 friendlyDuelSeat:{count:async()=>state.friendly},
 question:{count:async()=>10},
 $transaction:async(fn,options)=>{if(state.fail)throw new Error('PRIVATE_DATABASE_FAILURE');state.transactions.push(options);return fn(db);},
 $queryRaw:async(query)=>{
 if(Array.isArray(query))return[{now:new Date(now)}];state.queries.push(query);
 const id=query.values[0],final=query.sql.includes('p.final_position IS NOT NULL'),numbers=query.values.filter(v=>typeof v==='number'),limit=numbers.at(-1),cursor=query.values.find(v=>[...users,outsider].includes(v));
 let rows=state.rows.filter(r=>r.seasonId===id&&(final?r.finalPosition!=null:r.qualifiedAt!=null)).sort((a,b)=>(final?b.finalRating-a.finalRating:b.rating-a.rating)||a.userId.localeCompare(b.userId));
 // An independent array oracle models query output; this does not execute SQL.
 rows=rows.map((r,i)=>({userId:r.userId,rating:final?r.finalRating:r.rating,position:final?r.finalPosition:i+1,firstName:'Learner',lastName:'One',avatarUrl:null,email:'NEVER_EXPOSE'}));
 if(cursor)rows=rows.filter(r=>r.rating<numbers[0]||(r.rating===numbers[0]&&r.userId>cursor));return rows.slice(0,limit);
 }};
 const load=loader({'../../../config/prisma':{prisma:db},'../../config/prisma':{prisma:db},'../../social/friends.service':{lockUsers:async()=>{}},'../../ai/services/pvp-set-generation.service':{pvpSetGenerationService:{}}});
 const {RANKED_POLICY,digest}=load(path.join(__dirname,'../ranked/ranked-config.ts'));
 const {seasonBounds}=load(path.join(__dirname,'../ranked/ranked-season-time.ts'));
 const policy={id:'ranked-v1',config:RANKED_POLICY,configHash:digest(RANKED_POLICY),approvedAt:new Date(now)};
 function season(id='2026-10',extra={}){const value={...seasonBounds(id),policyId:policy.id,policy,settlementState:'OPEN',eligibleCount:null,finalizedAt:null,...extra};state.seasons.set(id,value);return value;}
 function row(userId=users[0],extra={}){const value={seasonId:'2026-10',userId,seedRating:1200,rating:1500,peakRating:1500,qualifiedPeakRating:1500,careerRatedBefore:20,played:3,wins:3,losses:0,draws:0,placementsRequired:3,qualifiedAt:new Date(now),version:3,finalizedAt:null,finalPosition:null,finalRating:null,finalPeakRating:null,finalLeague:null,...extra};state.rows.push(value);return value;}
 season();const runtime={reads:true,skillMatchmaking:true};
 const {RankedQueryService}=load(path.join(__dirname,'../ranked/ranked-query.service.ts'));
 const {RankedReadCache}=load(path.join(__dirname,'../ranked/ranked-cache.ts'));
 const {RankedCursor}=load(path.join(__dirname,'../ranked/ranked-cursor.ts'));
 const cache=new RankedReadCache(()=>now,8),service=new RankedQueryService(db,()=>runtime,cache,new RankedCursor(()=>'a'.repeat(48)));
 return{state,db,load,service,row,season,runtime,cache,policy,setTime:value=>{now=value;},now:()=>now,users,outsider,matchId};
}
module.exports={readFixture};
