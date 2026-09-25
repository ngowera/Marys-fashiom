"""Transactional staff stock operations and reports for the local preview."""
import calendar, datetime, json, secrets

def init(c):
    c.executescript('''
    CREATE TABLE IF NOT EXISTS suppliers(id TEXT PRIMARY KEY,name TEXT NOT NULL,contact TEXT NOT NULL,notes TEXT NOT NULL);
    CREATE TABLE IF NOT EXISTS stock_events(key TEXT PRIMARY KEY,kind TEXT,product TEXT,variant TEXT,qty INTEGER,supplier TEXT,reference TEXT,reason TEXT,created TEXT);
    CREATE TABLE IF NOT EXISTS returns(id TEXT PRIMARY KEY,key TEXT UNIQUE,order_id TEXT,product TEXT,variant TEXT,qty INTEGER,restock INTEGER,amount INTEGER,reason TEXT,refund_status TEXT,created TEXT);
    CREATE TABLE IF NOT EXISTS collections(order_id TEXT PRIMARY KEY,amount INTEGER,reference TEXT,created TEXT);
    ''')
    order_columns={r[1] for r in c.execute('pragma table_info(orders)')}
    if 'completed_at' not in order_columns:
        c.execute('alter table orders add column completed_at TEXT')

def required(d, field):
    value=d.get(field)
    if not isinstance(value,str) or not value.strip() or len(value)>1000: raise ValueError('Please complete '+field)
    return value.strip()

def apply(c, path, d):
    if path=='supplier':
        sid=d.get('id') or 'SUP-'+secrets.token_hex(4).upper()
        c.execute('insert or replace into suppliers values(?,?,?,?)',(sid,required(d,'name'),required(d,'contact'),str(d.get('notes',''))[:1000]))
        return {'ok':True,'id':sid}
    if path=='stock-event':
        key=required(d,'key')
        if len(key)<16:raise ValueError('Missing operation reference')
        if c.execute('select 1 from stock_events where key=?',(key,)).fetchone():return {'ok':True}
        kind=d.get('kind');qty=d.get('qty')
        if kind not in ['Receive','Damaged'] or type(qty) is not int or qty<1:raise ValueError('Choose a valid operation and positive quantity')
        row=c.execute('select * from products where id=?',(d.get('product'),)).fetchone()
        if row is None:raise ValueError('Product not found')
        variants=json.loads(row['variants']);variant=d.get('variant')
        if variant not in variants:raise ValueError('Choose a size / colour')
        reason=required(d,'reason');reference=required(d,'reference')
        supplier=d.get('supplier','')
        if kind=='Receive' and not c.execute('select 1 from suppliers where id=?',(supplier,)).fetchone():raise ValueError('Choose a supplier before receiving stock')
        delta=qty if kind=='Receive' else -qty
        if variants[variant]+delta<0:raise ValueError('Not enough available stock for this adjustment')
        variants[variant]+=delta
        c.execute('update products set variants=? where id=?',(json.dumps(variants),row['id']))
        c.execute("insert into stock_events values(?,?,?,?,?,?,?,?,datetime('now'))",(key,kind,row['id'],variant,qty,supplier,reference,reason))
        c.execute("insert into movements(product,variant,delta,reason,created) values(?,?,?,?,datetime('now'))",(row['id'],variant,delta,kind+' · '+reference+' · '+reason))
        return {'ok':True}
    if path=='collection':
        order=c.execute('select * from orders where id=?',(d.get('order_id'),)).fetchone()
        if order is None or order['status']!='Completed':raise ValueError('Record collection after completing delivery or pickup')
        if order['payment']!='Pay on collection/delivery':raise ValueError('Online payments must be verified by the payment provider')
        reference=required(d,'reference')
        c.execute("insert or ignore into collections values(?,?,?,datetime('now'))",(order['id'],order['total'],reference))
        return {'ok':True}
    if path=='return':
        key=required(d,'key')
        if len(key)<16:raise ValueError('Missing operation reference')
        old=c.execute('select id from returns where key=?',(key,)).fetchone()
        if old:return {'ok':True,'id':old['id']}
        order=c.execute('select * from orders where id=?',(d.get('order_id'),)).fetchone()
        if order is None or order['status']!='Completed':raise ValueError('Returns are recorded for completed orders only')
        qty=d.get('qty');pid=d.get('product');variant=d.get('variant')
        if type(qty) is not int or qty<1:raise ValueError('Enter a positive return quantity')
        lines=[x for x in json.loads(order['items']) if x['id']==pid and x['variant']==variant]
        bought=sum(x['qty'] for x in lines)
        returned=c.execute('select coalesce(sum(qty),0) from returns where order_id=? and product=? and variant=?',(order['id'],pid,variant)).fetchone()[0]
        if qty+returned>bought:raise ValueError('Return quantity exceeds the unreturned order quantity')
        restock=d.get('restock') is True;reason=required(d,'reason');rid='RET-'+secrets.token_hex(4).upper()
        if restock:
            row=c.execute('select variants from products where id=?',(pid,)).fetchone()
            if row is None:raise ValueError('Product no longer exists')
            variants=json.loads(row['variants']);variants[variant]=variants.get(variant,0)+qty
            c.execute('update products set variants=? where id=?',(json.dumps(variants),pid))
            c.execute("insert into movements(product,variant,delta,reason,created) values(?,?,?,?,datetime('now'))",(pid,variant,qty,'Return '+rid+' · '+reason))
        amount=qty*lines[0]['price']
        collected=c.execute('select 1 from collections where order_id=?',(order['id'],)).fetchone()
        refund='Pending' if collected else 'Review payment'
        c.execute("insert into returns values(?,?,?,?,?,?,?,?,?,?,datetime('now'))",(rid,key,order['id'],pid,variant,qty,int(restock),amount,reason,refund))
        return {'ok':True,'id':rid}
    return None

def _parse_time(value):
    if not value:return None
    try:return datetime.datetime.fromisoformat(str(value).replace('Z','+00:00')).replace(tzinfo=None)
    except ValueError:return None

def _month_start(value):
    return value.replace(day=1,hour=0,minute=0,second=0,microsecond=0)

def _add_months(value, amount):
    month=value.month-1+amount
    year=value.year+month//12
    month=month%12+1
    return value.replace(year=year,month=month,day=min(value.day,calendar.monthrange(year,month)[1]))

def _period_report(orders, returns, products, start, end, previous_start, bucket_kind):
    selected=[o for o in orders if start<=o['_report_time']<end]
    previous=[o for o in orders if previous_start<=o['_report_time']<start]
    selected_returns=[r for r in returns if (t:=_parse_time(r['created'])) is not None and start<=t<end]
    previous_returns=[r for r in returns if (t:=_parse_time(r['created'])) is not None and previous_start<=t<start]
    costs={p['id']:p['cost'] for p in products}

    def totals(period_orders, period_returns):
        sales=cost=units=estimated=0
        by_product={}
        for order in period_orders:
            for line in json.loads(order['items']):
                qty=line['qty']; revenue=qty*line['price']; units+=qty; sales+=revenue
                if 'cost' not in line:estimated+=1
                cost+=qty*line.get('cost',costs.get(line['id'],0))
                item=by_product.setdefault(line['id'],{'id':line['id'],'name':line['name'],'units':0,'sales':0})
                item['units']+=qty;item['sales']+=revenue
        return_value=sum(r['amount'] for r in period_returns)
        for r in period_returns:
            if r['restock']:
                matching=[o for o in orders if o['id']==r['order_id']]
                if matching:
                    lines=[l for l in json.loads(matching[0]['items']) if l['id']==r['product'] and l['variant']==r['variant']]
                    if lines:cost-=r['qty']*lines[0].get('cost',costs.get(r['product'],0))
        net=sales-return_value
        return {'completed_orders':len(period_orders),'item_sales':sales,'returns_value':return_value,
            'net_item_sales':net,'cost_of_goods':cost,'gross_margin':net-cost,'units_sold':units,
            'average_order_value':round(net/len(period_orders)) if period_orders else 0,
            'estimated_cost_lines':estimated,
            'top_products':sorted(by_product.values(),key=lambda x:(x['sales'],x['units']),reverse=True)[:5]}

    current=totals(selected,selected_returns);prior=totals(previous,previous_returns)
    previous_sales=prior['net_item_sales'];current_sales=current['net_item_sales']
    current['comparison_percent']=None if previous_sales==0 else round((current_sales-previous_sales)*100/previous_sales,1)
    current['previous_net_item_sales']=previous_sales
    current['margin_rate']=round(current['gross_margin']*100/current_sales,1) if current_sales else 0
    buckets=[]
    cursor=start
    while cursor<end:
        if bucket_kind=='day':
            bucket_end=cursor+datetime.timedelta(days=1);label=str(cursor.day)
        else:
            bucket_end=_add_months(cursor,1);label=cursor.strftime('%b')
        bucket_orders=[o for o in selected if cursor<=o['_report_time']<bucket_end]
        bucket_returns=[r for r in selected_returns if cursor<=_parse_time(r['created'])<bucket_end]
        bucket_totals=totals(bucket_orders,bucket_returns)
        buckets.append({'label':label,'sales':bucket_totals['net_item_sales'],'margin':bucket_totals['gross_margin'],'orders':len(bucket_orders)})
        cursor=bucket_end
    current['buckets']=buckets
    current['start']=start.date().isoformat();current['end']=(end-datetime.timedelta(days=1)).date().isoformat()
    return current

def admin(c):
    products=list(c.execute('select * from products'))
    lows=[{'product':p['id'],'name':p['name'],'variant':v,'qty':q} for p in products for v,q in json.loads(p['variants']).items() if q<=3]
    returns=[dict(r) for r in c.execute('select * from returns order by created desc')]
    completed=[]
    for row in c.execute("select * from orders where status='Completed'"):
        order=dict(row);order['_report_time']=_parse_time(order.get('completed_at') or order['created'])
        if order['_report_time'] is not None:completed.append(order)
    now=datetime.datetime.now(datetime.UTC).replace(tzinfo=None);this_month=_month_start(now);next_month=_add_months(this_month,1)
    report_month=_period_report(completed,returns,products,this_month,next_month,_add_months(this_month,-1),'day')
    six_start=_add_months(this_month,-5)
    report_six=_period_report(completed,returns,products,six_start,next_month,_add_months(six_start,-6),'month')
    year_start=_add_months(this_month,-11)
    report_year=_period_report(completed,returns,products,year_start,next_month,_add_months(year_start,-12),'month')
    all_time_start=min([o['_report_time'] for o in completed],default=this_month)
    all_time=_period_report(completed,returns,products,all_time_start,next_month,all_time_start,'month')
    stock_cost=sum(sum(json.loads(p['variants']).values())*p['cost'] for p in products)
    stock_retail=sum(sum(json.loads(p['variants']).values())*(p['sale_price'] if p['sale_price'] is not None else p['price']) for p in products)
    status_counts={r['status']:r['count'] for r in c.execute('select status,count(*) count from orders group by status')}
    cash_recorded=c.execute('select coalesce(sum(amount),0) from collections').fetchone()[0]
    refunds_pending=sum(r['amount'] for r in returns if r['refund_status']!='Refunded')
    for value in [report_month,report_six,report_year,all_time]:
        value['cash_recorded']=cash_recorded;value['refunds_pending']=refunds_pending
    return {'suppliers':[dict(r) for r in c.execute('select * from suppliers order by name')],
        'stock_events':[dict(r) for r in c.execute('select * from stock_events order by created desc limit 200')],
        'returns':returns,'collections':[dict(r) for r in c.execute('select * from collections')], 'low_stock':lows,
        'report':all_time,'reports':{'month':report_month,'six_months':report_six,'year':report_year},
        'business_health':{'stock_cost_value':stock_cost,'stock_retail_value':stock_retail,
            'low_stock_variants':len(lows),'active_products':sum(1 for p in products if p['active']),
            'order_statuses':status_counts,'cash_recorded':cash_recorded,'refunds_pending':refunds_pending}}
