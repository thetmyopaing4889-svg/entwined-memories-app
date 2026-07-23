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

async function requestGoogleAccessToken(env) {
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
  return { response, data };
}

function tokenErrorResponse(response, data) {
  return json({
    error: 'Token refresh failed',
    code: data.error ?? 'oauth_token_error',
    error_description:
        data.error_description ?? 'Google OAuth rejected the refresh request',
  }, response.status >= 400 ? response.status : 502);
}

function processingStatusFromYouTube(data) {
  const item = Array.isArray(data.items) ? data.items[0] : null;
  if (!item) return 'failed';

  const processingStatus = item.processingDetails?.processingStatus;
  const uploadStatus = item.status?.uploadStatus;

  if (processingStatus === 'succeeded' || uploadStatus === 'processed') {
    return 'succeeded';
  }
  if (processingStatus === 'failed' ||
      processingStatus === 'terminated' ||
      uploadStatus === 'failed' ||
      uploadStatus === 'rejected') {
    return 'failed';
  }
  return 'processing';
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
        const { response, data } = await requestGoogleAccessToken(env);
        if (response.ok && typeof data.access_token === 'string' &&
            data.access_token.length > 0) {
          return json({
            access_token: data.access_token,
            token_type: data.token_type ?? 'Bearer',
            expires_in: data.expires_in ?? null,
          });
        }

        // Preserve Google's error code without returning any secret values.
        return tokenErrorResponse(response, data);
      } catch (error) {
        return json({
          error: 'Token refresh request failed',
          code: 'oauth_request_failed',
          error_description: error instanceof Error ? error.message : 'Unknown OAuth error',
        }, 502);
      }
    }

    if (url.pathname === '/video-status' && request.method === 'POST') {
      try {
        let body;
        try {
          body = await request.json();
        } catch (_) {
          return json({
            error: 'Invalid request body',
            code: 'invalid_json',
            error_description: 'Request body must be valid JSON',
          }, 400);
        }

        const videoId = typeof body?.videoId === 'string'
            ? body.videoId.trim()
            : '';
        if (!/^[A-Za-z0-9_-]{6,20}$/.test(videoId)) {
          return json({
            error: 'Invalid video ID',
            code: 'invalid_video_id',
            error_description: 'A valid YouTube video ID is required',
          }, 400);
        }

        const { response: tokenResponse, data: tokenData } =
            await requestGoogleAccessToken(env);
        if (!tokenResponse.ok ||
            typeof tokenData.access_token !== 'string' ||
            tokenData.access_token.length === 0) {
          return tokenErrorResponse(tokenResponse, tokenData);
        }

        const youtubeUrl = new URL(
            'https://www.googleapis.com/youtube/v3/videos');
        youtubeUrl.searchParams.set('part', 'processingDetails,status');
        youtubeUrl.searchParams.set('id', videoId);

        const youtubeResponse = await fetch(youtubeUrl, {
          headers: {
            Authorization: `Bearer ${tokenData.access_token}`,
            Accept: 'application/json',
          },
        });
        const youtubeData = await youtubeResponse.json();

        if (!youtubeResponse.ok) {
          const insufficientScope =
              youtubeData.error?.errors?.some(
                  (error) => error.reason === 'insufficientPermissions');
          return json({
            error: 'YouTube status lookup failed',
            code: insufficientScope
                ? 'youtube_status_scope_missing'
                : 'youtube_api_error',
            error_description: youtubeData.error?.message ??
                'YouTube rejected the status request',
          }, youtubeResponse.status >= 400 ? youtubeResponse.status : 502);
        }

        return json({
          videoId,
          processingStatus: processingStatusFromYouTube(youtubeData),
        });
      } catch (error) {
        return json({
          error: 'Video status request failed',
          code: 'video_status_request_failed',
          error_description:
              error instanceof Error ? error.message : 'Unknown error',
        }, 502);
      }
    }

    return json({ error: 'Not found' }, 404);
  },
};