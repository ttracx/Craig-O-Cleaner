/**
 * Craig-O-Clean Web Server
 * Simple Node.js server for local development and deployment
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// MIME types for common file extensions
const MIME_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf',
    '.webp': 'image/webp',
    '.webm': 'video/webm',
    '.mp4': 'video/mp4',
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.txt': 'text/plain; charset=utf-8',
    '.xml': 'application/xml',
    '.pdf': 'application/pdf'
};

// Security headers
const SECURITY_HEADERS = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'SAMEORIGIN',
    'X-XSS-Protection': '1; mode=block',
    'Referrer-Policy': 'strict-origin-when-cross-origin'
};

// Create HTTP server
const server = http.createServer((req, res) => {
    // Parse URL
    let urlPath = req.url.split('?')[0];

    // Default to index.html
    if (urlPath === '/') {
        urlPath = '/index.html';
    }

    // Prevent directory traversal
    const safePath = path.normalize(urlPath).replace(/^(\.\.[\/\\])+/, '');
    const filePath = path.join(__dirname, safePath);

    // Check if file exists
    fs.stat(filePath, (err, stats) => {
        if (err || !stats.isFile()) {
            // Try serving index.html for SPA routing
            const indexPath = path.join(__dirname, 'index.html');
            serveFile(indexPath, res);
            return;
        }

        serveFile(filePath, res);
    });
});

function serveFile(filePath, res) {
    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, data) => {
        if (err) {
            res.writeHead(404, { 'Content-Type': 'text/html' });
            res.end('<h1>404 - Not Found</h1>');
            return;
        }

        // Set headers
        const headers = {
            'Content-Type': contentType,
            'Content-Length': data.length,
            ...SECURITY_HEADERS
        };

        // Cache control for static assets
        if (['.css', '.js', '.png', '.jpg', '.svg', '.woff2'].includes(ext)) {
            headers['Cache-Control'] = 'public, max-age=31536000, immutable';
        } else if (ext === '.html') {
            headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
        }

        // Service Worker headers
        if (filePath.endsWith('sw.js')) {
            headers['Service-Worker-Allowed'] = '/';
            headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
        }

        res.writeHead(200, headers);
        res.end(data);
    });
}

// Start server
server.listen(PORT, HOST, () => {
    console.log(`
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   🧹 Craig-O-Clean Web App                                ║
║                                                           ║
║   Server running at:                                      ║
║   → Local:   http://localhost:${PORT}                       ║
║   → Network: http://${HOST}:${PORT}                         ║
║                                                           ║
║   Press Ctrl+C to stop                                    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
    `);
});

// Handle server errors
server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`Port ${PORT} is already in use. Try a different port.`);
    } else {
        console.error('Server error:', err);
    }
    process.exit(1);
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\nShutting down server...');
    server.close(() => {
        console.log('Server stopped.');
        process.exit(0);
    });
});
