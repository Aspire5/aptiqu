// Local manifest inspection only; never publishes or installs.
const {execFileSync}=require('node:child_process');
const [artifact]=JSON.parse(execFileSync('npm',['pack','--dry-run','--ignore-scripts','--json'],{cwd:require('node:path').resolve(__dirname,'..'),encoding:'utf8',maxBuffer:2*1024*1024}));
const paths=artifact.files.map(file=>file.path);
const bad=paths.filter(file=>/(^|\/)(storage|books|node_modules|tests|scripts)(\/|$)|(^|\/)\.env$|\.(pdf|tgz)$/.test(file));
if(!paths.includes('dist/server.js')||bad.length)throw new Error('Release artifact contains unexpected files or lacks a built server');
console.log(JSON.stringify({files:paths.length,unpackedBytes:artifact.unpackedSize,privateRuntimeFiles:0}));
