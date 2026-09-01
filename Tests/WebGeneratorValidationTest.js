const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const javascript = require(path.join(root, ".html", "buildplanner", "javascript", "gbp1.js"));
const pythonPath = path.join(root, ".html", "buildplanner", "python", "gbp1.py");
const phpPath = path.join(root, ".html", "buildplanner", "php", "gbp1.php");

function baseBuild() {
    return {
        name: "Validation Test",
        selectedSetup: 1,
        setups: [{
            name: "Base Setup",
            equipment: {}, alternatives: {},
            skillBars: { front: [], back: [] },
            character: { attributes: { health: 0, magicka: 0, stamina: 64 } },
            champion: {
                craft: { allocations: [], slottables: [] },
                warfare: { allocations: [], slottables: [] },
                fitness: { allocations: [], slottables: [] }
            },
            consumables: [], checklist: [], buffAssumptions: {}
        }]
    };
}

function clone(value) { return JSON.parse(JSON.stringify(value)); }

const cases = [
    ["attribute total above 64", build => { build.setups[0].character.attributes.health = 1; }],
    ["duplicate Champion IDs", build => { build.setups[0].champion.craft.allocations = [
        { skillId: 1, name: "One", points: 10 }, { skillId: 1, name: "Again", points: 10 }
    ]; }],
    ["unallocated Champion slottable", build => { build.setups[0].champion.craft.slottables = [99]; }],
    ["duplicated Champion slottable", build => {
        build.setups[0].champion.craft.allocations = [{ skillId: 1, name: "One", points: 10, isSlottable: true }];
        build.setups[0].champion.craft.slottables = [1, 1];
    }],
    ["alternative without primary", build => { build.setups[0].alternatives.head = [{ itemName: "Alternative" }]; }],
    ["two-handed weapon with off-hand", build => {
        build.setups[0].equipment.frontMain = { itemName: "Greatsword", weaponType: 6 };
        build.setups[0].equipment.frontOff = { itemName: "Shield", weaponType: 14 };
    }],
    ["more than six skills", build => { build.setups[0].skillBars.front = Array.from({ length: 7 },
        (_, index) => ({ abilityId: index + 1 })); }],
    ["more than four Champion slots", build => { build.setups[0].champion.craft.slottables = [1, 2, 3, 4, 5]; }],
    ["too many consumables", build => { build.setups[0].consumables = Array.from({ length: 21 },
        () => ({ category: "food", name: "Food" })); }],
    ["too many checklist entries", build => { build.setups[0].checklist = Array.from({ length: 101 },
        () => ({ category: "other", name: "Step" })); }],
    ["invalid route", build => { build.setups[0].equipment.head = { preferredRoute: "teleport" }; }],
    ["invalid consumable category", build => { build.setups[0].consumables = [{ category: "snack", name: "Food" }]; }],
    ["invalid checklist detection", build => { build.setups[0].checklist = [
        { category: "other", name: "Step", detection: { kind: "guess" } }
    ]; }],
    ["weapon type on armor", build => { build.setups[0].equipment.head = { weaponType: 3 }; }],
    ["armor type on jewelry", build => { build.setups[0].equipment.neck = { armorType: 1 }; }],
    ["armor trait on weapon", build => { build.setups[0].equipment.frontMain = { weaponType: 3, traitType: 18 }; }],
    ["unknown weapon type", build => { build.setups[0].equipment.frontMain = { weaponType: 10 }; }],
    ["invalid quality override", build => { build.setups[0].equipment.head = { quality: 6 }; }],
    ["invalid level override", build => { build.setups[0].equipment.head = { level: 51 }; }],
    ["invalid Champion Point increment", build => { build.setups[0].equipment.head = { championPoints: 15 }; }],
    ["unsafe source URL", build => { build.sourceUrl = "javascript:alert(1)"; }],
    ["unsafe icon scheme", build => { build.setups[0].skillBars.front = [{ abilityId: 1, icon: "data:text/html,bad" }]; }],
    ["malformed ESO item link", build => { build.setups[0].equipment.head = { itemLink: "not-an-item-link" }; }],
    ["non-string metadata", build => { build.role = { label: "Damage" }; }],
    ["negative ID", build => { build.setups[0].equipment.head = { itemId: -1 }; }],
    ["fractional points", build => { build.setups[0].champion.craft.allocations = [
        { skillId: 1, name: "One", points: 1.5 }
    ]; }],
    ["oversized string", build => { build.name = "x".repeat(101); }],
    ["wrong container type", build => { build.setups = {}; }]
];

function javascriptRejects(build) {
    try { javascript.encodeBuild(build); return false; } catch (_) { return true; }
}

function runBuild(command, args, build) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "gbp-validation-"));
    const file = path.join(directory, "build.json");
    try {
        fs.writeFileSync(file, JSON.stringify(build));
        return spawnSync(command, args.concat(file), { cwd: root, encoding: "utf8" });
    } finally {
        fs.rmSync(directory, { recursive: true, force: true });
    }
}

function findPython() {
    const commands = process.platform === "win32" ? [["py", ["-3", pythonPath]], ["python", [pythonPath]]]
        : [["python3", [pythonPath]], ["python", [pythonPath]]];
    for (const [command, args] of commands) {
        const probe = spawnSync(command, ["--version"], { encoding: "utf8" });
        if (!probe.error && probe.status === 0) return [command, args];
    }
    throw new Error("Python is unavailable");
}

const python = findPython();
const valid = baseBuild();
javascript.encodeBuild(valid);
const validPython = runBuild(python[0], python[1], valid);
if (validPython.status !== 0) throw new Error(`Python could not encode the valid baseline: ${validPython.stderr || validPython.error || "unknown failure"}`);
const validPhp = runBuild("php", [phpPath], valid);
if (validPhp.status !== 0) throw new Error(`PHP could not encode the valid baseline: ${validPhp.stderr || validPhp.error || "unknown failure"}`);

for (const [name, mutate] of cases) {
    const build = clone(baseBuild());
    mutate(build);
    const results = {
        JavaScript: javascriptRejects(build),
        Python: runBuild(python[0], python[1], build).status !== 0,
        PHP: runBuild("php", [phpPath], build).status !== 0
    };
    for (const [language, rejected] of Object.entries(results)) {
        if (!rejected) throw new Error(`${language} accepted invalid case: ${name}`);
    }
}

process.stdout.write(`PASS ${cases.length} invalid build cases rejected by JavaScript, Python, and PHP\n`);
