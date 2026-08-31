const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const buildRoot = path.join(root, "Build");
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

const generatorOutput = run(process.execPath, [
  ".html/buildplanner/javascript/gbp1.js",
  ".html/buildplanner/example-build.json",
]).trim();
const generatorImportOutput = run(process.execPath, [
  fengariScript,
  "Tests/GeneratorImportTest.lua",
  generatorOutput,
]);
if (!generatorImportOutput.includes("Build Planner generator import test passed")) {
  fail("GBP1 generator import", generatorImportOutput);
}
process.stdout.write("PASS GBP1 generator import\n");

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

const languages = [
  "Build/Localization/en.lua",
  "Build/Localization/es.lua",
  "Build/Localization/fr.lua",
];
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

const manifestText = fs.readFileSync(
  path.join(buildRoot, "GravvyBuildPlanner.txt"),
  "utf8"
);
const manifestFiles = manifestText
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#") && /\.(lua|xml)$/i.test(line));
for (const file of manifestFiles) {
  if (!fs.existsSync(path.join(buildRoot, file))) fail(`missing manifest file: ${file}`);
}
function collectRuntimeFiles(directory, prefix = "") {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      files.push(...collectRuntimeFiles(path.join(directory, entry.name), relative));
    } else if (/\.(lua|xml)$/i.test(entry.name)) {
      files.push(relative);
    }
  }
  return files;
}
for (const file of collectRuntimeFiles(buildRoot)) {
  if (!manifestFiles.includes(file)) fail(`runtime file omitted from manifest: ${file}`);
}
process.stdout.write(`PASS manifest coverage (${manifestFiles.length} files)\n`);

const savedVariables = (manifestText.match(/^## SavedVariables:\s*(.+)$/m)?.[1] || "")
  .trim()
  .split(/\s+/)
  .filter(Boolean);
for (const required of ["GravvyBuildPlanner_Data", "GravvyBuildPlanner_RecoveryData"]) {
  if (!savedVariables.includes(required)) fail(`missing SavedVariables owner: ${required}`);
}
process.stdout.write("PASS SavedVariables ownership\n");

for (const file of manifestFiles.filter((file) => file.endsWith(".xml"))) {
  const source = fs.readFileSync(path.join(buildRoot, file), "utf8");
  if (/<(?:CenterColor|EdgeColor)\b/i.test(source)) {
    fail(`invalid backdrop color element: ${file}`);
  }
}
process.stdout.write("PASS XML backdrop elements\n");

for (const file of manifestFiles.filter((file) => file.endsWith(".lua"))) {
  const source = fs.readFileSync(path.join(buildRoot, file), "utf8");
  if (/CreateControlFromVirtual\s*\(\s*nil\b/s.test(source)) {
    fail(`anonymous virtual control: ${file}`);
  }
}
process.stdout.write("PASS virtual-control naming\n");

const manifestApis = (manifestText.match(/^## APIVersion:\s*([\d ]+)/m)?.[1] || "")
  .trim()
  .split(/\s+/)
  .filter(Boolean)
  .map(Number);
const resolverText = fs.readFileSync(
  path.join(buildRoot, "Features", "ItemResolver.lua"),
  "utf8"
);
const testedApi = Number(resolverText.match(/TESTED_API_VERSION\s*=\s*(\d+)/)?.[1]);
const supportedApis = [...resolverText.matchAll(/\[(10\d+)\]\s*=\s*true/g)]
  .map((match) => Number(match[1]));
if (!testedApi || manifestApis[manifestApis.length - 1] !== testedApi) {
  fail(`item-link API baseline: manifest ${manifestApis.join(",")}, resolver ${testedApi}`);
}
for (const api of supportedApis) {
  if (!manifestApis.includes(api)) fail(`supported API missing from manifest: ${api}`);
}
const manifestAddonVersion = Number(manifestText.match(/^## AddOnVersion:\s*(\d+)/m)?.[1]);
if (!manifestAddonVersion) fail("missing manifest AddOnVersion");
process.stdout.write(`PASS item-link API baseline (${testedApi})\n`);

function requireBefore(dependency, dependent) {
  const dependencyIndex = manifestFiles.indexOf(dependency);
  const dependentIndex = manifestFiles.indexOf(dependent);
  if (dependencyIndex < 0 || dependentIndex < 0 || dependencyIndex > dependentIndex) {
    fail(`manifest load order: ${dependency} before ${dependent}`);
  }
}

for (const [dependency, dependent] of [
  ["UI/Shared/UIHelpers.lua", "UI/Keyboard/UI.lua"],
  ["UI/Shared/Help.lua", "UI/Keyboard/UI.lua"],
  ["UI/Shared/Help.lua", "UI/Gamepad/GamepadDialogs.lua"],
  ["Core/EquipmentSlots.lua", "Core/Data.lua"],
  ["Core/ModelValidation.lua", "Core/Data.lua"],
  ["Core/Data.lua", "Core/Inventory.lua"],
  ["Features/BuffAssumptions.lua", "Features/StatImpact.lua"],
  ["Features/ItemResolver.lua", "Features/Acquisition.lua"],
  ["Features/Acquisition.lua", "Core/Inventory.lua"],
  ["Features/Readiness.lua", "Features/Walkthrough.lua"],
  ["UI/Shared/Accessibility.lua", "UI/Keyboard/UI.lua"],
  ["UI/Keyboard/UI.lua", "UI/Keyboard/RevisionHistory.lua"],
  ["UI/Keyboard/UI.lua", "UI/Keyboard/BuffAssumptionsUI.lua"],
  ["UI/Gamepad/Gamepad.lua", "UI/Gamepad/GamepadDialogs.lua"],
  ["UI/Gamepad/GamepadDialogs.lua", "GravvyBuildPlanner.lua"],
]) {
  requireBefore(dependency, dependent);
}
if (manifestFiles[manifestFiles.length - 1] !== "Bindings.xml"
    || manifestFiles[manifestFiles.length - 2] !== "GravvyBuildPlanner.lua") {
  fail("manifest load order: bootstrap and bindings must remain last");
}
process.stdout.write("PASS manifest load order\n");

run("git", ["diff", "--check"]);
process.stdout.write("PASS git diff --check\nBuild Planner audit passed\n");
