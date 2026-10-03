const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const mobile = process.argv.includes('--mobile');
const root = path.resolve(__dirname, mobile ? 'build/mobile-preview' : 'build/web');
const port = mobile ? 8081 : 8080;
const types = {'.html':'text/html', '.js':'application/javascript', '.json':'application/json', '.css':'text/css', '.wasm':'application/wasm', '.png':'image/png', '.woff2':'font/woff2', '.ttf':'font/ttf'};
http.createServer((req,res) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); } catch { res.writeHead(400).end(); return; }
  const target = path.resolve(root, '.' + (pathname.endsWith('/') ? pathname + 'index.html' : pathname));
  if (!target.startsWith(root + path.sep)) {res.writeHead(403).end();return;}
  fs.readFile(target, (error,data) => { if(error){res.writeHead(404).end('Not found');return;} res.writeHead(200, {'Content-Type':types[path.extname(target)] || 'application/octet-stream', 'Cache-Control':'no-store'});res.end(data);});
}).listen(port,'127.0.0.1',()=>console.log(`${mobile ? 'SolarServe mobile' : 'SolarCare'} preview: http://localhost:${port}`));
