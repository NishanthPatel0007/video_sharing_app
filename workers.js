export default {
  async fetch(request, env) {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, PUT, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Max-Age': '86400',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range',
    };

    try {
      const url = new URL(request.url);
      let path = decodeURIComponent(url.pathname);

      // Handle CORS preflight
      if (request.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders });
      }

      // Remove leading slash and get the key
      path = path.replace(/^\//, '');
      
      // Handle both thumbnails and videos from root path
      const key = path.split('?')[0];
      console.log('Fetching object:', key);

      const object = await env.VIDEO_BUCKET.get(key);
      if (!object) {
        console.error('Object not found:', key);
        return new Response('Not found', { 
          status: 404, 
          headers: corsHeaders 
        });
      }

      // Determine content type from file extension
      const ext = key.split('.').pop()?.toLowerCase();
      const contentType = 
        ext === 'png' ? 'image/png' : 
        ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg' :
        ext === 'mp4' ? 'video/mp4' :
        'application/octet-stream';

      // Handle video streaming
      if (contentType.startsWith('video/')) {
        const range = request.headers.get('range');
        if (range) {
          const [start, end] = range.replace(/bytes=/, '').split('-').map(Number);
          const contentLength = (end || object.size - 1) - start + 1;

          return new Response(object.slice(start, end + 1), {
            status: 206,
            headers: {
              ...corsHeaders,
              'Content-Type': contentType,
              'Content-Range': `bytes ${start}-${end || object.size - 1}/${object.size}`,
              'Content-Length': contentLength.toString(),
              'Accept-Ranges': 'bytes',
              'Cache-Control': 'public, max-age=31536000',
            },
          });
        }
      }

      // Return regular response
      return new Response(object.body, {
        headers: {
          ...corsHeaders,
          'Content-Type': contentType,
          'Content-Length': object.size.toString(),
          'Cache-Control': 'public, max-age=31536000',
          'Accept-Ranges': 'bytes',
        },
      });

    } catch (error) {
      console.error('Worker error:', error);
      return new Response(`Internal Server Error: ${error.message}`, { 
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/plain',
        }
      });
    }
  }
};