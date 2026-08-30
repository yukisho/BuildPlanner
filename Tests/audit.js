const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const fengariScript = path.join(
  root,
  "node_modules",
  "fengari-node-cli",
  "src",
  "lua-cli.js"
);

function fail(message, output = "") {
  process.stderr.write(`FAIL ${message}\n${output}`);
  process.exit(1);
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    ...options,
  });
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  if (result.error || result.status !== 0) {
    fail(`${command} ${args.join(" ")}`, output || String(result.error));
  }
  return output;
}

if (!fs.existsSync(fengariScript)) {
  fail("test dependency missing; run: npm install\n");
}

const dataOutput = run(process.execPath, [fengariScript, "Tests/DataTests.lua"]);
if (!dataOutput.includes("Build Planner data tests passed") || dataOutput.includes("stack traceback")) {
  fail("data tests", dataOutput);
}
process.stdout.write("PASS data tests\n");

const uiOutput = run(process.execPath, [fengariScript, "Tests/UITests.lua"]);
if (!uiOutput.includes("Build Planner UI tests passed") || uiOutput.includes("stack traceback")) {
  fail("UI tests", uiOutput);
}
process.stdout.write("PASS UI tests\n");

function collectLua(directory, prefix = "") {
  const files = [];
  const skipped = new Set(["node_modules", ".lua-lint", ".history", ".git"]);
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (skipped.has(entry.name)) continue;
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      files.push(...collectLua(path.join(directory, entry.name), relative));
    } else if (entry.name.endsWith(".lua")) {
      files.push(relative);
    }
  }
  return files;
}

const luaFiles = collectLua(root);
for (const file of luaFiles) {
  const normalized = file.replace(/\\/g, "/");
  const output = run(process.execPath, [
    fengariScript,
    "-e",
    `assert(loadfile([==[${normalized}]==]))`,
  ]);
  if (output.includes("stack traceback")) fail(`Lua 5.1 parse: ${file}`, output);
}
process.stdout.write(`PASS Lua 5.1 parse (${luaFiles.length} files)\n`);

function localizationEntries(file) {
  const text = fs.readFileSync(path.join(root, file), "utf8");
  const entries = new Map();
  const pattern = /(SI_GRAVVY_BUILD_PLANNER_[A-Z0-9_]+)[^\n]*?[=:,]\s*["']([^\n]*?)["'](?:\)|,)/g;
  let match;
  while ((match = pattern.exec(text))) {
    const placeholders = [...match[2].matchAll(/<<(\d+)>>/g)].map((item) => item[1]).sort().join(",");
    entries.set(match[1], placeholders);
  }
  return entries;
}

const languages = ["Localization/en.lua", "Localization/es.lua", "Localization/fr.lua"];
const base = localizationEntries(languages[0]);
for (const language of languages.slice(1)) {
  const entries = localizationEntries(language);
  if (entries.size !== base.size) fail(`localization key count: ${language}`);
  for (const [key, placeholders] of base) {
    if (!entries.has(key) || entries.get(key) !== placeholders) {
      fail(`localization parity: ${language} ${key}`);
    }
  }
}
process.stdout.write(`PASS localization parity (${base.size} keys)\n`);

const manifestText = fs.readFileSync(path.join(root, "GravvyBuildPlanner.txt"), "utf8");
const manifestFiles = manifestText
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#") && /\.(lua|xml)$/i.test(line));
for (const file of manifestFiles) {
  if (!fs.existsSync(path.join(root, file))) fail(`missing manifest file: ${file}`);
}
const rootRuntimeLua = fs.readdirSync(root).filter((file) => file.endsWith(".lua"));
for (const file of rootRuntimeLua) {
  if (!manifestFiles.includes(file)) fail(`runtime Lua omitted from manifest: ${file}`);
}
process.stdout.write(`PASS manifest coverage (${manifestFiles.length} files)\n`);

run("git", ["diff", "--check"]);
process.stdout.write("PASS git diff --check\nBuild Planner audit passed\n");
