const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const paychanguSecret = Deno.env.get('PAYCHANGU_SECRET_KEY')!;
const webhookSecret = Deno.env.get('PAYCHANGU_WEBHOOK_SECRET')!;
const publicBaseUrl = (Deno.env.get('PUBLIC_BASE_URL') ?? '').replace(/\/$/, '');
const paychanguApi = 'https://api.paychangu.com';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

async function rpc(name: string, args: Record<string, unknown>) {
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(args),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.message ?? 'Database operation failed');
  return body;
}

async function updatePaymentMethod(txRef: string, method: string) {
  await fetch(`${supabaseUrl}/rest/v1/payment_transactions?tx_ref=eq.${encodeURIComponent(txRef)}`, {
    method: 'PATCH',
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify({ payment_method: method }),
  });
}

async function verify(txRef: string) {
  const response = await fetch(`${paychanguApi}/verify-payment/${encodeURIComponent(txRef)}`, {
    headers: { Accept: 'application/json', Authorization: `Bearer ${paychanguSecret}` },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || body.status !== 'success' || !body.data) {
    throw new Error(body.message ?? 'Unable to verify PayChangu payment');
  }
  return body.data;
}

async function settle(txRef: string) {
  const payment = await verify(txRef);
  return rpc('settle_paychangu_payment_details', {
    p_tx_ref: txRef,
    p_provider_reference: payment.reference ?? payment.charge_id ?? txRef,
    p_amount: Number(payment.amount ?? 0),
    p_status: payment.status === 'success' ? 'success' : 'failed',
    p_payment_method: payment.meta?.payment_method ?? payment.customization?.payment_method ?? '',
    p_channel: payment.authorization?.channel ?? '',
    p_provider_type: payment.type ?? '',
    p_provider_mode: payment.mode ?? '',
    p_provider_charges: Number(payment.charges ?? 0),
    p_completed_at: payment.authorization?.completed_at ?? null,
  });
}

async function storedReturnUrl(txRef: string) {
  const response = await fetch(
    `${supabaseUrl}/rest/v1/payment_transactions?select=return_url&tx_ref=eq.${encodeURIComponent(txRef)}&limit=1`,
    { headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}` } },
  );
  const rows = await response.json();
  if (!response.ok || !rows.length) throw new Error('Payment session not found');
  return rows[0].return_url as string;
}

async function initiate(body: Record<string, unknown>) {
  if (!publicBaseUrl) {
    return json({ error: 'Payment service is not configured' }, 503);
  }
  const orderId = String(body.order_id ?? '');
  const token = String(body.token ?? '');
  const returnUrl = String(body.return_url ?? '');
  if (!orderId || !token || !returnUrl || !returnUrl.startsWith(publicBaseUrl)) {
    return json({ error: 'Invalid payment session' }, 400);
  }
  const txRef = `MF-${crypto.randomUUID()}`;
  const order = await rpc('begin_paychangu_payment', {
    p_order_id: orderId,
    p_token: token,
    p_tx_ref: txRef,
    p_return_url: returnUrl,
  });
  await updatePaymentMethod(txRef, String(body.payment_method ?? 'Airtel Money'));
  const names = String(order.customer).trim().split(/\s+/);
  const paymentResponse = await fetch(`${paychanguApi}/payment`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${paychanguSecret}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount: String(order.amount),
      currency: 'MWK',
      tx_ref: txRef,
      first_name: names.shift() ?? 'Customer',
      last_name: names.join(' '),
      callback_url: `${supabaseUrl}/functions/v1/paychangu/callback`,
      return_url: returnUrl,
      customization: { title: 'Mary’s Fashion', description: `Order ${orderId}` },
      meta: { order_id: orderId, payment_method: String(body.payment_method ?? 'Airtel Money') },
    }),
  });
  const payment = await paymentResponse.json().catch(() => ({}));
  if (!paymentResponse.ok || payment.status !== 'success' || !payment.data?.checkout_url) {
    await rpc('settle_paychangu_payment', {
      p_tx_ref: txRef,
      p_provider_reference: null,
      p_amount: 0,
      p_status: 'failed',
    }).catch(() => undefined);
    throw new Error(payment.message ?? 'Unable to start PayChangu checkout');
  }
  return json({ tx_ref: txRef, checkout_url: payment.data.checkout_url, status: 'pending' });
}

async function status(body: Record<string, unknown>) {
  return json(await rpc('paychangu_payment_status', {
    p_order_id: String(body.order_id ?? ''),
    p_token: String(body.token ?? ''),
  }));
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const url = new URL(request.url);
  try {
    if (url.pathname.endsWith('/callback')) {
      const txRef = url.searchParams.get('tx_ref') ?? '';
      if (!txRef) return new Response('Missing transaction reference', { status: 400 });
      const outcome = await settle(txRef);
      const returnUrl = await storedReturnUrl(txRef);
      const redirect = new URL(returnUrl);
      redirect.searchParams.set('tx_ref', txRef);
      redirect.searchParams.set('payment_status', outcome.status ?? 'failed');
      return Response.redirect(redirect, 303);
    }
    if (url.pathname.endsWith('/webhook')) {
      const raw = await request.text();
      const signature = request.headers.get('Signature') ?? '';
      const key = await crypto.subtle.importKey(
        'raw', new TextEncoder().encode(webhookSecret),
        { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
      );
      const digest = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(raw));
      const expected = [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, '0')).join('');
      if (signature.toLowerCase() !== expected) return new Response('Invalid signature', { status: 401 });
      const payload = JSON.parse(raw);
      if (payload.tx_ref) await settle(payload.tx_ref);
      return new Response('ok', { status: 200 });
    }
    if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405);
    const body = await request.json();
    return body.action === 'status' ? await status(body) : await initiate(body);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Payment failed' }, 400);
  }
});
