# PayChangu setup

Apply the payment migration after the existing migrations:

```sh
supabase db push
```

Set the Edge Function secrets. `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by Supabase; set the remaining values yourself:

```sh
supabase secrets set \
  PAYCHANGU_SECRET_KEY="your_paychangu_secret" \
  PAYCHANGU_WEBHOOK_SECRET="your_paychangu_webhook_secret" \
  PUBLIC_BASE_URL="https://marysfashion.afrisoft.store"
```

Use the PayChangu values this way:

| PayChangu value | Where it goes |
| --- | --- |
| Secret key | Supabase Edge Function secret: `PAYCHANGU_SECRET_KEY` |
| Webhook secret | Supabase Edge Function secret: `PAYCHANGU_WEBHOOK_SECRET` |
| Webhook URL | PayChangu dashboard webhook setting, not a Supabase secret |
| Public key | Not used by this hosted Standard Checkout integration; do not add it as a secret |

Deploy the function without JWT verification. The function is intentionally public because customers and PayChangu cannot provide a Supabase user JWT. The function protects payment creation with the order's private tracking token and protects settlement with the PayChangu webhook signature and server-side verification.

```sh
supabase functions deploy paychangu --no-verify-jwt
```

Configure these URLs in the PayChangu dashboard:

- Webhook URL: `https://ywuhtffhqbjxaslbwotn.supabase.co/functions/v1/paychangu/webhook`
- Payment callback URL: generated automatically as `https://ywuhtffhqbjxaslbwotn.supabase.co/functions/v1/paychangu/callback`

The Flutter website calls:

`https://ywuhtffhqbjxaslbwotn.supabase.co/functions/v1/paychangu`

For a successful payment, the function verifies the transaction with PayChangu before marking the Supabase order `Paid`, writing a payment collection, and allowing the website to show the order's tracking code.
