const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

const FIREBASE_CERTS_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function base64UrlToBytes(value) {
  const padded = value.replace(/-/g, '+').replace(/_/g, '/')
    .padEnd(Math.ceil(value.length / 4) * 4, '=');
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function pemToArrayBuffer(pem) {
  const normalized = pem
    .replace('-----BEGIN CERTIFICATE-----', '')
    .replace('-----END CERTIFICATE-----', '')
    .replace(/\s/g, '');
  const binary = atob(normalized);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0)).buffer;
}

async function importFirebasePublicKey(pem) {
  return crypto.subtle.importKey(
    'spki',
    pemToArrayBuffer(pem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
}

/// Verifies a Firebase ID token with Google public certificates and permits
/// only the one private-family account configured as FAMILY_UID. This ensures
/// media-delete endpoints cannot be called by arbitrary internet clients.
async function requireFamilyUser(request, env) {
  const authorization = request.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    throw new HttpError(401, 'Missing Firebase authorization token');
  }

  const token = authorization.slice('Bearer '.length).trim();
  const parts = token.split('.');
  if (parts.length !== 3) throw new HttpError(401, 'Invalid Firebase token');

  let header;
  let payload;
  try {
    header = JSON.parse(new TextDecoder().decode(base64UrlToBytes(parts[0])));
    payload = JSON.parse(new TextDecoder().decode(base64UrlToBytes(parts[1])));
  } catch (_) {
    throw new HttpError(401, 'Invalid Firebase token encoding');
  }

  const projectId = env.FIREBASE_PROJECT_ID ?? 'entwined-memories-app';
  const nowSeconds = Math.floor(Date.now() / 1000);
  if (header.alg !== 'RS256' || typeof header.kid !== 'string' ||
      payload.aud !== projectId ||
      payload.iss !== `https://securetoken.google.com/${projectId}` ||
      typeof payload.sub !== 'string' || payload.sub.length === 0 ||
      typeof payload.exp !== 'number' || payload.exp <= nowSeconds) {
    throw new HttpError(401, 'Firebase token validation failed');
  }

  let certificates;
  try {
    const response = await fetch(FIREBASE_CERTS_URL);
    if (!response.ok) throw new Error(`Google certificates HTTP ${response.status}`);
    certificates = await response.json();
  } catch (_) {
    throw new HttpError(503, 'Could not verify Firebase token');
  }

  const certificate = certificates[header.kid];
  if (typeof certificate !== 'string') {
    throw new HttpError(401, 'Firebase token signing key is unknown');
  }

  const key = await importFirebasePublicKey(certificate);
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    base64UrlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new HttpError(401, 'Firebase token signature is invalid');

  if (!env.FAMILY_UID || payload.sub !== env.FAMILY_UID) {
    throw new HttpError(403, 'This account is not permitted to delete media');
  }

  return { uid: payload.sub };
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function parseJsonBody(request) {
  try {
    return await request.json();
  } catch (_) {
    throw new HttpError(400, 'Request body must be valid JSON');
  }
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

function cloudinaryPublicIdFromUrl(imageUrl, env) {
  if (typeof imageUrl !== 'string' || imageUrl.length === 0) return null;

  try {
    const url = new URL(imageUrl);
    const cloudName = env.CLOUDINARY_CLOUD_NAME ?? 'txnn5lsu';
    if (url.hostname !== 'res.cloudinary.com') return null;

    const parts = url.pathname.split('/').filter(Boolean);
    if (parts[0] !== cloudName || parts[1] !== 'image' || parts[2] !== 'upload') {
      return null;
    }

    let index = 3;
    if (/^v\d+$/.test(parts[index] ?? '')) index += 1;
    const publicPath = parts.slice(index).map(decodeURIComponent).join('/');
    return publicPath.replace(/\.[A-Za-z0-9]{2,5}$/, '') || null;
  } catch (_) {
    return null;
  }
}

async function sha1Hex(value) {
  const digest = await crypto.subtle.digest(
    'SHA-1', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

async function deleteCloudinaryImage(body, env) {
  if (!env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    throw new HttpError(503, 'Cloudinary cleanup is not configured yet');
  }

  const publicId = typeof body?.imagePublicId === 'string' &&
          body.imagePublicId.trim().length > 0
      ? body.imagePublicId.trim()
      : cloudinaryPublicIdFromUrl(body?.imageUrl, env);
  if (!publicId) {
    throw new HttpError(400, 'A valid Cloudinary image ID is required');
  }

  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = await sha1Hex(
    `public_id=${publicId}&timestamp=${timestamp}${env.CLOUDINARY_API_SECRET}`);
  const cloudName = env.CLOUDINARY_CLOUD_NAME ?? 'txnn5lsu';
  const response = await fetch(
    `https://api.cloudinary.com/v1_1/${cloudName}/image/destroy`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        public_id: publicId,
        timestamp,
        api_key: env.CLOUDINARY_API_KEY,
        signature,
        invalidate: 'true',
      }),
    },
  );
  const data = await response.json();
  if (!response.ok || (data.result !== 'ok' && data.result !== 'not found')) {
    throw new HttpError(502, data.error?.message ?? 'Cloudinary deletion failed');
  }

  return { publicId, result: data.result };
}

async function deleteYouTubeVideo(body, env) {
  const videoId = typeof body?.videoId === 'string' ? body.videoId.trim() : '';
  if (!/^[A-Za-z0-9_-]{6,20}$/.test(videoId)) {
    throw new HttpError(400, 'A valid YouTube video ID is required');
  }

  const { response: tokenResponse, data: tokenData } =
      await requestGoogleAccessToken(env);
  if (!tokenResponse.ok || typeof tokenData.access_token !== 'string' ||
      tokenData.access_token.length === 0) {
    throw new HttpError(
      tokenResponse.status >= 400 ? tokenResponse.status : 502,
      tokenData.error_description ?? 'YouTube authorization failed',
    );
  }

  const endpoint = new URL('https://www.googleapis.com/youtube/v3/videos');
  endpoint.searchParams.set('id', videoId);
  const response = await fetch(endpoint, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${tokenData.access_token}` },
  });

  // The API returns 204 for a deletion. Treat a 404 as idempotent success so a
  // retry after a partial failure can still remove the Firestore document.
  if (response.status !== 204 && response.status !== 404) {
    const data = await response.json().catch(() => ({}));
    throw new HttpError(
      response.status >= 400 ? response.status : 502,
      data.error?.message ?? 'YouTube video deletion failed',
    );
  }

  return { videoId, deleted: response.status === 204 };
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
        const body = await parseJsonBody(request);
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
          const insufficientScope = youtubeData.error?.errors?.some(
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
        if (error instanceof HttpError) {
          return json({ error: error.message }, error.status);
        }
        return json({
          error: 'Video status request failed',
          code: 'video_status_request_failed',
          error_description:
              error instanceof Error ? error.message : 'Unknown error',
        }, 502);
      }
    }

    if (url.pathname === '/delete-image' && request.method === 'POST') {
      try {
        await requireFamilyUser(request, env);
        const body = await parseJsonBody(request);
        const result = await deleteCloudinaryImage(body, env);
        return json({ ok: true, ...result });
      } catch (error) {
        const status = error instanceof HttpError ? error.status : 502;
        return json({
          error: 'Image cleanup failed',
          error_description:
              error instanceof Error ? error.message : 'Unknown error',
        }, status);
      }
    }

    if (url.pathname === '/delete-video' && request.method === 'POST') {
      try {
        await requireFamilyUser(request, env);
        const body = await parseJsonBody(request);
        const result = await deleteYouTubeVideo(body, env);
        return json({ ok: true, ...result });
      } catch (error) {
        const status = error instanceof HttpError ? error.status : 502;
        return json({
          error: 'Video cleanup failed',
          error_description:
              error instanceof Error ? error.message : 'Unknown error',
        }, status);
      }
    }

    return json({ error: 'Not found' }, 404);
  },
};
