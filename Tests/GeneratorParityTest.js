const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.resolve(__dirname, "..");
const fixturePath = path.join(root, ".html", "buildplanner", "example-build.json");
const javascriptPath = path.join(root, ".html", "buildplanner", "javascript", "gbp1.js");
const pythonPath = path.join(root, ".html", "buildplanner", "python", "gbp1.py");
const phpPath = path.join(root, ".html", "buildplanner", "php", "gbp1.php");
const expectedLength = 6300;
const expectedHash = "44580d21440935a2d32d36c1fd1f85a83571154e4a07a15d186f36e1a3a8736b";

function fail(message, output = "") {
    process.stderr.write(`FAIL ${message}\n${output}`);
    process.exit(1);
}

function run(command, args) {
    const result = spawnSync(command, args, { cwd: root, encoding: "utf8" });
    if (result.error || result.status !== 0) {
        return { ok: false, output: `${result.stdout || ""}${result.stderr || ""}${result.error || ""}` };
    }
    return { ok: true, output: result.stdout.trim() };
}

function runPython() {
    const candidates = process.platform === "win32"
        ? [["py", ["-3", pythonPath, fixturePath]], ["python", [pythonPath, fixturePath]]]
        : [["python3", [pythonPath, fixturePath]], ["python", [pythonPath, fixturePath]]];
    const failures = [];
    for (const [command, args] of candidates) {
        const result = run(command, args);
        if (result.ok) return result.output;
        failures.push(`${command}: ${result.output}`);
    }
    fail("Python generator could not run", failures.join("\n"));
}

function verifyGolden(code) {
    if (!code.startsWith("GBP1:")) fail("generated value is not a GBP1 code");
    if (code.length !== expectedLength) fail(`golden length changed: ${code.length} instead of ${expectedLength}`);
    const hash = crypto.createHash("sha256").update(code).digest("hex");
    if (hash !== expectedHash) fail(`golden SHA-256 changed: ${hash}`);
}

const fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));
const javascriptCode = require(javascriptPath).encodeBuild(fixture);
verifyGolden(javascriptCode);

const pythonCode = runPython();
if (pythonCode !== javascriptCode) fail("Python output differs from JavaScript output");

const php = run("php", [phpPath, fixturePath]);
if (!php.ok) fail("PHP generator could not run", php.output);
if (php.output !== javascriptCode) fail("PHP output differs from JavaScript output");

process.stdout.write(`PASS generator parity (${javascriptCode.length} characters, ${expectedHash})\n`);
