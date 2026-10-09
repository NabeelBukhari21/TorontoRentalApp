// ============================================================================
//  RentOS — Edge Function: send-push
// ============================================================================
//  Drains the notification queue to APNs.
//
//  Invoked on a schedule (pg_cron, every ~30s) rather than per-insert. A
//  trigger calling out to APNs would hold a database transaction open across
//  a network round trip — the single fastest way to exhaust a connection pool
//  under load.
//
//  Three properties worth noting:
//
//   • It sends only rows where `delivered_push = false`. The `emit_notification`
//     function already applied preferences, mutes and quiet hours, so anything
//     suppressed was written as already-delivered and never appears here.
//   • The payload carries the notification **id**, not its content, so a push
//     tapped three days later opens the current state rather than a stale copy.
//   • A 410 from APNs prunes the token. Devices are replaced constantly and a
//     token table that only grows eventually sends more failures than pushes.
//
//  Deploy:  supabase functions deploy send-push
//  Secrets: APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, APNS_PRIVATE_KEY (p8)
//  Schedule:
//    select cron.schedule('send-push', '*/1 * * * *', $$
//      select net.http_post(
//        url := 'https://<ref>.functions.supabase.co/send-push',
//        headers := '{"Authorization":"Bearer <service-role>"}'::jsonb
//      );
//    $$);
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const APNS_HOST_PROD = "https://api.push.apple.com";
const APNS_HOST_SANDBOX = "https://api.sandbox.push.apple.com";
const BATCH_SIZE = 100;

interface NotificationRow {
  id: string;
  recipient_user_id: string;
  category: string;
  priority: string;
  title: string;
  body: string;
  deep_link: string | null;
  group_key: string | null;
}

interface TokenRow {
  token: string;
  platform: string;
  user_id: string;
}

// ── APNs auth ───────────────────────────────────────────────────────────────
// A JWT signed with the p8 key, valid for up to an hour. Cached because APNs
// rate-limits token generation and rejects a burst of fresh ones.

let cachedToken: { jwt: string; issuedAt: number } | null = null;

async function apnsToken(): Promise<string> {
  const now = Date.now();
  if (cachedToken && now - cachedToken.issuedAt < 40 * 60 * 1000) {
    return cachedToken.jwt;
  }

  const keyID = Deno.env.get("APNS_KEY_ID")!;
  const teamID = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_PRIVATE_KEY")!;

  const der = Uint8Array.from(
    atob(pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "").replace(/\s/g, "")),
    (c) => c.charCodeAt(0),
  );
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const jwt = await create(
    { alg: "ES256", kid: keyID },
    { iss: teamID, iat: getNumericDate(0) },
    key,
  );

  cachedToken = { jwt, issuedAt: now };
  return jwt;
}

// ── Payload ─────────────────────────────────────────────────────────────────
// Mirrors `PushPayload` in Swift. A key changed here without changing it
// there breaks tapping, silently, in production.

function buildPayload(note: NotificationRow) {
  const isCritical = note.priority === "critical";

  return {
    aps: {
      alert: { title: note.title, body: note.body },
      sound: isCritical ? "default" : undefined,
      badge: undefined, // set per-device below
      "thread-id": note.group_key ?? note.category,
      category: note.category,
      // `time-sensitive` pierces Focus modes; anything lower waits its turn.
      // Requires the com.apple.developer.usernotifications.time-sensitive
      // entitlement.
      "interruption-level": isCritical ? "time-sensitive" : "active",
      "relevance-score": isCritical ? 1.0 : 0.5,
      "mutable-content": 1,
    },
    notification_id: note.id,
    category: note.category,
    priority: note.priority,
    deep_link: note.deep_link,
    group_key: note.group_key,
  };
}

async function sendOne(
  token: TokenRow,
  note: NotificationRow,
  jwt: string,
  bundleID: string,
  badge: number,
): Promise<"sent" | "expired" | "failed"> {
  const host = token.platform === "ios_sandbox" ? APNS_HOST_SANDBOX : APNS_HOST_PROD;
  const payload = buildPayload(note);
  payload.aps.badge = badge;

  const response = await fetch(`${host}/3/device/${token.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleID,
      "apns-push-type": "alert",
      // Collapsing on the group key means a burst of replies replaces the
      // previous banner instead of stacking nine of them on the lock screen.
      "apns-collapse-id": (note.group_key ?? note.id).slice(0, 64),
      "apns-priority": note.priority === "critical" ? "10" : "5",
    },
    body: JSON.stringify(payload),
  });

  if (response.ok) return "sent";
  // 410 Gone, or 400 BadDeviceToken: the device is no longer reachable.
  if (response.status === 410) return "expired";
  const detail = await response.json().catch(() => ({}));
  if (detail?.reason === "BadDeviceToken" || detail?.reason === "Unregistered") {
    return "expired";
  }
  return "failed";
}

Deno.serve(async () => {
  try {
    // Service role: this runs unattended and must read rows across every
    // organization. It is the one place that legitimately bypasses RLS, which
    // is why it lives server-side and is never callable by a client.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: pending } = await supabase
      .from("notifications")
      .select("id, recipient_user_id, category, priority, title, body, deep_link, group_key")
      .eq("delivered_push", false)
      .is("dismissed_at", null)
      .order("created_at", { ascending: true })
      .limit(BATCH_SIZE);

    const notes = (pending ?? []) as NotificationRow[];
    if (notes.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const recipients = [...new Set(notes.map((n) => n.recipient_user_id))];

    const { data: tokenRows } = await supabase
      .from("device_tokens")
      .select("token, platform, user_id")
      .in("user_id", recipients);

    const tokensByUser = new Map<string, TokenRow[]>();
    for (const row of (tokenRows ?? []) as TokenRow[]) {
      const list = tokensByUser.get(row.user_id) ?? [];
      list.push(row);
      tokensByUser.set(row.user_id, list);
    }

    // Badge is per-recipient, not per-notification: it is the unread total,
    // so it has to be counted once per user rather than incremented per push.
    const badges = new Map<string, number>();
    for (const userID of recipients) {
      const { count } = await supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("recipient_user_id", userID)
        .is("read_at", null)
        .is("dismissed_at", null);
      badges.set(userID, count ?? 0);
    }

    const jwt = await apnsToken();
    const bundleID = Deno.env.get("APNS_BUNDLE_ID")!;

    let sent = 0;
    const expiredTokens: string[] = [];
    const deliveredIDs: string[] = [];

    for (const note of notes) {
      const tokens = tokensByUser.get(note.recipient_user_id) ?? [];

      // No device is not a failure. Mark it delivered so it does not sit in
      // the queue forever — the notification centre still has it.
      if (tokens.length === 0) {
        deliveredIDs.push(note.id);
        continue;
      }

      const results = await Promise.all(
        tokens.map((t) =>
          sendOne(t, note, jwt, bundleID, badges.get(note.recipient_user_id) ?? 0)
            .then((outcome) => {
              if (outcome === "expired") expiredTokens.push(t.token);
              return outcome;
            })
            .catch(() => "failed" as const)
        ),
      );

      // Delivered if it reached at least one device. A user with a dead iPad
      // and a working iPhone has been notified.
      if (results.some((r) => r === "sent")) {
        sent += 1;
        deliveredIDs.push(note.id);
      } else if (results.every((r) => r === "expired")) {
        // Every device is gone; retrying achieves nothing.
        deliveredIDs.push(note.id);
      }
      // Otherwise leave it queued for the next run.
    }

    if (deliveredIDs.length > 0) {
      await supabase
        .from("notifications")
        .update({ delivered_push: true, pushed_at: new Date().toISOString() })
        .in("id", deliveredIDs);
    }

    if (expiredTokens.length > 0) {
      await supabase.from("device_tokens").delete().in("token", expiredTokens);
    }

    return new Response(
      JSON.stringify({
        sent,
        processed: notes.length,
        pruned_tokens: expiredTokens.length,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
