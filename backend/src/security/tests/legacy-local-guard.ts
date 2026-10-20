import path from 'node:path';
// Must be the first import in legacy service-writing test scripts.
if(process.env.LEGACY_ALLOW_LOCAL_TESTS!=='true')throw new Error('Legacy integration disabled: use a dedicated local test database and explicit LEGACY_ALLOW_LOCAL_TESTS');
let database:URL,redis:URL;
try{database=new URL(process.env.LEGACY_TEST_DATABASE_URL || 'invalid:');redis=new URL(process.env.LEGACY_TEST_REDIS_URL || 'invalid:');}catch{throw new Error('Invalid legacy test configuration');}
const storage=process.env.LEGACY_TEST_STORAGE_ROOT || '';
if(!path.isAbsolute(storage)||!storage.startsWith('/private/tmp/aptiqu-legacy-'))throw new Error('Legacy tests require their own private temporary storage root');
if(!['postgres:','postgresql:'].includes(database.protocol) || database.hostname!=='127.0.0.1' || !/^\/aptiqu_legacy_test_[a-z0-9_]+$/.test(database.pathname) || !/^\d+$/.test(database.port))throw new Error('Legacy tests require a dedicated loopback database');
if(redis.protocol!=='redis:' || redis.hostname!=='127.0.0.1' || redis.port!=='56439' || redis.pathname!=='/8')throw new Error('Legacy tests require isolated loopback Redis DB 8');
Object.assign(process.env,{BOOK_STORAGE_ROOT:path.join(storage,'books'),BOOK_TEMP_ROOT:path.join(storage,'uploads'),DATABASE_URL:database.href,REDIS_URL:redis.href,DOTENV_CONFIG_PATH:'/dev/null',NODE_ENV:'test',GOOGLE_AUTH_ENABLED:'false',AI_GENERATION_ENABLED:'false',JWT_ACCESS_SECRET:'legacy-fixture-access',ADMIN_JWT_SECRET:'legacy-fixture-admin',ADMIN_USERNAME:'fixture',ADMIN_PASSWORD:'fixture'});
