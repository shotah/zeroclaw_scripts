#!/usr/bin/env node
'use strict';

/**
 * Sync .env → data/.zeroclaw/config.toml from config/config.toml.example.
 * Host-side only (no Node in the container). Requires Node on the host for sync.
 */

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const envPath = path.join(root, '.env');
const examplePath = path.join(root, 'config', 'config.toml.example');
const outDir = path.join(root, 'data', '.zeroclaw');
const outPath = path.join(outDir, 'config.toml');

function loadDotEnv(file) {
  const env = {};
  if (!fs.existsSync(file)) return env;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    env[key] = val;
  }
  return env;
}

function tomlStringArray(csv) {
  const items = String(csv || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (items.length === 0) return '[]';
  return `[${items.map((id) => `"${id.replace(/"/g, '')}"`).join(', ')}]`;
}

function main() {
  if (!fs.existsSync(examplePath)) {
    console.error(`Missing ${examplePath}`);
    process.exit(1);
  }

  const fileEnv = loadDotEnv(envPath);
  const get = (k, fallback = '') =>
    process.env[k] !== undefined && process.env[k] !== ''
      ? process.env[k]
      : fileEnv[k] !== undefined
        ? fileEnv[k]
        : fallback;

  const model = get('GEMINI_MODEL', 'gemini-2.5-flash');
  const allowed = tomlStringArray(get('TELEGRAM_ALLOWED_USERS', ''));

  let toml = fs.readFileSync(examplePath, 'utf8');

  // Replace model line under gemini.default
  toml = toml.replace(
    /(\[providers\.models\.gemini\.default\][\s\S]*?model\s*=\s*")[^"]*(")/,
    `$1${model}$2`
  );

  // Replace allowed_users array under telegram.default
  toml = toml.replace(
    /(\[channels\.telegram\.default\][\s\S]*?allowed_users\s*=\s*)\[[^\]]*\]/,
    `$1${allowed}`
  );

  fs.mkdirSync(outDir, { recursive: true });
  fs.mkdirSync(path.join(root, 'data', 'data'), { recursive: true });
  fs.writeFileSync(outPath, toml.endsWith('\n') ? toml : `${toml}\n`);

  console.log(`Wrote ${outPath}`);
  console.log(`  providers.models.gemini.default.model = ${model}`);
  console.log(`  channels.telegram.default.allowed_users = ${allowed}`);
  console.log('  api_key / bot_token come from compose env overrides (.env)');
}

main();
