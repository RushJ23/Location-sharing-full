// Escalation Edge Function: add Layer N contacts to incident_access.
// Accepts incident_id and layer (1, 2, or 3). Contacts see incidents when they open the app
// based on incident_access (no push). Time-based: Layer 1 on create, Layer 2 at +10 min, Layer 3 at +20 min.
// Contacts within each layer are ordered closest-first using haversine distance from the subject.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const origin = Deno.env.get('SUPABASE_URL') ?? '*';
const corsHeaders = {
  'Access-Control-Allow-Origin': origin,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
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
    const body = await req.json().catch(() => ({}));
    const incident_id = body.incident_id;
    const layer = body.layer ?? 1;
    if (!incident_id) {
      return new Response(JSON.stringify({ error: 'incident_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Fetch incident — also get last_known position for fallback
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

    // --- Resolve subject position (closest-first ordering) ---
    // Step 1: try always_share_locations (most recent live position)
    let subjectLat: number | null = null;
    let subjectLng: number | null = null;

    const { data: subjectLoc } = await supabase
      .from('always_share_locations')
      .select('lat, lng')
      .eq('user_id', subjectId)
      .maybeSingle();

    if (subjectLoc && subjectLoc.lat != null && subjectLoc.lng != null) {
      subjectLat = subjectLoc.lat as number;
      subjectLng = subjectLoc.lng as number;
    } else if (
      incident.last_known_lat != null &&
      incident.last_known_lng != null
    ) {
      // Step 2: fall back to last_known_lat/lng on the incident row
      subjectLat = incident.last_known_lat as number;
      subjectLng = incident.last_known_lng as number;
    }
    // Step 3: if neither is available, subjectLat/subjectLng remain null → fallback sort

    // --- Fetch Layer N contacts (with manual_priority and created_at for fallback sort) ---
    const { data: contacts } = await supabase
      .from('contacts')
      .select('contact_user_id, manual_priority, created_at')
      .eq('user_id', subjectId)
      .eq('layer', layer);

    if (!contacts || contacts.length === 0) {
      return new Response(JSON.stringify({ ok: true, notified: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const contactIds = contacts.map((c) => c.contact_user_id as string);

    // --- Deduplication: skip contacts already in incident_access ---
    const { data: existing } = await supabase
      .from('incident_access')
      .select('contact_user_id')
      .eq('incident_id', incident_id)
      .in('contact_user_id', contactIds);
    const existingIds = new Set((existing ?? []).map((r) => r.contact_user_id as string));
    const toAdd = contacts.filter((c) => !existingIds.has(c.contact_user_id as string));

    if (toAdd.length === 0) {
      return new Response(JSON.stringify({ ok: true, notified: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // --- Fetch positions for all contacts to insert in a single query ---
    const toAddIds = toAdd.map((c) => c.contact_user_id as string);
    const { data: contactLocs } = await supabase
      .from('always_share_locations')
      .select('user_id, lat, lng')
      .in('user_id', toAddIds);

    const locByContact = new Map<string, { lat: number; lng: number }>();
    for (const loc of contactLocs ?? []) {
      if (loc.lat != null && loc.lng != null) {
        locByContact.set(loc.user_id as string, {
          lat: loc.lat as number,
          lng: loc.lng as number,
        });
      }
    }

    // --- Sort contacts: Group A (known position, closest first) then Group B (no position, manual_priority ASC nulls-last, created_at ASC) ---
    type ContactRow = { contact_user_id: string; manual_priority: number | null; created_at: string };

    const groupA: Array<ContactRow & { distKm: number }> = [];
    const groupB: ContactRow[] = [];

    for (const c of toAdd) {
      const cRow = c as ContactRow;
      const cLoc = locByContact.get(cRow.contact_user_id);
      if (subjectLat != null && subjectLng != null && cLoc) {
        groupA.push({
          ...cRow,
          distKm: haversineKm(subjectLat, subjectLng, cLoc.lat, cLoc.lng),
        });
      } else {
        groupB.push(cRow);
      }
    }

    // Group A: ascending by haversine distance
    groupA.sort((a, b) => a.distKm - b.distKm);

    // Group B: manual_priority ASC (nulls last), then created_at ASC
    groupB.sort((a, b) => {
      const pA = a.manual_priority;
      const pB = b.manual_priority;
      if (pA == null && pB == null) {
        return a.created_at < b.created_at ? -1 : a.created_at > b.created_at ? 1 : 0;
      }
      if (pA == null) return 1;
      if (pB == null) return -1;
      if (pA !== pB) return pA - pB;
      return a.created_at < b.created_at ? -1 : a.created_at > b.created_at ? 1 : 0;
    });

    const ordered: ContactRow[] = [...groupA, ...groupB];

    // --- Insert incident_access rows in priority order ---
    const notifiedAt = new Date().toISOString();
    for (const contact of ordered) {
      await supabase.from('incident_access').upsert({
        incident_id,
        contact_user_id: contact.contact_user_id,
        layer,
        notified_at: notifiedAt,
      }, { onConflict: 'incident_id,contact_user_id' });
    }

    return new Response(
      JSON.stringify({ ok: true, notified: ordered.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
