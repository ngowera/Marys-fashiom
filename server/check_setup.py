"""Report configuration presence, never credential values."""
import os
from config import ROOT, public_settings
print('Environment file:', 'present' if (ROOT/'.env').is_file() else 'missing')
for group, keys in {
    'Supabase': ['SUPABASE_URL','SUPABASE_PUBLISHABLE_KEY','SUPABASE_SERVICE_ROLE_KEY'],
    'PayChangu': ['PAYCHANGU_SECRET_KEY','PAYCHANGU_WEBHOOK_SECRET','PUBLIC_BASE_URL'],
    'Shop information': ['SHOP_CONTACT','DELIVERY_AREAS','PICKUP_LOCATION','RETURNS_POLICY'],
}.items():
    missing=[key for key in keys if not os.environ.get(key)]
    print(group+': '+('missing '+', '.join(missing) if missing else 'values present (not connection verification)'))
print('Shop rules confirmed:',public_settings()['rules_confirmed'])
print('Storage: local SQLite. Supabase deployment and payment integration are still pending.')
