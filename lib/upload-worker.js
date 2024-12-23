export default {
  async fetch(request, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, PUT, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Expose-Headers': '*',
      'Access-Control-Max-Age': '86400',
      'Cache-Control': 'public, max-age=3600',
      'Access-Control-Allow-Private-Network': 'true',
    };

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { 
        headers: {
          ...corsHeaders,
          'Access-Control-Max-Age': '86400',
        } 
      });
    }

    try {
      const url = new URL(request.url);
      const key = decodeURIComponent(url.pathname.slice(1));

      // Handle file operations
      switch (request.method) {
        case 'GET': {
          // Check for range request
          const range = request.headers.get('Range');
          const obj = await env.MY_BUCKET.get(key);

          if (!obj) {
            return new Response('File not found', {
              status: 404,
              headers: {
                ...corsHeaders,
                'Content-Type': 'text/plain',
              },
            });
          }

          const headers = new Headers();
          obj.writeHttpMetadata(headers);
          headers.set('etag', obj.httpEtag);
          headers.set('Accept-Ranges', 'bytes');
          
          // Add CORS and cache headers
          Object.entries(corsHeaders).forEach(([k, v]) => headers.set(k, v));

          // Handle range request
          if (range) {
            headers.set('Range', range);
            return new Response(obj.body, { 
              status: 206,
              headers 
            });
          }

          return new Response(obj.body, { headers });
        }

        case 'PUT': {
          const contentType = request.headers.get('Content-Type') || 'application/octet-stream';
          const uploadId = request.headers.get('X-Upload-Id');
          const partNumber = request.headers.get('X-Part-Number');
          const totalParts = request.headers.get('X-Total-Parts');

          // Handle single file upload
          if (!uploadId || !partNumber || !totalParts) {
            const data = await request.arrayBuffer();
            await env.MY_BUCKET.put(key, data, {
              httpMetadata: { contentType },
              customMetadata: {
                uploaded: new Date().toISOString()
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

          // Handle multipart upload
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
                httpMetadata: { contentType },
                customMetadata: {
                  uploaded: new Date().toISOString(),
                  originalUploadId: uploadId
                }
              });

              // Cleanup chunks
              for (let i = 0; i < parseInt(totalParts); i++) {
                await env.MY_BUCKET.delete(`${chunkFolder}/part${i}`).catch(console.error);
              }

            } catch (error) {
              // Cleanup on error
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
          await env.MY_BUCKET.delete(key);
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