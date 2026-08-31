(function () {
    "use strict";

    const PYODIDE_URL = "https://cdn.jsdelivr.net/pyodide/v0.29.4/full/";
    const status = document.getElementById("runtime-status");
    let queue = Promise.resolve();

    function setStatus(message, state) {
        status.textContent = message;
        status.className = `runtime ${state || ""}`.trim();
    }

    if (new URLSearchParams(window.location.search).has("server")) {
        setStatus("Connected to the dependency-free Python example server.", "ready");
        window.BuildPlannerExampleEncoder = {
            name: "Python",
            async encode(buildObject) {
                const response = await fetch("/generate", {
                    method: "POST",
                    headers: { "Content-Type": "application/json", "Accept": "application/json" },
                    body: JSON.stringify(buildObject)
                });
                const result = await response.json();
                if (!response.ok || !result.code) throw new Error(result.error || `Python returned HTTP ${response.status}.`);
                return result.code;
            }
        };
        return;
    }

    function loadRuntimeScript() {
        if (typeof loadPyodide === "function") return Promise.resolve();
        return new Promise((resolve, reject) => {
            const script = document.createElement("script");
            script.src = `${PYODIDE_URL}pyodide.js`;
            script.onload = resolve;
            script.onerror = () => reject(new Error("The Pyodide runtime could not be downloaded."));
            document.head.appendChild(script);
        });
    }

    const ready = (async () => {
        try {
            await loadRuntimeScript();
            const pyodide = await loadPyodide({ indexURL: PYODIDE_URL });
            const response = await fetch("gbp1.py", { cache: "no-cache" });
            if (!response.ok) throw new Error(`Could not load gbp1.py (HTTP ${response.status}).`);
            pyodide.FS.writeFile("/home/pyodide/gbp1.py", await response.text());
            await pyodide.runPythonAsync(
                "import json, sys\n"
                + "sys.path.insert(0, '/home/pyodide')\n"
                + "from gbp1 import encode_build"
            );
            setStatus("Python is ready. Changes are encoded locally in this browser.", "ready");
            return pyodide;
        } catch (error) {
            setStatus(`Python could not start: ${error.message}`, "failed");
            throw error;
        }
    })();

    window.BuildPlannerExampleEncoder = {
        name: "Python",
        encode(buildObject) {
            const run = async () => {
                const pyodide = await ready;
                pyodide.globals.set("build_json", JSON.stringify(buildObject));
                try {
                    return await pyodide.runPythonAsync("encode_build(json.loads(build_json))");
                } finally {
                    pyodide.runPython("del build_json");
                }
            };
            const result = queue.then(run, run);
            queue = result.catch(() => {});
            return result;
        }
    };
})();
