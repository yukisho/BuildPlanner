const assert = require("assert");
const fs = require("fs");
const http = require("http");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");

const root = path.resolve(__dirname, "..", ".html", "buildplanner");
const firefox = "C:\\Program Files\\Mozilla Firefox\\firefox.exe";

function contentType(file) {
    const extension = path.extname(file).toLowerCase();
    return ({ ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
        ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8" })[extension]
        || "application/octet-stream";
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

async function connect(url, timeout = 15000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
        try {
            const socket = new WebSocket(url);
            await new Promise((resolve, reject) => {
                socket.onopen = resolve;
                socket.onerror = reject;
            });
            return socket;
        } catch (_) {
            await new Promise(resolve => setTimeout(resolve, 150));
        }
    }
    throw new Error("Firefox WebDriver BiDi did not start");
}

class Bidi {
    constructor(socket) {
        this.socket = socket;
        this.sequence = 0;
        this.pending = new Map();
        socket.onmessage = event => {
            const message = JSON.parse(event.data);
            if (!message.id || !this.pending.has(message.id)) return;
            const { resolve, reject } = this.pending.get(message.id);
            this.pending.delete(message.id);
            if (message.type === "error") reject(new Error(`${message.error}: ${message.message}`));
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

    async evaluate(context, expression) {
        const response = await this.send("script.evaluate", {
            expression, target: { context }, awaitPromise: true, resultOwnership: "none"
        });
        const remote = response.result;
        if (!remote || response.type === "exception") throw new Error(response.exceptionDetails?.text || "Firefox evaluation failed");
        if (["string", "boolean", "number", "bigint"].includes(remote.type)) return remote.value;
        if (remote.type === "null") return null;
        return remote;
    }
}

function firefoxPreferences(downloads) {
    const escaped = downloads.replace(/\\/g, "\\\\");
    return [
        'user_pref("browser.download.folderList", 2);',
        `user_pref("browser.download.dir", "${escaped}");`,
        'user_pref("browser.download.useDownloadDir", true);',
        'user_pref("browser.download.alwaysOpenPanel", false);',
        'user_pref("browser.helperApps.neverAsk.saveToDisk", "application/json,text/json,application/octet-stream");',
        'user_pref("dom.events.testing.asyncClipboard", true);',
        'user_pref("dom.events.asyncClipboard.readText", true);',
        'user_pref("dom.events.asyncClipboard.clipboardItem", true);'
    ].join("\n");
}

(async () => {
    if (process.platform !== "win32" || !fs.existsSync(firefox)) {
        process.stdout.write("SKIP Firefox browser interaction test (browser unavailable)\n");
        return;
    }

    const server = await startServer();
    const origin = `http://127.0.0.1:${server.address().port}`;
    const remotePort = 9800 + Math.floor(Math.random() * 500);
    const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "gbp-firefox-test-"));
    const profile = path.join(temporary, "profile");
    const downloads = path.join(temporary, "downloads");
    fs.mkdirSync(profile);
    fs.mkdirSync(downloads);
    fs.writeFileSync(path.join(profile, "user.js"), firefoxPreferences(downloads));
    let browser;
    let socket;

    try {
        browser = spawn(firefox, ["--headless", "--no-remote", "--profile", profile,
            "--remote-debugging-port", String(remotePort), "about:blank"], { stdio: "ignore", windowsHide: true });
        socket = await connect(`ws://127.0.0.1:${remotePort}/session`);
        const tools = new Bidi(socket);
        await tools.send("session.new", { capabilities: { alwaysMatch: { acceptInsecureCerts: true } } });
        const created = await tools.send("browsingContext.create", { type: "tab" });
        const context = created.context;
        await tools.send("browsingContext.navigate", { context, url: `${origin}/javascript/index.html`, wait: "complete" });

        await waitFor(() => tools.evaluate(context,
            "document.querySelector('#code-output').value.startsWith('GBP1:')"), "Firefox did not finish encoding");
        const tabState = JSON.parse(await tools.evaluate(context, `JSON.stringify((() => {
            const tabs = [...document.querySelectorAll('[role="tab"]')];
            return { count: tabs.length, selected: tabs.filter(tab => tab.getAttribute('aria-selected') === 'true').length,
                tabbable: tabs.filter(tab => tab.tabIndex === 0).length };
        })())`));
        assert.deepStrictEqual(tabState, { count: 8, selected: 1, tabbable: 1 });

        await tools.evaluate(context, "document.querySelector('[role=tab]').focus()");
        await tools.send("input.performActions", { context, actions: [{ type: "key", id: "keyboard", actions: [
            { type: "keyDown", value: "\uE014" }, { type: "keyUp", value: "\uE014" }
        ] }] });
        assert.strictEqual(await tools.evaluate(context, "document.activeElement.id"), "section-tab-gear");
        assert.strictEqual(await tools.evaluate(context, "getComputedStyle(document.activeElement).outlineStyle !== 'none'"), true);

        await tools.evaluate(context, "document.querySelector('[data-copy=\"json-output\"]').click()");
        await waitFor(() => tools.evaluate(context,
            "document.querySelector('[data-copy=\"json-output\"]').textContent === 'Copied'"), "Firefox Copy JSON did not report success");
        const clipboardJson = await tools.evaluate(context, "navigator.clipboard.readText()");
        const outputJson = await tools.evaluate(context, "document.querySelector('#json-output').textContent");
        assert.deepStrictEqual(JSON.parse(clipboardJson), JSON.parse(outputJson));

        await tools.evaluate(context, "document.querySelector('#download-json').click()");
        const download = await waitFor(() => {
            const files = fs.readdirSync(downloads).filter(file => file.endsWith(".json"));
            return files.length ? path.join(downloads, files[0]) : null;
        }, "Firefox Download JSON did not create a file");
        const downloadedBuild = JSON.parse(fs.readFileSync(download, "utf8"));
        assert.strictEqual(downloadedBuild.name, "Stamina Warden");
        assert.strictEqual(downloadedBuild.setups.length, 2);

        process.stdout.write("PASS Firefox keyboard, focus, clipboard, and download interactions\n");
        await tools.send("browser.close");
    } finally {
        if (socket && socket.readyState === WebSocket.OPEN) socket.close();
        if (browser && !browser.killed) browser.kill();
        await new Promise(resolve => server.close(resolve));
        await new Promise(resolve => setTimeout(resolve, 500));
        fs.rmSync(temporary, { recursive: true, force: true });
    }
})().catch(error => {
    process.stderr.write(`${error.stack || error}\n`);
    process.exit(1);
});
