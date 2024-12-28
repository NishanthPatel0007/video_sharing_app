// Configuration
const config = {
  allowedOrigins: ['*'],  // Configure with your domains in production
  maxUploadSize: 500 * 1024 * 1024,  // 500MB
  maxChunkSize: 10 * 1024 * 1024,    // 10MB
  allowedContentTypes: [
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'video/x-matroska',
    'video/mov',
    'video/m4v',
    'video/hevc',
    'image/jpeg',
    'image/png',
    'image/jpg'
  ]
};

// CORS Headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, PUT, POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': '*',
  'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Content-Type, Accept-Ranges, ETag',
  'Access-Control-Max-Age': '86400',
  'Cache-Control': 'public, max-age=31536000',
  'Access-Control-Allow-Private-Network': 'true',
  'Cross-Origin-Resource-Policy': 'cross-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
  'Cross-Origin-Opener-Policy': 'same-origin'
};

// Error Handling
class WorkerError extends Error {
  constructor(message, status = 500) {
    super(message);
    this.status = status;
  }
}

// Main Worker
export default {
  async fetch(request, env, ctx) {
    try {
      // Handle CORS preflight
      if (request.method === 'OPTIONS') {
        return new Response(null, { headers: corsHeaders });
      }

      const url = new URL(request.url);
      const pathname = url.pathname;

      // Route handling
      if (pathname.startsWith('/v/')) {
        return handleVideoPage(request, env);
      }

      if (pathname === '/getUploadUrl') {
        return handleGetUploadUrl(request, env);
      }

      if (pathname === '/combine') {
        return handleCombineChunks(request, env);
      }

      // Default file operations handling
      return handleFileOperation(request, env);

    } catch (err) {
      console.error('Worker error:', err);
      return createErrorResponse(err);
    }
  }
};

// Handle Get Upload URL Request
async function handleGetUploadUrl(request, env) {
  if (request.method !== 'POST') {
    throw new WorkerError('Method not allowed', 405);
  }

  try {
    // Verify authentication token
    const authHeader = request.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      throw new WorkerError('Unauthorized', 401);
    }

    // Parse request body
    const { fileType } = await request.json();
    if (!fileType || !config.allowedContentTypes.includes(fileType)) {
      throw new WorkerError('Invalid file type', 400);
    }

    // Generate unique upload ID
    const uploadId = crypto.randomUUID();
    const timestamp = Date.now();
    const key = `uploads/${timestamp}-${uploadId}`;

    return jsonResponse({
      uploadUrl: `https://${request.headers.get('host')}/${key}`,
      key: key,
      uploadId: uploadId,
      expiresIn: 3600, // 1 hour
      maxFileSize: config.maxUploadSize,
      maxChunkSize: config.maxChunkSize,
      contentType: fileType,
    });
  } catch (error) {
    if (error instanceof WorkerError) throw error;
    throw new WorkerError('Failed to generate upload URL: ' + error.message);
  }
}

// Handle Video Page Requests
async function handleVideoPage(request, env) {
  try {
    const indexHtml = await fetch(new URL('/index.html', request.url));
    if (!indexHtml.ok) throw new WorkerError('Failed to fetch index.html', 404);
    
    const html = await indexHtml.text();
    return new Response(html, {
      headers: {
        'Content-Type': 'text/html;charset=UTF-8',
        'Cache-Control': 'no-cache',
        ...corsHeaders
      }
    });
  } catch (error) {
    throw new WorkerError('Error serving video page: ' + error.message);
  }
}

// Handle File Operations (GET, PUT, DELETE)
async function handleFileOperation(request, env) {
  const url = new URL(request.url);
  const key = decodeURIComponent(url.pathname.slice(1));

  switch (request.method) {
    case 'HEAD':
      return handleHeadRequest(key, env);
    case 'GET':
      return handleGetRequest(key, request, env);
    case 'PUT':
      return handlePutRequest(key, request, env);
    case 'DELETE':
      return handleDeleteRequest(key, env);
    default:
      throw new WorkerError('Method not allowed', 405);
  }
}

// Handle HEAD Request
async function handleHeadRequest(key, env) {
  const obj = await env.MY_BUCKET.head(key);
  if (!obj) {
    throw new WorkerError('File not found', 404);
  }

  const headers = new Headers(corsHeaders);
  obj.writeHttpMetadata(headers);
  headers.set('etag', obj.httpEtag);
  headers.set('Accept-Ranges', 'bytes');
  headers.set('Content-Length', obj.size.toString());
  headers.set('Content-Type', obj.httpMetadata.contentType || 'application/octet-stream');

  return new Response(null, { headers });
}

// Handle GET Request
async function handleGetRequest(key, request, env) {
  const obj = await env.MY_BUCKET.get(key);
  if (!obj) {
    throw new WorkerError('File not found', 404);
  }

  const headers = new Headers(corsHeaders);
  obj.writeHttpMetadata(headers);
  headers.set('etag', obj.httpEtag);
  headers.set('Accept-Ranges', 'bytes');
  headers.set('Content-Type', obj.httpMetadata.contentType || 'application/octet-stream');

  // Handle range requests
  const range = request.headers.get('Range');
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

// Handle PUT Request
async function handlePutRequest(key, request, env) {
  const contentType = request.headers.get('Content-Type') || 'application/octet-stream';
  if (!config.allowedContentTypes.includes(contentType)) {
    throw new WorkerError('Invalid content type', 400);
  }

  const uploadId = request.headers.get('X-Upload-Id');
  const partNumber = request.headers.get('X-Part-Number');
  const totalParts = request.headers.get('X-Total-Parts');

  // Single file upload
  if (!uploadId || !partNumber || !totalParts) {
    return handleSingleFileUpload(key, request, contentType, env);
  }

  // Chunked upload
  return handleChunkedUpload(key, request, {
    uploadId,
    partNumber,
    totalParts,
    contentType
  }, env);
}

// Handle Single File Upload
async function handleSingleFileUpload(key, request, contentType, env) {
  const data = await request.arrayBuffer();
  if (data.byteLength > config.maxUploadSize) {
    throw new WorkerError('File too large', 413);
  }

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

  return jsonResponse({ success: true, message: 'File uploaded successfully' });
}

// Handle Chunked Upload
async function handleChunkedUpload(key, request, chunkInfo, env) {
  const { uploadId, partNumber, totalParts, contentType } = chunkInfo;
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

  return jsonResponse({
    success: true,
    message: parseInt(partNumber) === parseInt(totalParts) - 1 
      ? 'All chunks uploaded and combined'
      : 'Chunk uploaded'
  });
}

// Handle DELETE Request
async function handleDeleteRequest(key, env) {
  const obj = await env.MY_BUCKET.get(key);
  if (!obj) {
    throw new WorkerError('File not found', 404);
  }

  await env.MY_BUCKET.delete(key);

  // Clean up chunks if they exist
  const uploadId = obj.customMetadata?.originalUploadId;
  if (uploadId) {
    await cleanupChunks(key, uploadId, obj.customMetadata?.parts, env);
  }

  return jsonResponse({ success: true, message: 'File deleted successfully' });
}

// Handle Chunk Combination
async function handleCombineChunks(request, env) {
  const { key, uploadId, contentType, totalChunks, totalSize } = await request.json();
  if (!key || !uploadId || !contentType || !totalChunks) {
    throw new WorkerError('Missing required parameters', 400);
  }

  try {
    const chunks = [];
    const chunkFolder = `chunks/${key}/${uploadId}`;
    let actualSize = 0;

    // Gather all chunks
    for (let i = 0; i < totalChunks; i++) {
      const chunkKey = `${chunkFolder}/part${i}`;
      const chunk = await env.MY_BUCKET.get(chunkKey);
      if (!chunk) throw new WorkerError(`Missing chunk ${i}`, 400);
      
      const buffer = await chunk.arrayBuffer();
      actualSize += buffer.byteLength;
      chunks.push(buffer);
    }

    // Verify total size
    if (totalSize && actualSize !== parseInt(totalSize)) {
      throw new WorkerError('Size mismatch', 400);
    }

    // Combine and upload final file
    const finalFile = new Blob(chunks, { type: contentType });
    await env.MY_BUCKET.put(key, finalFile, {
      httpMetadata: {
        contentType,
        cacheControl: 'public, max-age=31536000',
      },
      customMetadata: {
        uploaded: new Date().toISOString(),
        originalUploadId: uploadId,
        size: actualSize,
        parts: totalChunks
      }
    });

    // Cleanup chunks
    await cleanupChunks(key, uploadId, totalChunks, env);

    return jsonResponse({
      success: true,
      message: 'Chunks combined successfully'
    });
  } catch (error) {
    // Cleanup on error
    await cleanupChunks(key, uploadId, totalChunks, env);
    throw error;
  }
}

// Utility Functions
async function cleanupChunks(key, uploadId, totalParts, env) {
  const chunkFolder = `chunks/${key}/${uploadId}`;
  const parts = parseInt(totalParts) || 0;
  
  for (let i = 0; i < parts; i++) {
    await env.MY_BUCKET.delete(`${chunkFolder}/part${i}`).catch(console.error);
  }
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function createErrorResponse(error) {
  const status = error.status || 500;
  const message = error.message || 'Internal Server Error';

  if (status === 404) {
    return new Response(createErrorPage('Video Not Found', 'This video may have been removed or is no longer available.'), {
      status,
      headers: {
        'Content-Type': 'text/html;charset=UTF-8',
        ...corsHeaders
      }
    });
  }

  return jsonResponse({
    error: true,
    message
  }, status);
}

function createErrorPage(title, message) {
  return `
    <!DOCTYPE html>
    <html>
      <head>
        <title>${title} - Video Platform</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background-color: #1E1B2C;
            color: white;
          }
          .error-container {
            text-align: center;
            padding: 2rem;
            background-color: #2D2940;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.2);
            max-width: 90%;
            width: 400px;
          }
          .error-icon {
            font-size: 48px;
            margin-bottom: 1rem;
          }
          .error-message {
            margin: 1rem 0;
            color: #E1E1E6;
          }
          .retry-button {
            margin-top: 1rem;
            padding: 0.75rem 1.5rem;
            background-color: #8257E5;
            border: none;
            border-radius: 4px;
            color: white;
            cursor: pointer;
            font-size: 16px;
            transition: background-color 0.2s;
          }
          .retry-button:hover {
            background-color: #9466FF;
          }
        </style>
      </head>
      <body>
        <div class="error-container">
          <div class="error-icon">⚠️</div>
          <h1>${title}</h1>
          <p class="error-message">${message}</p>
          <button class="retry-button" onclick="window.history.back()">Go Back</button>
        </div>
      </body>
    </html>
  `;
}