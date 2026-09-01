const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const source = fs.readFileSync(path.resolve(__dirname, "..", ".html", "buildplanner", "python", "browser-encoder.js"), "utf8");

function pyodideMock() {
    const state = { files: {}, imports: 0, encoded: 0, deleted: 0, globals: {} };
    return {
        state,
        api: {
            FS: { writeFile(name, value) { state.files[name] = value; } },
            globals: { set(name, value) { state.globals[name] = value; } },
            async runPythonAsync(code) {
                if (code.includes("from gbp1 import encode_build")) { state.imports += 1; return undefined; }
                if (code.includes("encode_build")) { state.encoded += 1; return "GBP1:test-code"; }
                return undefined;
            },
            runPython(code) { if (code === "del build_json") state.deleted += 1; }
        }
    };
}

function environment(options = {}) {
    const status = { textContent: "", className: "" };
    const runtime = pyodideMock();
    let appendedScripts = 0;
    const context = {
        console,
        JSON,
        Promise,
        URLSearchParams,
        window: { location: { search: options.search || "" } },
        document: {
            getElementById(id) { assert.strictEqual(id, "runtime-status"); return status; },
            createElement(tag) { assert.strictEqual(tag, "script"); return {}; },
            head: {
                appendChild(script) {
                    appendedScripts += 1;
                    if (options.scriptFailure) script.onerror();
                    else {
                        context.loadPyodide = async () => runtime.api;
                        script.onload();
                    }
                }
            }
        },
        async fetch(url, request) {
            if (url === "/generate") {
                assert.strictEqual(request.method, "POST");
                return { ok: true, async json() { return { code: "GBP1:server-code" }; } };
            }
            assert.strictEqual(url, "gbp1.py");
            return options.moduleFailure
                ? { ok: false, status: 404, async text() { return ""; } }
                : { ok: true, status: 200, async text() { return "def encode_build(value): return value"; } };
        }
    };
    if (options.warm) context.loadPyodide = async () => runtime.api;
    context.globalThis = context;
    vm.createContext(context);
    vm.runInContext(source, context, { filename: "browser-encoder.js" });
    return { context, status, runtime: runtime.state, get appendedScripts() { return appendedScripts; } };
}

async function expectFailure(options, phrase) {
    const test = environment(options);
    await assert.rejects(() => test.context.window.BuildPlannerExampleEncoder.encode({ name: "Test" }));
    assert.match(test.status.textContent, phrase);
    assert.match(test.status.className, /failed/);
}

(async () => {
    const cold = environment();
    assert.strictEqual(await cold.context.window.BuildPlannerExampleEncoder.encode({ name: "Cold" }), "GBP1:test-code");
    assert.strictEqual(cold.appendedScripts, 1);
    assert.strictEqual(cold.runtime.imports, 1);
    assert.strictEqual(cold.runtime.encoded, 1);
    assert.strictEqual(cold.runtime.deleted, 1);
    assert.match(cold.status.className, /ready/);

    const warm = environment({ warm: true });
    assert.strictEqual(await warm.context.window.BuildPlannerExampleEncoder.encode({ name: "Warm" }), "GBP1:test-code");
    assert.strictEqual(warm.appendedScripts, 0);
    assert.strictEqual(warm.runtime.imports, 1);

    const server = environment({ search: "?server=1" });
    assert.strictEqual(await server.context.window.BuildPlannerExampleEncoder.encode({ name: "Server" }), "GBP1:server-code");
    assert.match(server.status.textContent, /dependency-free Python example server/);

    await expectFailure({ scriptFailure: true }, /runtime could not be downloaded/);
    await expectFailure({ moduleFailure: true }, /Could not load gbp1\.py \(HTTP 404\)/);

    process.stdout.write("PASS browser Python cold, warm, server, CDN-failure, and module-failure states\n");
})().catch(error => {
    process.stderr.write(`${error.stack || error}\n`);
    process.exit(1);
});
