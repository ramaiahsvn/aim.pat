#!/usr/bin/env node
/**
 * Zoho Mail MCP Server
 * Env: ZOHO_ACCOUNT_EMAIL — which account to serve (maps to ~/.zoho-mail-mcp/<email>.json)
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import axios from 'axios';
import fs from 'fs';
import path from 'path';
import os from 'os';

const ACCOUNT_EMAIL = process.env.ZOHO_ACCOUNT_EMAIL;
const CREDS_DIR     = path.join(os.homedir(), '.zoho-mail-mcp');
const CREDS_FILE    = path.join(CREDS_DIR, `${ACCOUNT_EMAIL}.json`);
const BASE_URL      = 'https://mail.zoho.com/api';

if (!ACCOUNT_EMAIL) {
  console.error('Required: ZOHO_ACCOUNT_EMAIL env var');
  process.exit(1);
}

// ── Token management ──────────────────────────────────────────────────────────

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
  if (!creds.expiry_date || Date.now() > creds.expiry_date - 60_000) {
    return refreshToken();
  }
  return creds.access_token;
}

async function api(method, endpoint, params = {}, body = null) {
  const token = await getToken();
  const config = {
    method,
    url: `${BASE_URL}${endpoint}`,
    headers: { Authorization: `Zoho-oauthtoken ${token}` },
    params,
  };
  if (body) config.data = body;
  const { data } = await axios(config);
  return data;
}

// ── Zoho account ID resolution ────────────────────────────────────────────────

let _accountId = null;
async function getAccountId() {
  if (_accountId) return _accountId;
  const data = await api('GET', '/accounts');
  const accounts = data.data || [];
  const match = accounts.find(a => a.primaryEmailAddress === ACCOUNT_EMAIL) || accounts[0];
  _accountId = match?.accountId;
  return _accountId;
}

// ── MCP server ────────────────────────────────────────────────────────────────

const server = new Server(
  { name: `zoho-mail-${ACCOUNT_EMAIL}`, version: '1.0.0' },
  { capabilities: { tools: {} } }
);

const TOOLS = [
  {
    name: 'list_messages',
    description: `List messages in a folder for ${ACCOUNT_EMAIL}`,
    inputSchema: {
      type: 'object',
      properties: {
        folder:  { type: 'string', description: 'Folder name (default: Inbox)' },
        limit:   { type: 'number', description: 'Max results (default: 20)' },
        searchKey: { type: 'string', description: 'Optional search keyword' },
      },
    },
  },
  {
    name: 'get_message',
    description: `Get full content of a message for ${ACCOUNT_EMAIL}`,
    inputSchema: {
      type: 'object',
      required: ['message_id'],
      properties: {
        message_id: { type: 'string' },
      },
    },
  },
  {
    name: 'send_message',
    description: `Send an email from ${ACCOUNT_EMAIL} — REQUIRES user confirmation`,
    inputSchema: {
      type: 'object',
      required: ['to', 'subject', 'content'],
      properties: {
        to:      { type: 'string', description: 'Recipient email address' },
        subject: { type: 'string' },
        content: { type: 'string', description: 'Plain text body' },
        cc:      { type: 'string' },
        bcc:     { type: 'string' },
      },
    },
  },
  {
    name: 'create_draft',
    description: `Save a draft email for ${ACCOUNT_EMAIL}`,
    inputSchema: {
      type: 'object',
      required: ['to', 'subject', 'content'],
      properties: {
        to:      { type: 'string' },
        subject: { type: 'string' },
        content: { type: 'string' },
        cc:      { type: 'string' },
      },
    },
  },
  {
    name: 'list_folders',
    description: `List all folders/labels for ${ACCOUNT_EMAIL}`,
    inputSchema: { type: 'object', properties: {} },
  },
  {
    name: 'move_message',
    description: `Move a message to a different folder for ${ACCOUNT_EMAIL}`,
    inputSchema: {
      type: 'object',
      required: ['message_id', 'folder_id'],
      properties: {
        message_id: { type: 'string' },
        folder_id:  { type: 'string' },
      },
    },
  },

  // ── Zoho Mail Tasks (to-do) ──────────────────────────────────────────────
  {
    name: 'list_tasks',
    description: `List personal to-do tasks for ${ACCOUNT_EMAIL}`,
    inputSchema: {
      type: 'object',
      properties: {
        status: { type: 'string', description: "Optional filter: 'inprogress' or 'completed'" },
        limit:  { type: 'number', description: 'Max results' },
      },
    },
  },
  {
    name: 'get_task',
    description: `Get a single task by id for ${ACCOUNT_EMAIL}`,
    inputSchema: {
      type: 'object',
      required: ['task_id'],
      properties: { task_id: { type: 'string' } },
    },
  },
  {
    name: 'create_task',
    description: `Create a personal to-do task for ${ACCOUNT_EMAIL}. Set message_id to link the task to the email it came from.`,
    inputSchema: {
      type: 'object',
      required: ['title'],
      properties: {
        title:       { type: 'string', description: 'Task name (required)' },
        description: { type: 'string' },
        priority:    { type: 'string', description: "high | medium | low" },
        due_date:    { type: 'string', description: 'Due date, format DD/MM/YYYY' },
        status:      { type: 'string', description: "inprogress | completed (default inprogress)" },
        message_id:  { type: 'string', description: 'Source email id to link the task to' },
        email_reminder: { type: 'boolean' },
        reminder_date:  { type: 'string', description: 'ISO 8601 reminder time (requires a reminder type)' },
      },
    },
  },
  {
    name: 'update_task',
    description: `Update fields of an existing task for ${ACCOUNT_EMAIL}`,
    inputSchema: {
      type: 'object',
      required: ['task_id'],
      properties: {
        task_id:     { type: 'string' },
        title:       { type: 'string' },
        description: { type: 'string' },
        priority:    { type: 'string', description: "high | medium | low" },
        due_date:    { type: 'string', description: 'DD/MM/YYYY' },
        status:      { type: 'string', description: "inprogress | completed" },
      },
    },
  },
  {
    name: 'complete_task',
    description: `Mark a task as completed for ${ACCOUNT_EMAIL}`,
    inputSchema: {
      type: 'object',
      required: ['task_id'],
      properties: { task_id: { type: 'string' } },
    },
  },
  {
    name: 'delete_task',
    description: `Delete a task for ${ACCOUNT_EMAIL} — destructive, confirm with the user first`,
    inputSchema: {
      type: 'object',
      required: ['task_id'],
      properties: { task_id: { type: 'string' } },
    },
  },
];

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;
  const accountId = await getAccountId();

  try {
    let result;

    if (name === 'list_messages') {
      const folder = args.folder || 'Inbox';
      const params = { limit: args.limit || 20 };
      if (args.searchKey) params.searchKey = args.searchKey;
      const data = await api('GET', `/accounts/${accountId}/messages/view`, { folderId: folder, ...params });
      result = data.data || [];
    }

    else if (name === 'get_message') {
      const data = await api('GET', `/accounts/${accountId}/messages/${args.message_id}/content`);
      result = data.data || data;
    }

    else if (name === 'send_message') {
      const body = {
        fromAddress: ACCOUNT_EMAIL,
        toAddress: args.to,
        subject: args.subject,
        content: args.content,
        mailFormat: 'plaintext',
      };
      if (args.cc)  body.ccAddress  = args.cc;
      if (args.bcc) body.bccAddress = args.bcc;
      const data = await api('POST', `/accounts/${accountId}/messages`, {}, body);
      result = { status: 'sent', messageId: data.data?.messageId };
    }

    else if (name === 'create_draft') {
      const body = {
        fromAddress: ACCOUNT_EMAIL,
        toAddress: args.to,
        subject: args.subject,
        content: args.content,
        mailFormat: 'plaintext',
        action: 'save',
      };
      if (args.cc) body.ccAddress = args.cc;
      const data = await api('POST', `/accounts/${accountId}/messages`, {}, body);
      result = { status: 'draft_saved', messageId: data.data?.messageId };
    }

    else if (name === 'list_folders') {
      const data = await api('GET', `/accounts/${accountId}/folders`);
      result = data.data || [];
    }

    else if (name === 'move_message') {
      const data = await api('PUT', `/accounts/${accountId}/messages/${args.message_id}/move`, {}, { folderId: args.folder_id });
      result = { status: 'moved', ...data };
    }

    // ── Tasks (to-do) — top-level /tasks/me, no accountId in path ──
    else if (name === 'list_tasks') {
      const params = {};
      if (args.status) params.status = args.status;
      if (args.limit)  params.limit = args.limit;
      const data = await api('GET', '/tasks/me', params);
      result = data.data || data;
    }

    else if (name === 'get_task') {
      const data = await api('GET', `/tasks/me/${args.task_id}`);
      result = data.data || data;
    }

    else if (name === 'create_task') {
      const body = { title: args.title };
      if (args.description) body.description = args.description;
      if (args.priority)    body.priority = args.priority;
      if (args.due_date)    body.dueDate = args.due_date;
      body.status = args.status || 'inprogress';
      if (args.message_id)  { body.messageId = args.message_id; body.accountId = accountId; }
      if (args.reminder_date) { body.reminderDate = args.reminder_date; body.emailReminder = args.email_reminder !== false; }
      else if (args.email_reminder) body.emailReminder = true;
      const data = await api('POST', '/tasks/me', {}, body);
      result = { status: 'created', id: data.data?.id || data.id, ...(data.data || data) };
    }

    else if (name === 'update_task') {
      const body = {};
      if (args.title)       body.title = args.title;
      if (args.description) body.description = args.description;
      if (args.priority)    body.priority = args.priority;
      if (args.due_date)    body.dueDate = args.due_date;
      if (args.status)      body.status = args.status;
      const data = await api('PUT', `/tasks/me/${args.task_id}`, {}, body);
      result = { status: 'updated', ...(data.data || data) };
    }

    else if (name === 'complete_task') {
      const data = await api('PUT', `/tasks/me/${args.task_id}`, {}, { status: 'completed' });
      result = { status: 'completed', ...(data.data || data) };
    }

    else if (name === 'delete_task') {
      const data = await api('DELETE', `/tasks/me/${args.task_id}`);
      result = { status: 'deleted', ...(data.data || data) };
    }

    else {
      throw new Error(`Unknown tool: ${name}`);
    }

    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  } catch (err) {
    const msg = err.response?.data ? JSON.stringify(err.response.data) : err.message;
    return { content: [{ type: 'text', text: `Error: ${msg}` }], isError: true };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
