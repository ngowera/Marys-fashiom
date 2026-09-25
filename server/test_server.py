import base64
import unittest, tempfile, threading, json, urllib.request, urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import server
class MarketplaceTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory();server.DB=str(Path(cls.tmp.name)/'test.sqlite');server.PASSWORD='test-only-password';server.UPLOADS=Path(cls.tmp.name)/'uploads';server.init()
  cls.http=server.ThreadingHTTPServer(('127.0.0.1',0),server.Handler);threading.Thread(target=cls.http.serve_forever,daemon=True).start();cls.url='http://127.0.0.1:'+str(cls.http.server_port)+'/api/'
 @classmethod
 def tearDownClass(cls):cls.http.shutdown();cls.http.server_close();cls.tmp.cleanup()
 def call(self,path,data=None,token=None):
  r=urllib.request.Request(self.url+path,data=None if data is None else json.dumps(data).encode(),headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token} if token else {})})
  try:
   with urllib.request.urlopen(r) as res:return res.status,json.load(res)
  except urllib.error.HTTPError as e:
   with e:return e.code,json.load(e)
 def checkout(self,key,qty=1):return {'key':key,'customer':'Test Customer','phone':'0991234567','address':'Blantyre','delivery':'Pickup','items':[{'id':'D01','variant':'S / Terracotta','qty':qty,'price':1}]}
 def test_complete_order_and_inventory_contract(self):
  self.assertEqual(self.call('admin')[0],401)
  token=self.call('login',{'password':server.PASSWORD})[1]['token']
  status,order=self.call('orders',self.checkout('first-checkout-reference'))
  self.assertEqual(status,201);self.assertEqual(order['total'],28500)
  # Idempotent retry must neither create another order nor reduce stock twice.
  self.assertEqual(self.call('orders',self.checkout('first-checkout-reference'))[1]['id'],order['id'])
  products=self.call('products')[1]['products'];self.assertNotIn('cost',products[0]);self.assertEqual(products[0]['variants']['S / Terracotta'],5)
  # A bad second line rolls the entire checkout back.
  bad=self.checkout('bad-transaction-reference');bad['items'].append({'id':'D01','variant':'NO SIZE','qty':1})
  self.assertEqual(self.call('orders',bad)[0],400)
  self.assertEqual(next(p for p in self.call('products')[1]['products'] if p['id']=='D01')['variants']['S / Terracotta'],5)
  self.assertEqual(self.call('track',{'id':order['id'],'token':'bad'})[0],400)
  self.assertEqual(self.call('track',{'id':order['id'],'token':order['token']})[0],200)
  self.assertEqual(self.call('status',{'id':order['id'],'status':'Cancelled'},token)[0],200)
  self.assertEqual(self.call('status',{'id':order['id'],'status':'Cancelled'},token)[0],400)
  self.assertEqual(next(p for p in self.call('products')[1]['products'] if p['id']=='D01')['variants']['S / Terracotta'],6)
  p=self.call('admin',token=token)[1]['products'][0];p['version']=dict(p['variants']);p['variants']['S / Terracotta']=1
  self.assertEqual(self.call('product',p,token)[0],200)
  self.assertEqual(self.call('product',p,token)[0],400) # stale editor cannot overwrite new stock
  with ThreadPoolExecutor(2) as ex: results=list(ex.map(lambda key:self.call('orders',self.checkout(key)),['parallel-checkout-111','parallel-checkout-222']))
  self.assertEqual(sorted(r[0] for r in results),[201,400])
  self.assertEqual(next(p for p in self.call('products')[1]['products'] if p['id']=='D01')['variants']['S / Terracotta'],0)
  self.assertEqual(self.call('orders',self.checkout('negative-quantity-key',-1))[0],400)
 def test_photos_sales_and_delivery(self):
  token=self.call('login',{'password':server.PASSWORD})[1]['token']
  photo={'data':base64.b64encode(b'\x89PNG\r\n\x1a\n'+b'test').decode()}
  self.assertEqual(self.call('upload',photo)[0],401)
  self.assertEqual(self.call('upload',{'data':base64.b64encode(b'<svg/>').decode()},token)[0],400)
  status,result=self.call('upload',photo,token);self.assertEqual(status,201)
  p={'id':'TESTSALE','name':'Sale dress','category':'Dresses','price':20000,'sale_price':15000,'cost':8000,'images':[result['image']],'image':result['image'],'description':'Cotton','variants':{'M / Red':3},'active':True,'reason':'Opening stock'}
  self.assertEqual(self.call('product',p,token)[0],200)
  public=next(x for x in self.call('products')[1]['products'] if x['id']=='TESTSALE')
  self.assertEqual(public['price'],15000);self.assertEqual(public['regular_price'],20000);self.assertEqual(public['images'],p['images'])
  order=self.checkout('sale-order-reference');order['items']=[{'id':'TESTSALE','variant':'M / Red','qty':1}];order['delivery']='Express';order['expected_total']=15000
  self.assertEqual(self.call('orders',order)[0],400)
  order['expected_total']=21000
  status,result=self.call('orders',order);self.assertEqual(status,201);self.assertEqual(result['total'],21000)
  self.assertEqual(next(x for x in self.call('products')[1]['products'] if x['id']=='TESTSALE')['variants']['M / Red'],2)
  p['sale_price']=21000
  self.assertEqual(self.call('product',p,token)[0],400)
 def test_operations_are_audited_idempotent_and_reported(self):
  token=self.call('login',{'password':server.PASSWORD})[1]['token']
  supplier={'name':'Test supplier','contact':'0991234567','notes':'Cotton pieces'}
  self.assertEqual(self.call('supplier',supplier)[0],401)
  sid=self.call('supplier',supplier,token)[1]['id']
  stock=lambda: next(p for p in self.call('products')[1]['products'] if p['id']=='S02')['variants']['37 / White']
  before=stock()
  event={'key':'stock-receipt-test-12345','kind':'Receive','product':'S02','variant':'37 / White','qty':3,'supplier':sid,'reference':'INV-001','reason':'New delivery'}
  self.assertEqual(self.call('stock-event',event,token)[0],200)
  self.assertEqual(self.call('stock-event',event,token)[0],200);self.assertEqual(stock(),before+3)
  event.update(key='stock-damage-test-12345',kind='Damaged',qty=1000)
  self.assertEqual(self.call('stock-event',event,token)[0],400);self.assertEqual(stock(),before+3)
  event['qty']=1;self.assertEqual(self.call('stock-event',event,token)[0],200)
  order=self.checkout('operations-order-test-12345');order['items']=[{'id':'S02','variant':'37 / White','qty':2}]
  status,result=self.call('orders',order);self.assertEqual(status,201);self.assertNotIn('cost',result['items'][0])
  for state in ['Packed','Dispatched','Completed']:self.assertEqual(self.call('status',{'id':result['id'],'status':state},token)[0],200)
  collection={'order_id':result['id'],'reference':'CASH-001'}
  self.assertEqual(self.call('collection',collection,token)[0],200)
  self.assertEqual(self.call('collection',collection,token)[0],200)
  ret={'key':'return-test-reference-12345','order_id':result['id'],'product':'S02','variant':'37 / White','qty':1,'restock':True,'reason':'Fit'}
  self.assertEqual(self.call('return',ret,token)[0],200)
  self.assertEqual(self.call('return',ret,token)[0],200);self.assertEqual(stock(),before+1)
  ret.update(key='return-test-too-many-12345',qty=2)
  self.assertEqual(self.call('return',ret,token)[0],400);self.assertEqual(stock(),before+1)
  admin=self.call('admin',token=token)[1]
  self.assertEqual(admin['report']['net_item_sales'],36000)
  self.assertEqual(admin['report']['gross_margin'],12000)
  self.assertEqual(admin['report']['cash_recorded'],72000)
  self.assertEqual(set(admin['reports']),{'month','six_months','year'})
  month=admin['reports']['month']
  self.assertEqual(sum(point['sales'] for point in month['buckets']),month['net_item_sales'])
  self.assertEqual(sum(point['margin'] for point in month['buckets']),month['gross_margin'])
  self.assertGreaterEqual(month['units_sold'],2)
  self.assertTrue(month['top_products'])
  self.assertGreater(admin['business_health']['stock_retail_value'],0)
  self.assertIn('Completed',admin['business_health']['order_statuses'])
  self.assertEqual(admin['returns'][0]['refund_status'],'Pending')
  self.assertNotIn('cost',self.call('track',{'id':result['id'],'token':result['token']})[1]['items'][0])
 def test_public_configuration_hides_secrets(self):
  import os
  os.environ['PAYCHANGU_SECRET_KEY']='do-not-disclose'
  status,config=self.call('settings');self.assertEqual(status,200)
  self.assertNotIn('do-not-disclose',json.dumps(config))
  self.assertFalse(config['online_payment_enabled'])
  self.assertEqual(self.call('../.env')[0],404)
  self.assertEqual(self.call('../inventory/')[0],404)

def test_product_update_and_delete_flow(self):
  token=self.call('login',{'password':server.PASSWORD})[1]['token']
  p={'id':'DELETE-TEST','name':'Editable dress','category':'Dresses','price':20000,'sale_price':15000,'cost':8000,'images':['/media/test.jpg'],'image':'/media/test.jpg','description':'Cotton','variants':{'S / Red':3},'active':True,'reason':'Opening stock'}
  self.assertEqual(self.call('product',p,token)[0],200)
  updated={**p,'variants':{'M / Blue':3},'version':{'S / Red':3}}
  self.assertEqual(self.call('product',updated,token)[0],200)
  public=next(x for x in self.call('products')[1]['products'] if x['id']=='DELETE-TEST')
  self.assertEqual(sorted(public['variants'].keys()),['M / Blue'])
  self.assertEqual(self.call('product',{'id':'DELETE-TEST','delete':True},token)[0],200)
  self.assertIsNone(next((x for x in self.call('products')[1]['products'] if x['id']=='DELETE-TEST'), None))

if __name__=='__main__':unittest.main()
