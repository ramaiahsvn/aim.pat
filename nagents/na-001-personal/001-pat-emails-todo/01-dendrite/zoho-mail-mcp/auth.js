#!/usr/bin/env node
/**
 * Zoho Mail OAuth2 — interactive auth flow.
 * Usage: ZOHO_CLIENT_ID=xxx ZOHO_CLIENT_SECRET=yyy ZOHO_ACCOUNT_EMAIL=you@domain.com node auth.js
 * Writes a credentials file to ~/.zoho-mail-mcp/<email>.json
 */

import http from 'http';
import { URL } from 'url';
import open from 'open';
import fs from 'fs';
import path from 'path';
import os from 'os';
import axios from 'axios';

const CLIENT_ID     = process.env.ZOHO_CLIENT_ID;
const CLIENT_SECRET = process.env.ZOHO_CLIENT_SECRET;
const ACCOUNT_EMAIL = process.env.ZOHO_ACCOUNT_EMAIL;
const REDIRECT_URI  = 'http://localhost:3000/oauth2callback';
const CREDS_DIR     = path.join(os.homedir(), '.zoho-mail-mcp');
const SCOPES        = [
  'ZohoMail.messages.READ',
  'ZohoMail.messages.CREATE',
  'ZohoMail.folders.READ',
  'ZohoMail.accounts.READ',
  'ZohoMail.tasks.ALL',
].join(',');

if (!CLIENT_ID || !CLIENT_SECRET || !ACCOUNT_EMAIL) {
  console.error('Required: ZOHO_CLIENT_ID, ZOHO_CLIENT_SECRET, ZOHO_ACCOUNT_EMAIL');
  process.exit(1);
}

fs.mkdirSync(CREDS_DIR, { recursive: true });

const authUrl =
  `https://accounts.zoho.com/oauth/v2/auth` +
  `?response_type=code` +
  `&client_id=${CLIENT_ID}` +
  `&scope=${encodeURIComponent(SCOPES)}` +
  `&redirect_uri=${encodeURIComponent(REDIRECT_URI)}` +
  `&access_type=offline` +
  `&prompt=consent`;

console.log(`\nOpening browser for ${ACCOUNT_EMAIL}...`);
console.log(`Auth URL:\n${authUrl}\n`);
open(authUrl);

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost:3000');
  if (!url.pathname.startsWith('/oauth2callback')) { res.end(); return; }

  const code = url.searchParams.get('code');
  if (!code) {
    res.end('Error: no code in callback');
    server.close();
    return;
  }

  try {
    const { data } = await axios.post(
      'https://accounts.zoho.com/oauth/v2/token',
      new URLSearchParams({
        code,
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        redirect_uri: REDIRECT_URI,
        grant_type: 'authorization_code',
      }).toString(),
      { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
    );

    const credsFile = path.join(CREDS_DIR, `${ACCOUNT_EMAIL}.json`);
    fs.writeFileSync(credsFile, JSON.stringify({ ...data, email: ACCOUNT_EMAIL, client_id: CLIENT_ID, client_secret: CLIENT_SECRET }, null, 2));
    console.log(`\nCredentials saved → ${credsFile}`);
    res.end('<h2>Auth complete — you can close this tab.</h2>');
  } catch (err) {
    console.error('Token exchange failed:', err.response?.data || err.message);
    res.end('Error: token exchange failed. Check terminal.');
  }

  server.close();
});

server.listen(3000, () => console.log('Waiting for OAuth callback on port 3000...'));
