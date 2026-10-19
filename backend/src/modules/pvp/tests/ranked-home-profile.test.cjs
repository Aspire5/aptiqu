const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {loader}=require('./pvp-test-fixture.cjs');
test('Home preserves its existing Ranked result and learning fields when the optional standing section is unavailable',async()=>{
 const legacy={result:'WIN',correct:4,questions:10};
 const db={$transaction:async queries=>Promise.all(queries),$queryRaw:async query=>query==='stats'?[]:query==='last'?[legacy]:[{dailyDates:[]}],lessonSession:{findFirst:async()=>null},achievement:{findMany:async()=>[]}};
 const load=loader({
 '../../config/prisma':{prisma:db},'../pvp/ranked/ranked-query.service':{rankedQueryService:{compact:async()=>({status:'UNAVAILABLE',retryable:true})}},
 '../achievements/achievement.service':{achievementFactsQuery:()=> 'facts',achievementOrder:[],liveAchievementWhere:{},presentAchievements:()=>[]},
 './home.queries':{homeStatsQuery:()=> 'stats',latestHomeMatchQuery:()=> 'last'},
 });
 const {HomeService}=load(path.join(__dirname,'../../home/home.service.ts'));const home=await new HomeService().getHome('owner',new Date('2026-10-20T12:00:00Z'));
 assert.deepEqual(home.ranked,legacy);assert.equal(home.rankedLeague.status,'UNAVAILABLE');assert.equal(home.resume,null);assert.equal(home.timezone,'Asia/Kolkata');
});
test('Profile adds standing independently while preserving identity, XP and daily challenge contracts',async()=>{
 const db={user:{findUnique:async()=>({id:'owner',email:'private@owner.invalid',isRegistrationComplete:true,profile:{firstName:'Learner'}})}};
 const xp={level:2,total:100,progress:0.5},daily={currentStreak:1,highestStreak:3,stats:{coins:5},isDue:false,isCompletedToday:true,canAttempt:false,tierInfo:{tier:1,title:'First',questionCount:5},msUntilMidnight:123,expiresAt:'time'};
 const load=loader({'../../config/prisma':{prisma:db},'../xp/xp.service':{xpService:{getUserProgress:async()=>xp}},'../daily-challenge/daily-challenge.service':{dailyChallengeService:{syncUserStreak:async()=>daily}},'../pvp/ranked/ranked-query.service':{rankedQueryService:{compact:async()=>({status:'DISABLED',retryable:false})}}});
 const {UserService}=load(path.join(__dirname,'../../user/user.service.ts'));const profile=await new UserService().getProfile('owner',false);
 assert.equal(profile.email,'private@owner.invalid');assert.equal(profile.totalXp,100);assert.equal(profile.coins,5);assert.equal(profile.dailyChallenge.isCompletedToday,true);assert.equal(profile.rankedLeague.status,'DISABLED');
});
