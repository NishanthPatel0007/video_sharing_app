export default {
  async fetch(request, env) {
    const ALLOWED_DOMAINS = ["for10cloud.com", "www.for10cloud.com"];
    const MAX_UPLOAD_SIZE = 500000000; // 500MB from your env

    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, PUT, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Content-Type, X-Platform-Info, X-Video-Format, X-HLS-Support, X-Upload-Content-Type, X-Upload-Content-Length, X-Auth-Token',
      'Access-Control-Max-Age': '86400',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      // Domain validation
      const requestUrl = new URL(request.url);
      if (!ALLOWED_DOMAINS.includes(requestUrl.hostname)) {
        return new Response(JSON.stringify({ error: 'Invalid domain' }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // Get request details
      const authToken = request.headers.get('X-Auth-Token');
      const key = decodeURIComponent(requestUrl.pathname.slice(1));
      const platformInfo = request.headers.get('X-Platform-Info') || '';
      const videoFormat = request.headers.get('X-Video-Format') || 'mp4';
      const hlsSupport = request.headers.get('X-HLS-Support') === 'true';
      const isIOS = platformInfo.includes('iOS');

      // Firebase Auth validation
      const isAuthenticated = await validateAuth(authToken, {
        projectId: env.FIREBASE_PROJECT_ID,
        apiKey: env.FIREBASE_API_KEY
      });
      
      switch (request.method) {
        case 'GET': {
          let finalKey = key;
          let useHLS = false;

          // Handle HLS for iOS
          if (hlsSupport && isIOS && key.includes('/videos/') && !key.includes('/hls/')) {
            const hlsPath = key.replace('/videos/', '/videos/hls/');
            const hlsObj = await env.MY_BUCKET.get(hlsPath);
            if (hlsObj) {
              finalKey = hlsPath;
              useHLS = true;
            }
          }

          const obj = await env.MY_BUCKET.get(finalKey);
          if (!obj) {
            return new Response(JSON.stringify({ error: 'Object not found' }), {
              status: 404,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
          }

          const headers = new Headers();
          obj.writeHttpMetadata(headers);
          headers.set('etag', obj.httpEtag);
          headers.set('Cache-Control', useHLS ? 'no-cache' : 'public, max-age=31536000');
          Object.entries(corsHeaders).forEach(([k, v]) => headers.set(k, v));
          headers.set('Accept-Ranges', 'bytes');

          const range = request.headers.get('range');
          if (range) {
            return handleRangeRequest(obj, range, headers);
          }

          return new Response(obj.body, { headers });
        }

        case 'PUT': {
          if (!isAuthenticated) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
              status: 401,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
          }

          const contentLength = parseInt(request.headers.get('Content-Length') || '0');
          if (contentLength > MAX_UPLOAD_SIZE) {
            return new Response(JSON.stringify({ error: 'File too large' }), {
              status: 413,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
          }

          const contentType = request.headers.get('Content-Type');
          const uploadId = request.headers.get('X-Upload-Id');
          const partNumber = request.headers.get('X-Part-Number');
          const totalParts = request.headers.get('X-Total-Parts');
          const format = request.headers.get('X-Format-Type') || 'original';

          let storageKey = key;
          if (key.startsWith('videos/')) {
            const formatPath = format === 'hls' ? 'hls' : format;
            storageKey = `videos/${formatPath}/${key.split('/').pop()}`;
          }

          if (!uploadId || !partNumber || !totalParts) {
            const data = await request.arrayBuffer();
            await env.MY_BUCKET.put(storageKey, data, {
              httpMetadata: {
                contentType,
                'Cache-Control': format === 'hls' ? 'no-cache' : 'public, max-age=31536000'
              }
            });

            return new Response(JSON.stringify({ 
              success: true,
              path: storageKey 
            }), {
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
          }

          const data = await request.arrayBuffer();
          const partKey = `chunks/${storageKey}/${uploadId}/part${partNumber}`;

          await env.MY_BUCKET.put(partKey, data, {
            customMetadata: {
              uploadId,
              partNumber,
              totalParts,
              originalKey: storageKey,
              contentType,
              format
            }
          });

          if (parseInt(partNumber) === parseInt(totalParts) - 1) {
            const chunks = [];
            const chunkFolder = `chunks/${storageKey}/${uploadId}`;

            try {
              for (let i = 0; i < parseInt(totalParts); i++) {
                const chunk = await env.MY_BUCKET.get(`${chunkFolder}/part${i}`);
                if (!chunk) throw new Error(`Missing chunk ${i}`);
                chunks.push(await chunk.arrayBuffer());
              }

              const finalFile = new Blob(chunks, { type: contentType });
              await env.MY_BUCKET.put(storageKey, finalFile, {
                httpMetadata: {
                  contentType,
                  'Cache-Control': format === 'hls' ? 'no-cache' : 'public, max-age=31536000'
                }
              });

              // Cleanup chunks
              for (let i = 0; i < parseInt(totalParts); i++) {
                await env.MY_BUCKET.delete(`${chunkFolder}/part${i}`).catch(() => {});
              }
            } catch (error) {
              // Cleanup on error
              for (let i = 0; i < parseInt(totalParts); i++) {
                await env.MY_BUCKET.delete(`${chunkFolder}/part${i}`).catch(() => {});
              }
              await env.MY_BUCKET.delete(storageKey).catch(() => {});
              throw error;
            }
          }

          return new Response(JSON.stringify({ 
            success: true,
            path: storageKey
          }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        case 'DELETE': {
          if (!isAuthenticated) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
              status: 401,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
          }

          const basePath = key.split('/').slice(0, -1).join('/');
          const fileName = key.split('/').pop();
          
          const deletions = [
            env.MY_BUCKET.delete(`${basePath}/original/${fileName}`),
            env.MY_BUCKET.delete(`${basePath}/web_optimized/${fileName}`),
            env.MY_BUCKET.delete(`${basePath}/hls/${fileName}`),
            env.MY_BUCKET.delete(`chunks/${basePath}/${fileName}/*`),
          ];
          
          await Promise.all(deletions.map(p => p.catch(() => {})));
          
          return new Response(JSON.stringify({ success: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }

        default:
          return new Response(JSON.stringify({ error: 'Method not allowed' }), {
            status: 405,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
      }
    } catch (err) {
      console.error('Worker error:', err);
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
  }
};

async function handleRangeRequest(obj, range, headers) {
  const bytes = range.replace('bytes=', '').split('-');
  const start = parseInt(bytes[0]);
  const end = bytes[1] ? parseInt(bytes[1]) : obj.size - 1;
  
  headers.set('Content-Range', `bytes ${start}-${end}/${obj.size}`);
  headers.set('Content-Length', String(end - start + 1));
  headers.set('Accept-Ranges', 'bytes');
  
  const slicedData = obj.body.slice(start, end + 1);
  return new Response(slicedData, {
    status: 206,
    headers
  });
}

async function validateAuth(token, config) {
  if (!token) return false;
  try {
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${config.apiKey}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ idToken: token })
      }
    );
    
    return response.ok;
  } catch (e) {
    console.error('Auth validation error:', e);
    return false;
  }
}