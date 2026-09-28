"""Mary’s Fashion local development API. Production needs HTTPS and managed staff identity."""
import json, os, sqlite3, secrets, hashlib, hmac, time, mimetypes, base64, re, binascii, urllib.request, urllib.error
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse
from config import public_settings
import operations
ROOT = Path(__file__).resolve().parents[1]
DB = os.environ.get('NYASA_DB', str(ROOT / 'server' / 'nyasa.sqlite'))
UPLOADS = Path(os.environ.get('MARYS_UPLOADS', str(ROOT / 'server' / 'uploads')))
PASSWORD = os.environ.get('NYASA_ADMIN_PASSWORD')
SUPABASE_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
SUPABASE_KEY = os.environ.get('SUPABASE_PUBLISHABLE_KEY', '')
SESSIONS = {}
CATEGORIES = ['Outfit', 'Topwear', 'Bottomwear', 'Footwear', 'Dresses', 'Shoes', 'Bags', 'Accessories', 'Suit']
def connect():
 c=sqlite3.connect(DB,timeout=15); c.row_factory=sqlite3.Row; c.execute('PRAGMA foreign_keys=ON'); return c

def init():
 with connect() as c:
  c.executescript('''CREATE TABLE IF NOT EXISTS products(id TEXT PRIMARY KEY,name TEXT,category TEXT,price INTEGER,cost INTEGER,description TEXT,image TEXT,variants TEXT,active INTEGER DEFAULT 1);
  CREATE TABLE IF NOT EXISTS orders(id TEXT PRIMARY KEY,token TEXT,customer TEXT,phone TEXT,address TEXT,delivery TEXT,total INTEGER,items TEXT,status TEXT,payment TEXT,created TEXT);
  CREATE TABLE IF NOT EXISTS movements(id INTEGER PRIMARY KEY,product TEXT,variant TEXT,delta INTEGER,reason TEXT,created TEXT);
  CREATE TABLE IF NOT EXISTS requests(key TEXT PRIMARY KEY,order_id TEXT);''')
  operations.init(c)
  columns={r[1] for r in c.execute('pragma table_info(products)')}
  if 'sale_price' not in columns:c.execute('alter table products add column sale_price INTEGER')
  if 'images' not in columns:c.execute("alter table products add column images TEXT NOT NULL DEFAULT '[]'")
  if 'collections' not in columns:c.execute("alter table products add column collections TEXT NOT NULL DEFAULT '[]'")
  if 'audience' not in columns:c.execute("alter table products add column audience TEXT NOT NULL DEFAULT 'Woman'")

def product(r,staff=False):
 d=dict(r); d['variants']=json.loads(d['variants']); d['images']=json.loads(d['images']) or [d['image']]; d['collections']=json.loads(d.get('collections') or '[]')
 d['regular_price']=d['price'];d['price']=d['sale_price'] if d['sale_price'] is not None else d['price']
 if not staff:d.pop('cost',None)
 return d

class Handler(BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def send(self,status,data):
  
  if isinstance(data,dict) and 'items' in data:
   data=dict(data);data['items']=[{k:v for k,v in line.items() if k!='cost'} for line in data['items']]
  b=json.dumps(data).encode(); self.send_response(status); self.send_header('Content-Type','application/json'); self.send_header('Cache-Control','no-store'); self.end_headers();self.wfile.write(b)
 def auth(self):
  key=self.headers.get('Authorization','').removeprefix('Bearer ')
  if SESSIONS.get(key,0)>=time.time(): return
  if not key or not SUPABASE_URL or not SUPABASE_KEY:
   raise PermissionError('Please sign in to the inventory app.')
  headers={'apikey':SUPABASE_KEY,'Authorization':'Bearer '+key}
  try:
   request=urllib.request.Request(SUPABASE_URL+'/auth/v1/user',headers=headers)
   with urllib.request.urlopen(request,timeout=5) as response:
    user=json.loads(response.read())
   user_id=user.get('id')
   if not user_id: raise PermissionError('Please sign in to the inventory app.')
   profile=urllib.request.Request(
    SUPABASE_URL+'/rest/v1/staff_profiles?select=user_id&user_id=eq.'+user_id,
    headers=headers)
   with urllib.request.urlopen(profile,timeout=5) as response:
    staff=json.loads(response.read())
   if not staff: raise PermissionError('Your account is not authorised for inventory access.')
  except (urllib.error.HTTPError, urllib.error.URLError, ValueError, KeyError):
   raise PermissionError('Please sign in to the inventory app.')
 def do_GET(self):
  p=urlparse(self.path).path
  try:
   with connect() as c:
    if p=='/api/auth-config':
     return self.send(200,{'url':SUPABASE_URL,'publishable_key':SUPABASE_KEY})
    if p=='/api/settings': return self.send(200,public_settings())
    if p=='/api/products': return self.send(200,{'products':[product(r) for r in c.execute('select * from products where active=1')],'settings':public_settings()})
    if p=='/api/admin':
     self.auth(); return self.send(200,{'products':[product(r,True) for r in c.execute('select * from products')],'orders':[dict(r) | {'items':json.loads(r['items'])} for r in c.execute('select * from orders order by created desc')],'movements':[dict(r) for r in c.execute('select * from movements order by id desc limit 200')]} | operations.admin(c))
   if p.startswith('/media/'):
    name=p.removeprefix('/media/')
    if not re.fullmatch(r'[a-f0-9]{32}\.(png|jpg|webp)',name):return self.send(404,{'error':'Photo not found'})
    f=UPLOADS/name
    if not f.is_file():return self.send(404,{'error':'Photo not found'})
    self.send_response(200);self.send_header('Content-Type',mimetypes.guess_type(name)[0]);self.send_header('X-Content-Type-Options','nosniff');self.end_headers();self.wfile.write(f.read_bytes());return
   rel=p.lstrip('/') or 'index.html'
   base=ROOT/'apps'/'marys_fashion_website'/'build'/'web'
   if not base.is_dir():base=ROOT/'build'/'web'
   f=(base/rel).resolve()
   if not f.is_relative_to(base.resolve()) or not f.is_file(): return self.send(404,{'error':'Not found'})
   self.send_response(200); self.send_header('Content-Type',mimetypes.guess_type(str(f))[0] or 'application/octet-stream'); self.end_headers();self.wfile.write(f.read_bytes())
  except PermissionError as e:self.send(401,{'error':str(e)})
 def do_POST(self):
  try:
   length=int(self.headers.get('Content-Length',0))
   if length>6000000:raise ValueError('Photo too large. Maximum 4 MB per image.')
   d=json.loads(self.rfile.read(length)); p=urlparse(self.path).path
   if p=='/api/login':
    time.sleep(.3)
    if not PASSWORD or not hmac.compare_digest(str(d.get('password','')),PASSWORD):raise PermissionError('Incorrect staff password')
    token=secrets.token_urlsafe(32);SESSIONS[token]=time.time()+28800;return self.send(200,{'token':token})
   if p=='/api/upload':
    self.auth()
    try:raw=base64.b64decode(d.get('data',''),validate=True)
    except (binascii.Error,TypeError):raise ValueError('Invalid image data')
    if not raw or len(raw)>4*1024*1024:raise ValueError('Maximum image size is 4 MB')
    ext='png' if raw.startswith(b'\x89PNG\r\n\x1a\n') else 'jpg' if raw.startswith(b'\xff\xd8\xff') else 'webp' if raw[:4]==b'RIFF' and raw[8:12]==b'WEBP' else None
    if ext is None:raise ValueError('Choose a JPG, PNG or WebP photo')
    UPLOADS.mkdir(parents=True,exist_ok=True);name=secrets.token_hex(16)+'.'+ext
    (UPLOADS/name).write_bytes(raw)
    return self.send(201,{'image':'/media/'+name})
   with connect() as c:
    c.execute('BEGIN IMMEDIATE')
    if p=='/api/orders':
     key=str(d.get('key',''))
     if len(key)<16:raise ValueError('Missing checkout reference')
     old=c.execute('select o.* from requests r join orders o on r.order_id=o.id where r.key=?',(key,)).fetchone()
     if old:return self.send(200,dict(old)|{'items':json.loads(old['items'])})
     for field in ['customer','phone','address']:
      if not isinstance(d.get(field),str) or not d[field].strip() or len(d[field])>500:raise ValueError('Please complete your contact and delivery details')
     digits=''.join(x for x in d['phone'] if x.isdigit())
     if len(digits)<9 or len(digits)>15:raise ValueError('Enter a valid phone number')
     if d.get('delivery') not in ['Pickup','Delivery','Express']:raise ValueError('Choose a delivery method')
     if not isinstance(d.get('items'),list) or not d['items']:raise ValueError('Your bag is empty')
     lines=[];total=0
     for item in d['items']:
      qty=item.get('qty'); variant=item.get('variant'); row=c.execute('select * from products where id=? and active=1',(item.get('id'),)).fetchone()
      if type(qty) is not int or qty<1 or qty>100 or row is None:raise ValueError('Invalid item')
      v=json.loads(row['variants'])
      if variant not in v or v[variant]<qty:raise ValueError(f'{row["name"]}: selected size no longer has enough stock. Please update your bag.')
      v[variant]-=qty;c.execute('update products set variants=? where id=?',(json.dumps(v),row['id']))
      price=row['sale_price'] if row['sale_price'] is not None else row['price']
      total+=price*qty;lines.append({'id':row['id'],'name':row['name'],'variant':variant,'qty':qty,'price':price,'regular_price':row['price'],'cost':row['cost']})
     oid='NT-'+secrets.token_hex(4).upper();token=secrets.token_urlsafe(24)
     for line in lines:c.execute("insert into movements(product,variant,delta,reason,created) values(?,?,?,?,datetime('now'))",(line['id'],line['variant'],-line['qty'],'Order '+oid))
     # Delivery rate is deliberately explicit and server-owned; demo pickup is free.
     total+=public_settings()['delivery_fees'][d['delivery']]
     if 'expected_total' in d and d['expected_total']!=total:raise ValueError('A price has changed. Refresh your cart and review the new total before ordering.')
     c.execute("insert into orders(id,token,customer,phone,address,delivery,total,items,status,payment,created) values(?,?,?,?,?,?,?,?,?,?,datetime('now'))",(oid,token,d['customer'].strip(),d['phone'].strip(),d['address'].strip(),d['delivery'],total,json.dumps(lines),'Placed','Pay on collection/delivery'))
     c.execute('insert into requests values(?,?)',(key,oid));c.commit()
     return self.send(201,{'id':oid,'token':token,'total':total,'status':'Placed','items':lines})
    if p=='/api/track':
     r=c.execute('select * from orders where id=? and token=?',(d.get('id'),d.get('token'))).fetchone()
     if r is None:raise ValueError('Order not found. Check your order reference and private tracking code.')
     return self.send(200,dict(r)|{'items':json.loads(r['items'])})
    self.auth()
    result=operations.apply(c,p.removeprefix('/api/'),d)
    if result is not None:
     c.commit();return self.send(200,result)
    if p=='/api/product':
     id=d.get('id')
     if d.get('delete') is True:
      if not isinstance(id,str) or not id.strip():raise ValueError('Missing product id')
      c.execute('update products set active=0 where id=?',(id,))
      c.commit();return self.send(200,{'ok':True,'deleted':True})
     for f in ['name','description','category']:
      if not isinstance(d.get(f),str) or not d[f].strip():raise ValueError('Complete all product fields')
     d['audience'] = d.get('audience') or ('Men' if d.get('category') == 'Suit' else 'Woman')
     if d['audience'] not in ['Woman','Men']:raise ValueError('Choose Woman or Men')
     if d['category'] not in CATEGORIES:raise ValueError('Choose a category')
     allowed = ['Suit','Topwear','Bottomwear','Shoes','Accessories'] if d['audience'] == 'Men' else ['Outfit','Topwear','Bottomwear','Footwear','Dresses','Shoes','Bags','Accessories']
     if d['category'] not in allowed:raise ValueError('Choose a category for this shop section')
     for f in ['price','cost']:
      if type(d.get(f)) is not int or d[f]<0:raise ValueError('Prices must be positive whole kwacha amounts')
     if not isinstance(d.get('variants'),dict) or not d['variants']:raise ValueError('Add at least one size / colour')
     if not isinstance(d.get('collections',[]),list) or any(c not in ['New Arrivals','Best Sellers','Sale / Clearance'] for c in d.get('collections',[])):raise ValueError('Invalid special collection')
     if any(not k.strip() or type(v) is not int or v<0 for k,v in d['variants'].items()):raise ValueError('Stock must be a non-negative whole number')
     id=id or 'P'+secrets.token_hex(4).upper();old=c.execute('select * from products where id=?',(id,)).fetchone();before=json.loads(old['variants']) if old else {};images=d.get('images') or [d.get('image','dress.jpg')]
     if old:
      current=json.loads(old['variants'])
      same_total=sum(current.values())==sum(d['variants'].values())
      if d.get('version') is not None and d.get('version') != current and not same_total:
        raise ValueError('Stock changed while you were editing. Reload and try again.')
     sale=d.get('sale_price')
     if sale is not None and (type(sale) is not int or sale<=0 or sale>=d['price']):raise ValueError('Sale price must be greater than zero and lower than the regular price')
     c.execute('insert or replace into products(id,name,audience,category,price,cost,description,image,variants,active,sale_price,images,collections) values(?,?,?,?,?,?,?,?,?,?,?,?,?)',(id,d['name'].strip(),d['audience'],d['category'],d['price'],d['cost'],d['description'],images[0],json.dumps(d['variants']),int(bool(d.get('active',True))),sale,json.dumps(images),json.dumps(d.get('collections',[]))))
     for v,q in d['variants'].items():
      delta=q-before.get(v,0)
      if delta:c.execute("insert into movements(product,variant,delta,reason,created) values(?,?,?,?,datetime('now'))",(id,v,delta,str(d.get('reason','Stock adjustment'))[:300]))
     c.commit();return self.send(200,{'ok':True})
    if p=='/api/status':
     row=c.execute('select * from orders where id=?',(d.get('id'),)).fetchone()
     if not row:raise ValueError('Order not found')
     allowed={'Placed':['Packed','Cancelled'],'Packed':['Dispatched','Cancelled'],'Dispatched':['Completed'],'Completed':[],'Cancelled':[]}
     status=d.get('status')
     if status not in allowed[row['status']]:raise ValueError('This status transition is not allowed')
     if status=='Cancelled':
      for line in json.loads(row['items']):
       r=c.execute('select variants from products where id=?',(line['id'],)).fetchone();v=json.loads(r[0]);v[line['variant']]=v.get(line['variant'],0)+line['qty'];c.execute('update products set variants=? where id=?',(json.dumps(v),line['id']))
       c.execute("insert into movements(product,variant,delta,reason,created) values(?,?,?,?,datetime('now'))",(line['id'],line['variant'],line['qty'],'Cancelled '+row['id']))
     if status=='Completed':
      c.execute("update orders set status=?,completed_at=datetime('now') where id=?",(status,row['id']))
     else:c.execute('update orders set status=? where id=?',(status,row['id']))
     c.commit();return self.send(200,{'ok':True})
    return self.send(404,{'error':'Not found'})
  except PermissionError as e:self.send(401,{'error':str(e)})
  except (ValueError,KeyError,TypeError) as e:self.send(400,{'error':str(e)})
  except Exception:
   import traceback;traceback.print_exc()
   self.send(500,{'error':'Unable to complete the request. Please try again.'})

if __name__=='__main__':
 if not PASSWORD:raise SystemExit('Set NYASA_ADMIN_PASSWORD before starting the server.')
 init();port=int(os.environ.get('PORT',8080));print(f'Mary’s Fashion running at http://127.0.0.1:{port}',flush=True);ThreadingHTTPServer(('127.0.0.1',port),Handler).serve_forever()
