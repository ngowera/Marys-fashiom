"""Server-only configuration. Never bundle .env into Flutter assets."""
import os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def load_env(path=ROOT / '.env'):
    if not path.exists(): return
    for number, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith('#'): continue
        key, sep, value = line.partition('=')
        if not sep or not key.strip().replace('_', '').isalnum():
            raise ValueError(f'Invalid configuration line {number}')
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'": value = value[1:-1]
        os.environ.setdefault(key.strip(), value)
def public_settings():
    def fee(key, default):
        value = int(os.environ.get(key, default))
        if value < 0: raise ValueError(f'{key} must not be negative')
        return value
    return {'brand': 'Mary’s Fashion', 'currency': 'MWK',
        'delivery_fees': {'Pickup': 0, 'Delivery': fee('STANDARD_DELIVERY_MWK', 3000), 'Express': fee('EXPRESS_DELIVERY_MWK', 6000)},
        'delivery_areas': os.environ.get('DELIVERY_AREAS', ''),
        'pickup_location': os.environ.get('PICKUP_LOCATION', ''),
        'contact': os.environ.get('SHOP_CONTACT', ''),
        'returns_policy': os.environ.get('RETURNS_POLICY', ''),
        'rules_confirmed': os.environ.get('SHOP_RULES_CONFIRMED', 'false').lower() == 'true',
        'online_payment_enabled': False}
load_env()
