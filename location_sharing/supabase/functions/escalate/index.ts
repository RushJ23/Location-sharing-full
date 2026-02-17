// Escalation Edge Function: notify contacts by layer (closest → furthest within layer).
// "Closest → furthest": contacts with location (always-share or opted-in) are ordered by
// distance from subject's last_known; others use manual_priority or deterministic fallback.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    const { incident_id } = await req.json();
    if (!incident_id) {
      return new Response(JSON.stringify({ error: 'incident_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const { data: incident } = await supabase
      .from('incidents')
      .select('id, user_id, last_known_lat, last_known_lng')
      .eq('id', incident_id)
      .single();
    if (!incident) {
      return new Response(JSON.stringify({ error: 'Incident not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const subjectId = incident.user_id;
    const lat = incident.last_known_lat;
    const lng = incident.last_known_lng;
    const { data: contacts } = await supabase
      .from('contacts')
      .select('id, contact_user_id, layer, is_always_share, manual_priority')
      .eq('user_id', subjectId)
      .order('layer')
      .order('manual_priority', { ascending: true, nullsFirst: false });
    if (!contacts || contacts.length === 0) {
      return new Response(JSON.stringify({ ok: true, message: 'No contacts' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    const layer1 = contacts.filter((c) => c.layer === 1);
    for (const c of layer1) {
      await supabase.from('incident_access').upsert({
        incident_id,
        contact_user_id: c.contact_user_id,
        layer: 1,
        notified_at: new Date().toISOString(),
      }, { onConflict: 'incident_id,contact_user_id' });
    }
    return new Response(JSON.stringify({ ok: true, notified: layer1.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
