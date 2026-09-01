const assert = require("assert");
const fs = require("fs");
const http = require("http");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");

const root = path.resolve(__dirname, "..", ".html", "buildplanner");
const browsers = {
    edge: { label: "Edge", executable: "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe" },
    chrome: { label: "Chrome", executable: "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe" }
};
const selectedBrowser = browsers[process.argv[2] || "edge"];
if (!selectedBrowser) throw new Error(`Unknown browser '${process.argv[2]}'. Use edge or chrome.`);

function contentType(file) {
    const extension = path.extname(file).toLowerCase();
    return ({ ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
        ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8",
        ".py": "text/plain; charset=utf-8" })[extension] || "application/octet-stream";
}

function startServer() {
    const server = http.createServer((request, response) => {
        const url = new URL(request.url, "http://127.0.0.1");
        const relative = decodeURIComponent(url.pathname).replace(/^\/+/, "") || "index.html";
        const file = path.resolve(root, relative);
        if (!file.startsWith(root + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
            response.writeHead(404); response.end("Not found"); return;
        }
        response.writeHead(200, { "Content-Type": contentType(file), "Cache-Control": "no-store" });
        fs.createReadStream(file).pipe(response);
    });
    return new Promise(resolve => server.listen(0, "127.0.0.1", () => resolve(server)));
}

async function waitFor(check, message, timeout = 15000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
        const value = await check();
        if (value) return value;
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    throw new Error(message);
}

class DevTools {
    constructor(socket) {
        this.socket = socket;
        this.sequence = 0;
        this.pending = new Map();
        socket.onmessage = event => {
            const message = JSON.parse(event.data);
            if (!message.id || !this.pending.has(message.id)) return;
            const { resolve, reject } = this.pending.get(message.id);
            this.pending.delete(message.id);
            if (message.error) reject(new Error(message.error.message));
            else resolve(message.result || {});
        };
    }

    send(method, params = {}) {
        const id = ++this.sequence;
        return new Promise((resolve, reject) => {
            this.pending.set(id, { resolve, reject });
            this.socket.send(JSON.stringify({ id, method, params }));
        });
    }

    async evaluate(expression, awaitPromise = true) {
        const result = await this.send("Runtime.evaluate", { expression, awaitPromise, returnByValue: true });
        if (result.exceptionDetails) throw new Error(result.exceptionDetails.text || "Browser evaluation failed");
        return result.result.value;
    }
}

(async () => {
    if (process.platform !== "win32" || !fs.existsSync(selectedBrowser.executable)) {
        process.stdout.write(`SKIP ${selectedBrowser.label} browser interaction test (browser unavailable)\n`);
        return;
    }

    const server = await startServer();
    const address = server.address();
    const origin = `http://127.0.0.1:${address.port}`;
    const debugPort = 9300 + Math.floor(Math.random() * 500);
    const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "gbp-browser-test-"));
    const profile = path.join(temporary, "profile");
    const downloads = path.join(temporary, "downloads");
    fs.mkdirSync(downloads);
    let browser;
    let socket;

    try {
        browser = spawn(selectedBrowser.executable, ["--headless=new", "--disable-gpu", "--no-first-run",
            `--remote-debugging-port=${debugPort}`, "--remote-allow-origins=*",
            `--user-data-dir=${profile}`, "about:blank"], { stdio: "ignore", windowsHide: true });

        const target = await waitFor(async () => {
            try {
                const response = await fetch(`http://127.0.0.1:${debugPort}/json/list`);
                const targets = await response.json();
                return targets.find(entry => entry.type === "page");
            } catch (_) { return null; }
        }, "Edge DevTools did not start");

        socket = new WebSocket(target.webSocketDebuggerUrl);
        await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
        const tools = new DevTools(socket);
        await tools.send("Page.enable");
        await tools.send("Runtime.enable");
        await tools.send("Browser.grantPermissions", {
            origin, permissions: ["clipboardReadWrite", "clipboardSanitizedWrite"]
        });
        await tools.send("Browser.setDownloadBehavior", { behavior: "allow", downloadPath: downloads });
        await tools.send("Page.navigate", { url: `${origin}/javascript/index.html` });

        await waitFor(() => tools.evaluate("document.readyState === 'complete' && document.querySelector('#code-output').value.startsWith('GBP1:')"),
            "The JavaScript example did not finish encoding");

        const tabState = await tools.evaluate(`(() => {
            const tabs = [...document.querySelectorAll('[role="tab"]')];
            return { count: tabs.length, selected: tabs.filter(tab => tab.getAttribute('aria-selected') === 'true').length,
                tabbable: tabs.filter(tab => tab.tabIndex === 0).length };
        })()`);
        assert.deepStrictEqual(tabState, { count: 8, selected: 1, tabbable: 1 });

        await tools.evaluate("document.querySelector('[role=tab]').focus()");
        await tools.send("Input.dispatchKeyEvent", { type: "keyDown", key: "ArrowRight", code: "ArrowRight", windowsVirtualKeyCode: 39 });
        await tools.send("Input.dispatchKeyEvent", { type: "keyUp", key: "ArrowRight", code: "ArrowRight", windowsVirtualKeyCode: 39 });
        assert.strictEqual(await tools.evaluate("document.activeElement.id"), "section-tab-gear");
        assert.strictEqual(await tools.evaluate("getComputedStyle(document.activeElement).outlineStyle !== 'none'"), true);

        await tools.evaluate("document.querySelector('[data-copy=\"json-output\"]').click()");
        await waitFor(() => tools.evaluate("document.querySelector('[data-copy=\"json-output\"]').textContent === 'Copied'"),
            "Copy JSON did not report success");
        const clipboardJson = await tools.evaluate("navigator.clipboard.readText()");
        const outputJson = await tools.evaluate("document.querySelector('#json-output').textContent");
        assert.deepStrictEqual(JSON.parse(clipboardJson), JSON.parse(outputJson));

        await tools.evaluate("document.querySelector('#download-json').click()");
        const download = await waitFor(() => {
            const files = fs.readdirSync(downloads).filter(file => file.endsWith(".json"));
            return files.length ? path.join(downloads, files[0]) : null;
        }, "Download JSON did not create a file");
        const downloadedBuild = JSON.parse(fs.readFileSync(download, "utf8"));
        assert.strictEqual(downloadedBuild.name, "Stamina Warden");
        assert.strictEqual(downloadedBuild.setups.length, 2);

        await tools.send("Emulation.setDeviceMetricsOverride", { width: 520, height: 900, deviceScaleFactor: 1, mobile: false });
        await tools.evaluate(`(() => {
            const input = document.querySelector('#build-name');
            input.value = 'A very long translated build title '.repeat(4).slice(0, 100);
            input.dispatchEvent(new Event('input', { bubbles: true }));
        })()`);
        await new Promise(resolve => setTimeout(resolve, 200));
        assert.strictEqual(await tools.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 1"), true);

        process.stdout.write(`PASS ${selectedBrowser.label} keyboard, focus, clipboard, download, and narrow-layout interactions\n`);
        await tools.send("Browser.close");
    } finally {
        if (socket && socket.readyState === WebSocket.OPEN) socket.close();
        if (browser && !browser.killed) browser.kill();
        await new Promise(resolve => server.close(resolve));
        await new Promise(resolve => setTimeout(resolve, 250));
        fs.rmSync(temporary, { recursive: true, force: true });
    }
})().catch(error => {
    process.stderr.write(`${error.stack || error}\n`);
    process.exit(1);
});
