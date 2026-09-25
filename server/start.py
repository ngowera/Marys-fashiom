"""Starts the local preview; generates a unique local staff password on first run."""
import os, secrets, sys
from config import load_env
load_env()
from pathlib import Path
here=Path(__file__).resolve().parent
password_file=here/'.staff-password'
if not password_file.exists():
 fd=os.open(password_file,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
 with os.fdopen(fd,'w') as f:f.write(secrets.token_urlsafe(16))
env=dict(os.environ,NYASA_ADMIN_PASSWORD=os.environ.get('NYASA_ADMIN_PASSWORD') or password_file.read_text().strip())
print('Staff password is in server/.staff-password (local only).',flush=True)
os.execve(sys.executable,[sys.executable,str(here/'server.py')],env)
