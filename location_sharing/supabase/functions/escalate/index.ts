// Escalation Edge Function: add Layer N contacts to incident_access.
// Accepts incident_id and layer (1, 2, or 3). Contacts see incidents when they open the app
// based on incident_access (no push). Time-based: Layer 1 on create, Layer 2 at +10 min, Layer 3 at +20 min.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
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
      return new Response(JSON.stringify({ ok: true, notified: 0 }), {
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
    const toAdd = contactIds.filter((id) => !existingIds.has(id));

    for (const contactUserId of toAdd) {
      await supabase.from('incident_access').upsert({
        incident_id,
        contact_user_id: contactUserId,
        layer,
        notified_at: new Date().toISOString(),
      }, { onConflict: 'incident_id,contact_user_id' });
    }

    return new Response(
      JSON.stringify({ ok: true, notified: toAdd.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
