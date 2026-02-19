// Escalation Edge Function: add Layer N contacts to incident_access and send email.
// Accepts incident_id and layer (1, 2, or 3).
// Sends email to contact's Supabase signup email via Resend (optional: set RESEND_API_KEY).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

async function sendEmail(to: string, incidentId: string, supabaseUrl: string): Promise<boolean> {
  const apiKey = Deno.env.get('RESEND_API_KEY');
  if (!apiKey) return false;
  const incidentUrl = `${supabaseUrl.replace('.supabase.co', '')}/project/_/auth/redirect?redirect_to=location-sharing://incidents/${incidentId}`;
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: Deno.env.get('RESEND_FROM') ?? 'Location Sharing <onboarding@resend.dev>',
      to: [to],
      subject: 'Emergency: Someone needs help',
      html: `<p>Someone you know has triggered an emergency alert. Open the Location Sharing app to view their location and last 12h history.</p><p>Incident ID: ${incidentId}</p>`,
    }),
  });
  return res.ok;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const body = await req.json().catch(() => ({}));
    const incident_id = body.incident_id;
    const layer = body.layer ?? 1;
    if (!incident_id) {
      return new Response(JSON.stringify({ error: 'incident_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const { data: incident } = await supabase
      .from('incidents')
      .select('id, user_id')
      .eq('id', incident_id)
      .single();
    if (!incident) {
      return new Response(JSON.stringify({ error: 'Incident not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const subjectId = incident.user_id;
    const { data: contacts } = await supabase
      .from('contacts')
      .select('contact_user_id')
      .eq('user_id', subjectId)
      .eq('layer', layer);
    if (!contacts || contacts.length === 0) {
      return new Response(JSON.stringify({ ok: true, notified: 0, emailsSent: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const contactIds = contacts.map((c) => c.contact_user_id);
    const { data: existing } = await supabase
      .from('incident_access')
      .select('contact_user_id')
      .eq('incident_id', incident_id)
      .in('contact_user_id', contactIds);
    const existingIds = new Set((existing ?? []).map((r) => r.contact_user_id));
    const toNotify = contactIds.filter((id) => !existingIds.has(id));

    for (const contactUserId of toNotify) {
      await supabase.from('incident_access').upsert({
        incident_id,
        contact_user_id: contactUserId,
        layer,
        notified_at: new Date().toISOString(),
      }, { onConflict: 'incident_id,contact_user_id' });
    }

    let emailsSent = 0;
    for (const contactUserId of toNotify) {
      try {
        const { data } = await supabase.auth.admin.getUserById(contactUserId);
        const email = data?.user?.email;
        if (email && await sendEmail(email, incident_id, supabaseUrl)) {
          emailsSent++;
        }
      } catch (_) {
        // Skip failed email
      }
    }

    return new Response(
      JSON.stringify({ ok: true, notified: toNotify.length, emailsSent }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
