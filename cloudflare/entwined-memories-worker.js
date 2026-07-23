const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    if (url.pathname === '/' || url.pathname === '/health') {
      return json({ ok: true, service: 'entwined-memories-worker' });
    }

    if (url.pathname === '/token' && request.method === 'POST') {
      try {
        const response = await fetch('https://oauth2.googleapis.com/token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({
            client_id: env.YOUTUBE_CLIENT_ID,
            client_secret: env.YOUTUBE_CLIENT_SECRET,
            refresh_token: env.YOUTUBE_REFRESH_TOKEN,
            grant_type: 'refresh_token',
          }),
        });

        const data = await response.json();
        if (response.ok && typeof data.access_token === 'string' &&
            data.access_token.length > 0) {
          return json({
            access_token: data.access_token,
            token_type: data.token_type ?? 'Bearer',
            expires_in: data.expires_in ?? null,
          });
        }

        // Preserve Google's error code without returning any secret values.
        return json({
          error: 'Token refresh failed',
          code: data.error ?? 'oauth_token_error',
          error_description: data.error_description ?? 'Google OAuth rejected the refresh request',
        }, response.status >= 400 ? response.status : 502);
      } catch (error) {
        return json({
          error: 'Token refresh request failed',
          code: 'oauth_request_failed',
          error_description: error instanceof Error ? error.message : 'Unknown OAuth error',
        }, 502);
      }
    }

    return json({ error: 'Not found' }, 404);
  },
};