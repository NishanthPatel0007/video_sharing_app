export default {
  async fetch(request, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, PUT, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Content-Type, Accept-Ranges, ETag',
      'Access-Control-Max-Age': '3600',
      'Cache-Control': 'public, max-age=31536000',
      'Access-Control-Allow-Private-Network': 'true',
      'Cross-Origin-Resource-Policy': 'cross-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Range': '*',
      'Accept-Ranges': 'bytes',
      'Timing-Allow-Origin': '*',
      'Vary': 'Origin'
    };

    try {
      const url = new URL(request.url);
      const pathname = url.pathname;

      if (request.method === 'OPTIONS') {
        return new Response(null, {
          headers: corsHeaders
        });
      }

      // Video URL handling with redirection
      if (pathname.startsWith('/v/')) {
        const code = pathname.substring(3);
        return Response.redirect(`${url.origin}/?video=${code}`, 302);
      }

      const key = decodeURIComponent(pathname.slice(1));

      switch (request.method) {
        case 'HEAD': {
          const obj = await env.MY_BUCKET.get(key);
          if (!obj) {
            return new Response(null, {
              status: 404,
              headers: { ...corsHeaders }
            });
          }
          const headers = new Headers();
          obj.writeHttpMetadata(headers);
          headers.set('etag', obj.httpEtag);
          headers.set('Accept-Ranges', 'bytes');
          headers.set('Content-Type', obj.httpMetadata.contentType || 'application/octet-stream');
          headers.set('Content-Length', obj.size.toString());
          Object.entries(corsHeaders).forEach(([k, v]) => headers.set(k, v));
          return new Response(null, { headers });
        }

        case 'GET': {
          const obj = await env.MY_BUCKET.get(key);
          if (!obj) {
            return new Response('File not found', {
              status: 404,
              headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
            });
          }

          const range = request.headers.get('Range');
          const headers = new Headers();
          
          obj.writeHttpMetadata(headers);
          headers.set('etag', obj.httpEtag);
          headers.set('Accept-Ranges', 'bytes');
          headers.set('Content-Type', obj.httpMetadata.contentType || 'application/octet-stream');
          Object.entries(corsHeaders).forEach(([k, v]) => headers.set(k, v));

          if (range) {
            const rangeMatch = range.match(/bytes=(\d+)-(\d+)?/);
            if (rangeMatch) {
              const start = parseInt(rangeMatch[1]);
              const end = rangeMatch[2] ? parseInt(rangeMatch[2]) : obj.size - 1;
              headers.set('Content-Range', `bytes ${start}-${end}/${obj.size}`);
              headers.set('Content-Length', `${end - start + 1}`);
              return new Response(obj.body.slice(start, end + 1), {
                status: 206,
                headers
              });
            }
          }

          return new Response(obj.body, { headers });
        }

        case 'PUT': {
          const contentType = request.headers.get('Content-Type') || 'application/octet-stream';
          const uploadId = request.headers.get('X-Upload-Id');
          const partNumber = request.headers.get('X-Part-Number');
          const totalParts = request.headers.get('X-Total-Parts');

          if (!uploadId || !partNumber || !totalParts) {
            const data = await request.arrayBuffer();
            await env.MY_BUCKET.put(key, data, {
              httpMetadata: {
                contentType,
                cacheControl: 'public, max-age=31536000',
              },
              customMetadata: {
                uploaded: new Date().toISOString(),
                size: data.byteLength
              }
            });

            return new Response(JSON.stringify({
              success: true,
              message: 'File uploaded successfully'
            }), {
              headers: {
                ...corsHeaders,
                'Content-Type': 'application/json',
              },
            });
          }

          const data = await request.arrayBuffer();
          const partKey = `chunks/${key}/${uploadId}/part${partNumber}`;

          await env.MY_BUCKET.put(partKey, data, {
            customMetadata: {
              uploadId,
              partNumber,
              totalParts,
              originalKey: key,
              contentType,
              size: data.byteLength
            }
          });

          if (parseInt(partNumber) === parseInt(totalParts) - 1) {
            const chunks = [];
            const chunkFolder = `chunks/${key}/${uploadId}`;
            let totalSize = 0;

            try {
              for (let i = 0; i < parseInt(totalParts); i++) {
                const chunkKey = `${chunkFolder}/part${i}`;
                const chunk = await env.MY_BUCKET.get(chunkKey);
                if (!chunk) throw new Error(`Missing chunk ${i}`);
                const buffer = await chunk.arrayBuffer();
                totalSize += buffer.byteLength;
                chunks.push(buffer);
              }

              const finalFile = new Blob(chunks, { type: contentType });
              await env.MY_BUCKET.put(key, finalFile, {
                httpMetadata: {
                  contentType,
                  cacheControl: 'public, max-age=31536000',
                },
                customMetadata: {
                  uploaded: new Date().toISOString(),
                  originalUploadId: uploadId,
                  size: totalSize,
                  parts: totalParts
                }
              });

              for (let i = 0; i < parseInt(totalParts); i++) {
                await env.MY_BUCKET.delete(`${chunkFolder}/part${i}`).catch(console.error);
              }
            } catch (error) {
              for (let i = 0; i < parseInt(totalParts); i++) {
                await env.MY_BUCKET.delete(`${chunkFolder}/part${i}`).catch(console.error);
              }
              await env.MY_BUCKET.delete(key).catch(console.error);
              throw error;
            }
          }

          return new Response(JSON.stringify({
            success: true,
            message: partNumber === totalParts - 1 ? 'All chunks uploaded and combined' : 'Chunk uploaded'
          }), {
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          });
        }

        case 'DELETE': {
          const obj = await env.MY_BUCKET.get(key);
          if (!obj) {
            return new Response('File not found', {
              status: 404,
              headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
            });
          }

          await env.MY_BUCKET.delete(key);
          
          const uploadId = obj.customMetadata?.originalUploadId;
          if (uploadId) {
            const chunkFolder = `chunks/${key}/${uploadId}`;
            const totalParts = parseInt(obj.customMetadata?.parts || 0);
            for (let i = 0; i < totalParts; i++) {
              await env.MY_BUCKET.delete(`${chunkFolder}/part${i}`).catch(console.error);
            }
          }

          return new Response(JSON.stringify({
            success: true,
            message: 'File deleted successfully'
          }), {
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          });
        }

        default:
          return new Response(JSON.stringify({
            error: 'Method not allowed'
          }), {
            status: 405,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json',
            },
          });
      }
    } catch (err) {
      console.error('Worker error:', err);
      return new Response(JSON.stringify({
        error: 'Internal server error',
        message: err.message
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      });
    }
  }
};