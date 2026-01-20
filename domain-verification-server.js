#!/usr/bin/env node

/**
 * Simple Express server to serve Apple domain verification file
 * This is needed for Sign In with Apple web authentication
 *
 * Usage:
 *   node domain-verification-server.js
 *
 * The server will:
 * - Serve the Apple domain verification file at /.well-known/apple-developer-domain-association.txt
 * - Handle CORS for cross-origin requests
 * - Run on port 3000 (or PORT environment variable)
 */

const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// CORS middleware - allow all origins for domain verification
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Serve Apple domain verification file
app.get('/.well-known/apple-developer-domain-association.txt', (req, res) => {
  const filePath = path.join(__dirname, '.well-known', 'apple-developer-domain-association.txt');

  // Check if file exists
  if (!fs.existsSync(filePath)) {
    console.error('⚠️  Verification file not found at:', filePath);
    console.error('⚠️  Please download the file from Apple Developer Portal and place it at:');
    console.error('   ', filePath);
    return res.status(404).send('Domain verification file not found. Please configure it first.');
  }

  // Serve the file with correct content type
  res.type('text/plain');
  res.sendFile(filePath);
  console.log('✓ Served Apple domain verification file');
});

// Serve static files from .well-known directory
app.use('/.well-known', express.static(path.join(__dirname, '.well-known')));

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested resource does not exist',
    path: req.path
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// Start server
app.listen(PORT, () => {
  console.log('\n🚀 Apple Domain Verification Server');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`✓ Server running on port ${PORT}`);
  console.log(`✓ Verification URL: http://localhost:${PORT}/.well-known/apple-developer-domain-association.txt`);
  console.log('\n📋 Setup Instructions:');
  console.log('1. Download the verification file from Apple Developer Portal');
  console.log('2. Place it at: .well-known/apple-developer-domain-association.txt');
  console.log('3. For production, deploy this server to your domain (craigoclean.com)');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('HTTP server closed');
  });
});
