// Escalation Edge Function: add Layer N contacts to incident_access, send FCM push, and email.
// Accepts incident_id and layer (1, 2, or 3).
// Sends FCM push to contacts (requires FIREBASE_SERVICE_ACCOUNT and FIREBASE_PROJECT_ID).
// Sends email via Resend (optional: set RESEND_API_KEY).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import * as jose from 'https://deno.land/x/jose@v5.2.0/index.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface FirebaseServiceAccount {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
}

async function getGoogleAccessToken(serviceAccountJson: string): Promise<string | null> {
  try {
    const sa = JSON.parse(serviceAccountJson) as FirebaseServiceAccount;
    const now = Math.floor(Date.now() / 1000);
    const jwt = await new jose.SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuer(sa.client_email)
      .setAudience('https://oauth2.googleapis.com/token')
      .setIssuedAt(now)
      .setExpirationTime(now + 3600)
      .sign(await jose.importPKCS8(sa.private_key.replace(/\\n/g, '\n'), 'RS256'));

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });
    const data = await res.json();
    return data.access_token ?? null;
  } catch {
    return null;
  }
}

async function sendFcmPush(
  token: string,
  incidentId: string,
  subjectDisplayName: string,
  projectId: string,
  accessToken: string,
): Promise<boolean> {
  try {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title: `Emergency: ${subjectDisplayName} needs help`,
            body: 'Tap to view their location and help.',
          },
          data: {
            incident_id: String(incidentId),
            click_action: `location-sharing://incidents/${incidentId}`,
          },
          android: {
            priority: 'high',
            notification: { channelId: 'incident_emergency', priority: 'max' },
          },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
          },
        },
      }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

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
      return new Response(JSON.stringify({ ok: true, notified: 0, pushSent: 0, emailsSent: 0 }), {
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

    // Fetch subject display name for push/email
    const { data: subjectProfile } = await supabase
      .from('profiles')
      .select('display_name')
      .eq('id', subjectId)
      .single();
    const subjectDisplayName = (subjectProfile?.display_name?.trim() || 'Someone') as string;

    // Send FCM push to contacts
    let pushSent = 0;
    const firebaseSa = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID');
    if (firebaseSa && firebaseProjectId && toNotify.length > 0) {
      const accessToken = await getGoogleAccessToken(firebaseSa);
      if (accessToken) {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('id, fcm_token, display_name')
          .in('id', toNotify);
        for (const p of profiles ?? []) {
          const token = p.fcm_token;
          if (token && typeof token === 'string' && token.length > 0) {
            if (await sendFcmPush(token, incident_id, subjectDisplayName, firebaseProjectId, accessToken)) {
              pushSent++;
            }
          }
        }
      }
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
      JSON.stringify({ ok: true, notified: toNotify.length, pushSent, emailsSent }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
