// Expire pending safety checks: create incidents and notify Layer 1.
// Invoke via cron (external or Supabase) every 1-2 minutes.
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

    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const escalateUrl = `${supabaseUrl}/functions/v1/escalate`;
    let processed = 0;

    const { data: expired } = await supabase
      .from('pending_safety_checks')
      .select('id, user_id, schedule_id')
      .lte('expires_at', new Date().toISOString())
      .is('responded_at', null);

    const expiredList = expired ?? [];
    for (const row of expiredList) {
      const userId = row.user_id;

      const { data: samples } = await supabase
        .from('user_location_samples')
        .select('lat, lng, timestamp')
        .eq('user_id', userId)
        .order('timestamp', { ascending: true });

      const samplesList = samples ?? [];
      const lastSample = samplesList.length > 0 ? samplesList[samplesList.length - 1] : null;
      const lat = lastSample ? (lastSample.lat as number) : null;
      const lng = lastSample ? (lastSample.lng as number) : null;

      const { data: incident, error: incErr } = await supabase
        .from('incidents')
        .insert({
          user_id: userId,
          status: 'active',
          trigger: 'curfew_timeout',
          last_known_lat: lat,
          last_known_lng: lng,
        })
        .select('id')
        .single();

      if (incErr || !incident) continue;

      for (const s of samplesList) {
        await supabase.from('incident_location_history').insert({
          incident_id: incident.id,
          lat: s.lat,
          lng: s.lng,
          timestamp: (s as { timestamp: string }).timestamp,
        });
      }

      const { data: layer1 } = await supabase
        .from('contacts')
        .select('contact_user_id')
        .eq('user_id', userId)
        .eq('layer', 1);

      for (const c of layer1 ?? []) {
        await supabase.from('incident_access').upsert({
          incident_id: incident.id,
          contact_user_id: c.contact_user_id,
          layer: 1,
          notified_at: new Date().toISOString(),
        }, { onConflict: 'incident_id,contact_user_id' });
      }

      await supabase
        .from('pending_safety_checks')
        .update({ responded_at: new Date().toISOString() })
        .eq('id', row.id);

      try {
        await fetch(escalateUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${serviceKey}`,
          },
          body: JSON.stringify({ incident_id: incident.id, layer: 1 }),
        });
      } catch (_) {
        // Escalate may fail if notify function not configured
      }
      processed++;
    }

    const nowMs = Date.now();
    const tenMinAgoMs = nowMs - 10 * 60 * 1000;
    const twentyMinAgoMs = nowMs - 20 * 60 * 1000;

    const { data: activeIncidents } = await supabase
      .from('incidents')
      .select('id, created_at')
      .eq('status', 'active');

    const invokeEscalate = async (incidentId: string, layer: number): Promise<boolean> => {
      try {
        const res = await fetch(escalateUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${serviceKey}`,
          },
          body: JSON.stringify({ incident_id: incidentId, layer }),
        });
        return res.ok;
      } catch {
        return false;
      }
    };

    for (const inc of activeIncidents ?? []) {
      const raw = (inc as { created_at?: string }).created_at;
      if (!raw || typeof raw !== 'string') continue;
      // Ensure UTC parsing. PostgREST returns "2026-02-19 23:36:58.384268+00" (short
      // TZ) or "2026-02-19 23:00:00" (none). Only append Z when there's no TZ - our
      // previous regex missed "+00" and produced invalid "+00Z", causing NaN/skip.
      const hasTz = /[Zz]|[+-]\d{1,2}(:?\d{2})?$/.test(raw);
      const utcStr = hasTz ? raw : raw.replace(' ', 'T') + 'Z';
      const createdMs = new Date(utcStr).getTime();
      if (Number.isNaN(createdMs)) continue;
      if (createdMs <= twentyMinAgoMs) {
        await invokeEscalate(inc.id, 2);
        await invokeEscalate(inc.id, 3);
      } else if (createdMs <= tenMinAgoMs) {
        await invokeEscalate(inc.id, 2);
      }
    }

    return new Response(JSON.stringify({ ok: true, processed }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
