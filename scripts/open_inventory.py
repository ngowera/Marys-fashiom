"""Open the local Mary Inventory app and its shared website backend."""
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
from config import load_env
import os
load_env()
port = int(os.environ.get('PORT', '8083'))
if port != 8083:
    raise SystemExit('This local app build uses port 8083. Set PORT=8083 in .env or rebuild with API_URL for your server.')
app = ROOT / 'apps/mary_inventory/build/linux/x64/release/bundle/mary_inventory'
if not app.exists():
    raise SystemExit('Build the desktop app first: cd apps/mary_inventory && flutter build linux --release')

def ready():
    try:
        with urllib.request.urlopen('http://127.0.0.1:8083/api/settings', timeout=1) as response:
            return response.status == 200
    except OSError:
        return False

server = None
try:
    if not ready():
        server = subprocess.Popen([sys.executable, str(ROOT / 'server/start.py')], cwd=ROOT)
        for _ in range(50):
            if ready():
                break
            if server.poll() is not None:
                raise SystemExit('The local server could not start.')
            time.sleep(0.1)
        else:
            raise SystemExit('The local server did not become ready.')
    print('Website: http://127.0.0.1:8083/ — keep Mary Inventory open to use this local preview.', flush=True)
    subprocess.run([str(app)], cwd=app.parent, check=True)
finally:
    if server is not None:
        server.terminate()
        server.wait(timeout=10)
