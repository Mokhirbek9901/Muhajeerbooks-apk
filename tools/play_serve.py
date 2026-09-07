from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os

ROOT = Path('/output')
os.chdir(ROOT)

class Handler(SimpleHTTPRequestHandler):
    def send_head(self):
        requested = self.path.split('?', 1)[0]
        local = ROOT / requested.lstrip('/')
        if requested not in ('/', '') and not local.exists():
            self.path = '/index.html'
        return super().send_head()

ThreadingHTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
