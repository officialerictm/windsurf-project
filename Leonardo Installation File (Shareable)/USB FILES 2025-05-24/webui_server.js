#!/usr/bin/env node
// Simple HTTP server that serves the WebUI and forwards API requests to Ollama
// This avoids CORS issues by acting as a proxy

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

// Configuration
const PORT = 8080;
const OLLAMA_API = 'http://127.0.0.1:11434';
const OLLAMA_API_HOST = '127.0.0.1:11434';

// Simple MIME type mapping
const MIME_TYPES = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon'
};

// Create HTTP server
const server = http.createServer((req, res) => {
  console.log(`${req.method} ${req.url}`);
  
  // Handle API proxy requests
  if (req.url.startsWith('/api/')) {
    const options = {
      hostname: '127.0.0.1',
      port: 11434,
      path: req.url,
      method: req.method,
      headers: {
        'Content-Type': 'application/json'
      }
    };
    
    const apiReq = http.request(options, (apiRes) => {
      // Set CORS headers to allow requests
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
      
      // Forward status and headers
      res.writeHead(apiRes.statusCode, apiRes.headers);
      
      // Stream response data
      apiRes.pipe(res);
    });
    
    apiReq.on('error', (error) => {
      console.error(`API Request Error: ${error.message}`);
      res.writeHead(500);
      res.end(JSON.stringify({ error: 'Error connecting to Ollama API' }));
    });
    
    // Forward request body to Ollama API
    if (['POST', 'PUT'].includes(req.method)) {
      req.pipe(apiReq);
    } else {
      apiReq.end();
    }
    
    return;
  }
  
  // For OPTIONS requests (preflight CORS)
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.writeHead(204);
    res.end();
    return;
  }
  
  // Serve WebUI files
  let filePath = './webui' + (req.url === '/' ? '/index.html' : req.url);
  
  // Check if file exists
  fs.access(filePath, fs.constants.F_OK, (err) => {
    if (err) {
      res.writeHead(404);
      res.end('File not found');
      return;
    }
    
    // Read and serve the file
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(500);
        res.end('Error reading file');
        return;
      }
      
      const ext = path.extname(filePath);
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';
      
      res.setHeader('Content-Type', contentType);
      res.writeHead(200);
      res.end(data);
    });
  });
});

// Start server
server.listen(PORT, () => {
  console.log(`WebUI server running at http://localhost:${PORT}/`);
  console.log(`Proxying API requests to ${OLLAMA_API}`);
});

// Handle server errors
server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Try a different port.`);
  } else {
    console.error('Server error:', err);
  }
});
