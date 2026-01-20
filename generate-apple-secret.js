const jwt = require('jsonwebtoken');
const fs = require('fs');

// Your Apple credentials
const TEAM_ID = 'K36LFHM32T';           // From Step 4
const CLIENT_ID = 'com.craigoclean.web';  // Your Services ID from Step 2
const KEY_ID = '9UXQ898S57';             // From Step 3

// Read your private key file
const privateKey = fs.readFileSync('AuthKey_9UXQ898S57.p8');

// Generate the client secret (valid for 6 months max)
const clientSecret = jwt.sign({}, privateKey, {
  algorithm: 'ES256',
  expiresIn: '180d',
  audience: 'https://appleid.apple.com',
  issuer: TEAM_ID,
  subject: CLIENT_ID,
  keyid: KEY_ID
});

console.log('Client Secret (valid for 180 days):');
console.log(clientSecret);