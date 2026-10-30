#!/usr/bin/env node
/**
 * Enforces a consistent package manager across the AI infra project.
 * Writes CLAUDE_PACKAGE_MANAGER into the appropriate config files
 * so Claude Code always uses the right tool regardless of environment.
 *
 * Usage:
 *   node scripts/setup-package-manager.js --global pnpm
 *   node scripts/setup-package-manager.js --project bun
 *   node scripts/setup-package-manager.js --detect
 */

const nodeChild_process = require("node:child_process");
const { readFileSync, writeFileSync, existsSync } = require("node:fs");
const { homedir } = require("node:os");
const { join } = require("node:path");

const SUPPORTED = ["pnpm", "bun", "npm", "yarn"];
const GLOBAL_SETTINGS = join(homedir(), ".claude", "settings.json");
const LOCAL_SETTINGS = join(process.cwd(), ".claude", "settings.local.json");

// ── CLI parsing ──────────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const flag = args[0];
const manager = args[1];

if (flag === "--detect") {
  detect();
} else if (flag === "--global" && manager) {
  setGlobal(manager);
} else if (flag === "--project" && manager) {
  setProject(manager);
} else {
  console.log(`
Usage:
  node scripts/setup-package-manager.js --detect
  node scripts/setup-package-manager.js --global pnpm
  node scripts/setup-package-manager.js --project bun

Supported managers: ${SUPPORTED.join(", ")}
  `);
  process.exit(1);
}

// ── Commands ─────────────────────────────────────────────────────────────────

function detect() {
  const envVal = process.env.CLAUDE_PACKAGE_MANAGER;
  const globalVal = readJsonKey(GLOBAL_SETTINGS, ["env", "CLAUDE_PACKAGE_MANAGER"]);
  const localVal = readJsonKey(LOCAL_SETTINGS, ["env", "CLAUDE_PACKAGE_MANAGER"]);

  console.log("Package manager detection:");
  console.log(`  env var CLAUDE_PACKAGE_MANAGER : ${envVal || "(not set)"}`);
  console.log(`  global settings (~/.claude)    : ${globalVal || "(not set)"}`);
  console.log(`  project settings (.claude/)    : ${localVal || "(not set)"}`);

  // Installed check
  for (const pm of SUPPORTED) {
    try {
      const ver = nodeChild_process.execSync(`${pm} --version`, { stdio: "pipe" }).toString().trim();
      console.log(`  ${pm.padEnd(6)} installed: ${ver}`);
    } catch {
      // not installed
    }
  }
}

function setGlobal(pm) {
  validate(pm);
  const settings = loadJson(GLOBAL_SETTINGS);
  settings.env = settings.env || {};
  settings.env.CLAUDE_PACKAGE_MANAGER = pm;
  writeFileSync(GLOBAL_SETTINGS, JSON.stringify(settings, null, 2) + "\n");
  console.log(`Global package manager set to '${pm}' in ${GLOBAL_SETTINGS}`);
}

function setProject(pm) {
  validate(pm);
  const settings = loadJson(LOCAL_SETTINGS);
  settings.env = settings.env || {};
  settings.env.CLAUDE_PACKAGE_MANAGER = pm;
  writeFileSync(LOCAL_SETTINGS, JSON.stringify(settings, null, 2) + "\n");
  console.log(`Project package manager set to '${pm}' in ${LOCAL_SETTINGS}`);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function validate(pm) {
  if (!SUPPORTED.includes(pm)) {
    console.error(`Error: '${pm}' is not supported. Choose from: ${SUPPORTED.join(", ")}`);
    process.exit(1);
  }
}

function loadJson(path) {
  if (!existsSync(path)) return {};
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return {};
  }
}

function readJsonKey(path, keys) {
  const obj = loadJson(path);
  return keys.reduce((acc, k) => (acc && typeof acc === "object" ? acc[k] : undefined), obj);
}
