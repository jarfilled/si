import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const resendApiKey = Deno.env.get('RESEND_API_KEY');
  const fromEmail = Deno.env.get('RESEND_FROM_EMAIL');

  if (!supabaseUrl || !anonKey || !serviceRoleKey || !resendApiKey || !fromEmail) {
    return new Response(
      JSON.stringify({ error: 'Email service is not configured.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(
      JSON.stringify({ error: 'Authentication required.' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userError } = await userClient.auth.getUser();

  if (userError || !user) {
    return new Response(
      JSON.stringify({ error: 'Invalid authentication.' }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const payload = await req.json().catch(() => null);
  const date = typeof payload?.date === 'string' ? payload.date : '';
  const mood = Number(payload?.mood);
  const pain = Number(payload?.pain);

  if (!date || !Number.isInteger(mood) || mood < 1 || mood > 5 ||
      !Number.isInteger(pain) || pain < 0 || pain > 10) {
    return new Response(
      JSON.stringify({ error: 'Invalid report data.' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: profile, error: profileError } = await admin
    .from('womens_health_profiles')
    .select('share_daily_mood_pain_enabled')
    .eq('user_id', user.id)
    .maybeSingle();

  if (profileError) {
    return new Response(
      JSON.stringify({ error: profileError.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  if (profile?.share_daily_mood_pain_enabled !== true) {
    return new Response(
      JSON.stringify({ sent: 0, reason: 'disabled' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const { data: contacts, error: contactsError } = await admin
    .from('womens_health_share_contacts')
    .select('name,email')
    .eq('user_id', user.id)
    .eq('enabled', true)
    .order('created_at', { ascending: true });

  if (contactsError) {
    return new Response(
      JSON.stringify({ error: contactsError.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const recipients = (contacts ?? [])
    .map((contact) => ({
      name: String(contact.name ?? '').trim(),
      email: String(contact.email ?? '').trim(),
    }))
    .filter((contact) => contact.email.length > 0);

  if (recipients.length === 0) {
    return new Response(
      JSON.stringify({ sent: 0, reason: 'no_contacts' }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  const subject = 'گزارش روزانه خلق‌وخو و درد';
  const text = [
    `گزارش ثبت‌شده برای تاریخ ${date}`,
    '',
    `خلق‌وخو: ${mood} از ۵`,
    `شدت درد: ${pain} از ۱۰`,
    '',
    'این گزارش با فعال بودن اشتراک‌گذاری روزانه در برنامه «سی» ارسال شده است.',
  ].join('\n');

  let sent = 0;
  const failures: string[] = [];

  for (const recipient of recipients) {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [recipient.email],
        subject,
        text,
      }),
    });

    if (response.ok) {
      sent += 1;
    } else {
      const errorBody = await response.text();
      failures.push(`${recipient.email}: ${errorBody}`);
    }
  }

  return new Response(
    JSON.stringify({
      sent,
      failed: failures.length,
    }),
    {
      status: sent > 0 || failures.length === 0 ? 200 : 502,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    },
  );
});
