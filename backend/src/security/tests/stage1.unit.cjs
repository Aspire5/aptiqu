const test=require('node:test'); const assert=require('node:assert/strict'); const path=require('node:path');
const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');
const ENV={JWT_ACCESS_SECRET:'unit-access-key',ADMIN_JWT_SECRET:'unit-admin-key',ADMIN_USERNAME:'admin',JWT_ISSUER:'aptiqu',JWT_AUDIENCE:'aptiqu-mobile',JWT_ACCESS_EXPIRATION:'15m',JWT_REFRESH_EXPIRATION:'2d',ADMIN_JWT_EXPIRATION:'24h'};
const load=loader({crypto:{default:require('node:crypto')},jsonwebtoken:{default:require('jsonwebtoken')},'../config/env':{ENV},'../../config/env':{ENV}});
const jwt=load(path.join(__dirname,'../../utils/jwt.ts')); const admin=load(path.join(__dirname,'../../modules/admin/admin.middleware.ts'));
const jsonwebtoken=require('jsonwebtoken'); const user={userId:'00000000-0000-4000-8000-000000000001',email:'test@example.invalid'};
test('purpose/key/algorithm/issuer/audience/shape separate admin and learner JWTs',()=>{
 const access=jwt.signAccessToken(user); assert.equal(jwt.verifyAccessToken(access).userId,user.userId);
 const token=admin.signAdminToken('admin'); assert.equal(admin.verifyAdminToken(token).role,'ADMIN');
 assert.throws(()=>admin.verifyAdminToken(access)); assert.throws(()=>jwt.verifyAccessToken(token));
 for(const payload of [{...user,purpose:'admin'},{...user,purpose:'access',role:'ADMIN'},{...user,purpose:'access',userId:'bad'}]) {
  assert.throws(()=>jwt.verifyAccessToken(jsonwebtoken.sign(payload,ENV.JWT_ACCESS_SECRET,{algorithm:'HS256',expiresIn:60,issuer:'aptiqu',audience:'aptiqu-mobile'})));
 }
 for (const options of [{algorithm:'HS384'},{issuer:'other'},{audience:'other'},{expiresIn:-1}]) {
  assert.throws(()=>jwt.verifyAccessToken(jsonwebtoken.sign({...user,purpose:'access'},ENV.JWT_ACCESS_SECRET,{algorithm:'HS256',issuer:'aptiqu',audience:'aptiqu-mobile',expiresIn:60,...options})));
 }
});
test('opaque refresh expiration follows configuration and invalid durations fail',()=>{
 const before=Date.now(); const token=jwt.createRefreshTokenData(); assert.equal(token.rawToken.length,96);
 assert.ok(+token.expiresAt-before>=172800000 && +token.expiresAt-before<172801000); assert.notEqual(token.tokenHash,token.rawToken);
 for(const value of ['0s','forever','-1d','99999d']) assert.throws(()=>jwt.durationMs(value));
});
test('public lesson nodes allow only display fields, including nested option objects',()=>{
 const {publicLessonNode}=load(path.join(__dirname,'../../modules/lesson/services/public-lesson-node.ts'));
 const node=publicLessonNode({id:'q',type:'QUESTION',content:{text:'Question',secret:'SECRET'},input:{type:'CHOICE',options:[{id:'A',label:'A',payload:{correct:true}}]},questionReference:{mode:'INLINE',inlineData:{prompt:'P',options:[{id:'A',label:'A',isCorrect:true}],correctOptionId:'A',incorrectExplanation:'SECRET',variations:[{explanation:'SECRET'}],explanation:'SECRET'}},transitions:[{condition:{field:'isCorrect',value:true}}]});
 const raw=JSON.stringify(node); assert.ok(!raw.includes('SECRET')); for(const key of ['isCorrect','correctOptionId','variations','payload'])assert.ok(!raw.includes(key)); assert.equal(node.questionReference.inlineData.prompt,'P');
});
test('Google requires verified email and a configured audience',async()=>{
 let claims={sub:'google-sub',email:'test@example.invalid',email_verified:false};
 const googleLoad=loader({'../config/env':{ENV:{GOOGLE_WEB_CLIENT_ID:'web'}},'google-auth-library':{OAuth2Client:class{async verifyIdToken(){return {getPayload:()=>claims}}}}});
 const {verifyGoogleToken}=googleLoad(path.join(__dirname,'../../utils/google.ts'));
 await assert.rejects(()=>verifyGoogleToken('test')); claims.email_verified=true; assert.equal((await verifyGoogleToken('test')).googleId,'google-sub');
});

test('forwarded addresses are used only through explicitly trusted proxy networks',()=>{
 const req={socket:{remoteAddress:'127.0.0.1'},headers:{'x-forwarded-for':'203.0.113.9'}};
 const direct=loader({'../config/env':{ENV:{TRUST_PROXY:''}}})(path.join(__dirname,'../trusted-peer.ts'));
 assert.equal(direct.trustedPeer(req),'127.0.0.1');
 const proxied=loader({'../config/env':{ENV:{TRUST_PROXY:'loopback'}}})(path.join(__dirname,'../trusted-peer.ts'));
 assert.equal(proxied.trustedPeer(req),'203.0.113.9');assert.equal(proxied.trustedPeer({...req,socket:{remoteAddress:'198.51.100.8'}}),'198.51.100.8');
});
