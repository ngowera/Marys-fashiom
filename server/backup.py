"""Create a private backup of the local database and product uploads."""
import os, sqlite3, tempfile, zipfile
from datetime import datetime, timezone
from pathlib import Path
from config import ROOT

def backup(destination=None):
    folder=Path(destination) if destination else ROOT/'server'/'backups'
    folder.mkdir(parents=True,exist_ok=True)
    path=folder/('marysfashion-'+datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f')+'.zip')
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    try:
        with os.fdopen(fd,'wb') as output, tempfile.TemporaryDirectory() as tmp:
            snapshot=Path(tmp)/'shop.sqlite'
            db=Path(os.environ.get('NYASA_DB',ROOT/'server'/'nyasa.sqlite'))
            if not db.exists():raise ValueError('No local database to back up yet')
            with sqlite3.connect(db) as source, sqlite3.connect(snapshot) as target:source.backup(target)
            with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as archive:
                archive.write(snapshot,'nyasa.sqlite')
                uploads=Path(os.environ.get('MARYS_UPLOADS',ROOT/'server'/'uploads'))
                if uploads.exists():
                    for image in uploads.iterdir():
                        if image.is_file():archive.write(image,'uploads/'+image.name)
    except Exception:
        path.unlink(missing_ok=True);raise
    return path
if __name__=='__main__':print(backup())
