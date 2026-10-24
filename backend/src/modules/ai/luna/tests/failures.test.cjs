const test=require('node:test');const assert=require('node:assert/strict');
const {preparationFailure,LunaFailure,safeProviderCode}=require('../failures.ts');
test('only fixed preparation codes, safe provider details and Prisma codes reach diagnostics',()=>{
 const known=new LunaFailure('LUNA_AUTH_FAILED',401,'invalid_api_key');
 assert.deepEqual(preparationFailure(known),{code:'LUNA_AUTH_FAILED',providerStatus:401,providerCode:'invalid_api_key'});
 assert.deepEqual(preparationFailure(Object.assign(new Error('SECRET_CANARY'),{code:'P2002'})),{code:'DATABASE_FAILURE',causeCode:'P2002'});
 for(const name of ['SyntaxError','ZodError'])assert.equal(preparationFailure({name,message:'SECRET_CANARY'}).code,'LUNA_INVALID_RESPONSE');
 assert.equal(preparationFailure({name:'AbortError'}).code,'LUNA_REQUEST_TIMEOUT');
 assert.equal(preparationFailure(Error('QUALITY_REVIEW_FAILED')).code,'QUALITY_REVIEW_FAILED');
 assert.deepEqual(preparationFailure(Object.assign(new TypeError('SECRET_CANARY'),{cause:{code:'ECONNRESET',address:'SECRET_CANARY'}})),{code:'LUNA_NETWORK_FAILURE',causeCode:'ECONNRESET'});
 assert.equal(safeProviderCode('SECRET_CANARY'),undefined);
});
test('unknown, malformed and credential-bearing errors are never copied into diagnostic fields',()=>{
 for(const error of [null,undefined,'SECRET_CANARY',{code:'SECRET_CANARY',message:'SECRET_CANARY',stack:'SECRET_CANARY'},
  {code:'LUNA_REQUEST_FAILED',providerStatus:Infinity,providerCode:'SECRET_CANARY'}]){
  const diagnostic=preparationFailure(error);assert.ok(!JSON.stringify(diagnostic).includes('SECRET_CANARY'));
  assert.equal(diagnostic.providerStatus,undefined);assert.equal(diagnostic.providerCode,undefined);
 }
});
