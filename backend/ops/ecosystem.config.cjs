// Prepared example only. Never use reload/cluster for realtime or jobs ownership.
const path=require('node:path');
const cwd=path.resolve(__dirname,'..');
const common={cwd,script:'dist/server.js',exec_mode:'fork',instances:1,wait_ready:true,listen_timeout:30000,kill_timeout:35000,time:false,autorestart:true,exp_backoff_restart_delay:1000};
module.exports={apps:[
 {...common,name:'aptiqu-realtime',env:{NODE_ENV:'production',BACKEND_ROLE:'realtime',HOST:'127.0.0.1',PORT:'5001',SHUTDOWN_TIMEOUT_MS:'30000'}},
 {...common,name:'aptiqu-jobs',env:{NODE_ENV:'production',BACKEND_ROLE:'jobs',HOST:'127.0.0.1',PORT:'5002',SHUTDOWN_TIMEOUT_MS:'30000'}},
]};
