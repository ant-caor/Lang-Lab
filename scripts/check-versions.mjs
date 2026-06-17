#!/usr/bin/env node
// Version watcher: query endoflife.date for the latest stable release of each
// registered language and update versions.lock.json. Zero dependencies.
//
// Skips baseline / manually-pinned languages. Exits NON-ZERO if a tracked feed is
// unreachable or has no `latest` release (so a pin can't silently rot). Writes the
// updated-language list to $GITHUB_OUTPUT when running inside GitHub Actions.
import { readFile, writeFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const registry = JSON.parse(await readFile(new URL("languages.json", root)));
const lockUrl = new URL("versions.lock.json", root);
const lock = JSON.parse(await readFile(lockUrl));

const updates = [];
const failures = [];

for (const [lang, cfg] of Object.entries(registry)) {
  // Baseline (C) and manually-pinned langs (e.g. Swift - no endoflife feed) are skipped.
  if (cfg.baseline || cfg.versionSource === "manual" || !cfg.eol) continue;
  const res = await fetch(`https://endoflife.date/api/${cfg.eol}.json`);
  if (!res.ok) {
    failures.push(`${lang}: endoflife.date/${cfg.eol} returned ${res.status}`);
    continue;
  }
  const cycles = await res.json();
  // The newest cycle is first. Require a concrete `latest` patch - never pin a bare
  // cycle label (e.g. "3.14"), which is not a precise reproducible version.
  const latest = cycles[0]?.latest;
  if (!latest) {
    failures.push(`${lang}: endoflife feed has no 'latest' release`);
    continue;
  }
  if (lock[lang] !== String(latest)) {
    updates.push({ lang, from: lock[lang], to: String(latest) });
    lock[lang] = String(latest);
  }
}

if (updates.length > 0) {
  await writeFile(lockUrl, JSON.stringify(lock, null, 2) + "\n");
  for (const u of updates) console.log(`updated ${u.lang}: ${u.from} -> ${u.to}`);
  if (process.env.GITHUB_OUTPUT) {
    const list = updates.map((u) => u.lang).join(",");
    await writeFile(process.env.GITHUB_OUTPUT, `updated=${list}\n`, { flag: "a" });
  }
} else {
  console.log("up-to-date");
}

if (failures.length > 0) {
  console.error(`\n! ${failures.length} tracked feed(s) failed - fix the slug or mark versionSource:"manual":`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exitCode = 1; // surface rot instead of silently skipping a language
}
