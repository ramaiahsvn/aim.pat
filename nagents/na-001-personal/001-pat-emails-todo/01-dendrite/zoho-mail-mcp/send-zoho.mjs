// One-off HTML send through Zoho Mail, reusing the credentials the zoho-mail MCP already holds.
// The MCP's own send_message hardcodes mailFormat:'plaintext', which cannot carry the house HTML
// format — so this posts the same endpoint with mailFormat:'html'.
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import os from 'os';

const ACCOUNT = 'ramaiah@bnprs.in';
const CREDS_FILE = path.join(os.homedir(), '.zoho-mail-mcp', `${ACCOUNT}.json`);
const BASE_URL = 'https://mail.zoho.com/api';

let creds = JSON.parse(fs.readFileSync(CREDS_FILE, 'utf8'));

async function refreshToken() {
  const { data } = await axios.post(
    'https://accounts.zoho.com/oauth/v2/token',
    new URLSearchParams({
      refresh_token: creds.refresh_token,
      client_id: creds.client_id,
      client_secret: creds.client_secret,
      grant_type: 'refresh_token',
    }).toString(),
    { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
  );
  creds = { ...creds, ...data, expiry_date: Date.now() + data.expires_in * 1000 };
  fs.writeFileSync(CREDS_FILE, JSON.stringify(creds, null, 2));
  return creds.access_token;
}

async function getToken() {
  if (!creds.expiry_date || Date.now() > creds.expiry_date - 60_000) return refreshToken();
  return creds.access_token;
}

async function api(method, endpoint, body = null) {
  const token = await getToken();
  const cfg = { method, url: `${BASE_URL}${endpoint}`,
                headers: { Authorization: `Zoho-oauthtoken ${token}` } };
  if (body) cfg.data = body;
  const { data } = await axios(cfg);
  return data;
}

const [, , htmlPath, to, cc, subject, dryRun] = process.argv;

const accounts = (await api('GET', '/accounts')).data || [];
const acct = accounts.find(a => a.primaryEmailAddress === ACCOUNT);
if (!acct) {
  console.error(`FAILED: ${ACCOUNT} not among`, accounts.map(a => a.primaryEmailAddress));
  process.exit(1);
}
console.log('  from      ', acct.primaryEmailAddress, '(accountId', acct.accountId + ')');
console.log('  to        ', to);
if (cc) console.log('  cc        ', cc);
console.log('  subject   ', subject);

const html = fs.readFileSync(htmlPath, 'utf8');
console.log('  body      ', html.length, 'bytes of HTML');

if (dryRun === 'dry') { console.log('  DRY RUN — nothing sent'); process.exit(0); }

const body = {
  fromAddress: ACCOUNT,
  toAddress: to,
  subject,
  content: html,
  mailFormat: 'html',
};
if (cc) body.ccAddress = cc;

const res = await api('POST', `/accounts/${acct.accountId}/messages`, body);
console.log('  SENT      messageId =', res.data?.messageId ?? JSON.stringify(res).slice(0, 200));
