export default {
  async fetch(request, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, PUT, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Content-Type',
      'Access-Control-Max-Age': '86400',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      const url = new URL(request.url);
      const pathname = url.pathname;

      // Handle root path and web app paths
      if (pathname === '/' || pathname.startsWith('/assets/') || pathname === '/index.html') {
        const key = pathname === '/' ? 'index.html' : pathname.slice(1);
        const obj = await env.MY_BUCKET.get(key);
        
        if (!obj) {
          // If index.html not found, return the default one
          const defaultHtml = await env.MY_BUCKET.get('index.html');
          if (!defaultHtml) {
            throw new Error('Web app files not found');
          }
          return new Response(defaultHtml.body, {
            headers: {
              'content-type': 'text/html;charset=UTF-8',
              ...corsHeaders,
            },
          });
        }

        const headers = new Headers();
        obj.writeHttpMetadata(headers);
        Object.entries(corsHeaders).forEach(([k, v]) => headers.set(k, v));
        return new Response(obj.body, { headers });
      }

      // Handle 6-character video codes
      const videoCodeMatch = pathname.match(/^\/([A-Za-z0-9]{6})$/);
      if (videoCodeMatch) {
        // Return the web app for video routes - client will handle the routing
        const indexHtml = await env.MY_BUCKET.get('index.html');
        if (!indexHtml) {
          throw new Error('Web app not found');
        }
        return new Response(indexHtml.body, {
          headers: {
            'content-type': 'text/html;charset=UTF-8',
            ...corsHeaders,
          },
        });
      }

      // Handle R2 storage operations
      const key = decodeURIComponent(pathname.slice(1));

      switch (request.method) {
        case 'GET': {
          const obj = await env.MY_BUCKET.get(key);
          if (!obj) {
            return new Response(JSON.stringify({ error: 'Object not found' }), {
              status: 404,
              headers: {
                ...corsHeaders,
                'Content-Type': 'application/json',
              },
            });
          }

          const headers = new Headers();
          obj.writeHttpMetadata(headers);
          headers.set('etag', obj.httpEtag);
          Object.entries(corsHeaders).forEach(([k, v]) => headers.set(k, v));
          headers.set('Accept-Ranges', 'bytes');

          return new Response(obj.body, { headers });
        }

        case 'PUT': {
          const contentType = request.headers.get('Content-Type');
          const uploadId = request.headers.get('X-Upload-Id');
          const partNumber = request.headers.get('X-Part-Number');
          const totalParts = request.headers.get('X-Total-Parts');

          // Handle single file upload
          if (!uploadId || !partNumber || !totalParts) {
            const data = await request.arrayBuffer();
            await env.MY_BUCKET.put(key, data, {
              httpMetadata: { contentType }
            });

            return new Response(JSON.stringify({ success: true }), {
              headers: {
                ...corsHeaders,
                'Content-Type': 'application/json',
              },
            });
          }

          // Handle chunked upload
          const data = await request.arrayBuffer();
          const partKey = `chunks/${key}/${uploadId}/part${partNumber}`;

          await env.MY_BUCKET.put(partKey, data, {
            customMetadata: {
              uploadId,
              partNumber,
              totalParts,
              originalKey: key,
              contentType,
            }
          });

          // Combine chunks if this is the last part
          if (parseInt(partNumber) === parseInt(totalParts) - 1) {
            const chunks = [];
            const chunkFolder = `chunks/${key}/${uploadId}`;

            try {
              // Load and combine chunks
              for (let i = 0; i < parseInt(totalParts); i++) {
                const chunkKey = `${chunkFolder}/part${i}`;
                const chunk = await env.MY_BUCKET.get(chunkKey);
                if (!chunk) throw new Error(`Missing chunk ${i}`);
                chunks.push(await chunk.arrayBuffer());
              }

              // Upload combined file
              const finalFile = new Blob(chunks, { type: contentType });
              await env.MY_BUCKET.put(key, finalFile, {
                httpMetadata: { contentType }
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
              await env.MY_BUCKET.delete(key).catch(() => {});
              throw error;
            }
          }

          return new Response(JSON.stringify({ success: true }), {
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          });
        }

        case 'DELETE': {
          await env.MY_BUCKET.delete(key);
          return new Response(JSON.stringify({ success: true }), {
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          });
        }

        default:
          return new Response(JSON.stringify({ error: 'Method not allowed' }), {
            status: 405,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          });
      }
    } catch (err) {
      return new Response(JSON.stringify({ error: err.message }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    }
  }
};