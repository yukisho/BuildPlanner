<?php
declare(strict_types=1);

/**
 * Complete browser-to-PHP example for the Build Planner GBP1 generator.
 *
 * GET renders the shared full-build form. POST accepts that form's complete
 * JSON object, turns it into $buildArray, validates server-side invariants, and
 * calls gbpEncodeBuild($buildArray). A production site may move the POST branch
 * into its normal controller without changing the generator call.
 */

require_once __DIR__ . '/gbp1.php';

const EXAMPLE_MAX_REQUEST_BYTES = 1_000_000;
const EXAMPLE_SLOTS = [
    'head' => 'armor', 'shoulders' => 'armor', 'chest' => 'armor',
    'hands' => 'armor', 'waist' => 'armor', 'legs' => 'armor', 'feet' => 'armor',
    'neck' => 'jewelry', 'ring1' => 'jewelry', 'ring2' => 'jewelry',
    'frontMain' => 'weapon', 'frontOff' => 'weapon',
    'backMain' => 'weapon', 'backOff' => 'weapon',
];
const EXAMPLE_TWO_HANDED = [4, 5, 6, 8, 9, 12, 13, 15];

function validateWebsiteBuild(array $buildArray): void
{
    $setups = $buildArray['setups'] ?? null;
    if (!is_array($setups) || !$setups || count($setups) > 100) {
        throw new InvalidArgumentException('A build requires between 1 and 100 setups.');
    }

    foreach ($setups as $setupIndex => $setup) {
        if (!is_array($setup)) throw new InvalidArgumentException('Every setup must be an object.');
        $prefix = 'Setup ' . ($setupIndex + 1);
        $attributes = $setup['character']['attributes'] ?? [];
        $attributeTotal = 0;
        foreach (['health', 'magicka', 'stamina'] as $key) {
            $value = $attributes[$key] ?? 0;
            if (!is_int($value) || $value < 0 || $value > 64) {
                throw new InvalidArgumentException("$prefix has an invalid $key attribute value.");
            }
            $attributeTotal += $value;
        }
        if ($attributeTotal > 64) throw new InvalidArgumentException("$prefix exceeds 64 attribute points.");

        $equipment = $setup['equipment'] ?? [];
        if (!is_array($equipment)) throw new InvalidArgumentException("$prefix equipment must be an object.");
        foreach ($equipment as $slot => $requirement) {
            if (!isset(EXAMPLE_SLOTS[$slot]) || !is_array($requirement)) {
                throw new InvalidArgumentException("$prefix contains an invalid equipment slot.");
            }
            $family = EXAMPLE_SLOTS[$slot];
            if ($family !== 'armor' && array_key_exists('armorType', $requirement)) {
                throw new InvalidArgumentException("$prefix $slot cannot use armorType.");
            }
            if ($family !== 'weapon' && array_key_exists('weaponType', $requirement)) {
                throw new InvalidArgumentException("$prefix $slot cannot use weaponType.");
            }
        }
        foreach ([['frontMain', 'frontOff'], ['backMain', 'backOff']] as [$main, $off]) {
            $weaponType = $equipment[$main]['weaponType'] ?? null;
            if (in_array($weaponType, EXAMPLE_TWO_HANDED, true) && isset($equipment[$off])) {
                throw new InvalidArgumentException("$prefix cannot pair a two-handed $main with $off.");
            }
        }

        $alternatives = $setup['alternatives'] ?? [];
        if (!is_array($alternatives)) throw new InvalidArgumentException("$prefix alternatives must be an object.");
        foreach ($alternatives as $slot => $entries) {
            if (!isset(EXAMPLE_SLOTS[$slot]) || !isset($equipment[$slot])) {
                throw new InvalidArgumentException("$prefix alternatives require primary equipment in the same slot.");
            }
            if (!is_array($entries) || count($entries) > 8) {
                throw new InvalidArgumentException("$prefix has too many alternatives in $slot.");
            }
        }
    }
}

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'POST') {
    header('Content-Type: application/json; charset=utf-8');
    try {
        $contentLength = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
        if ($contentLength > EXAMPLE_MAX_REQUEST_BYTES) {
            throw new LengthException('The submitted build is too large.');
        }
        $json = file_get_contents('php://input', false, null, 0, EXAMPLE_MAX_REQUEST_BYTES + 1);
        if ($json === false || strlen($json) > EXAMPLE_MAX_REQUEST_BYTES) {
            throw new LengthException('The submitted build is too large.');
        }
        $buildArray = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
        $buildArray = gbpObject($buildArray, 'build');
        validateWebsiteBuild($buildArray);
        echo json_encode(['code' => gbpEncodeBuild($buildArray)], JSON_THROW_ON_ERROR);
    } catch (Throwable $error) {
        http_response_code(422);
        echo json_encode(['error' => $error->getMessage()], JSON_THROW_ON_ERROR);
    }
    exit;
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Complete server example for generating a Gravvy Build Planner GBP1 code with PHP.">
    <title>Complete Build Planner PHP Example</title>
    <link rel="stylesheet" href="../example.css">
</head>
<body>
<header><div class="shell">
    <a class="brand" href="../index.html">Build Planner Developer Tools</a>
    <a href="../reference.html">Complete schema reference</a>
</div></header>

<main class="shell">
    <h1>Complete PHP build example</h1>
    <p class="intro">This form covers every portable GBP1 section. It submits the complete object as JSON, PHP converts it to <code>$buildArray</code>, and the server calls <code>gbpEncodeBuild($buildArray)</code>.</p>

    <section class="panel" aria-labelledby="build-heading">
        <div class="section-head">
            <div><h2 id="build-heading">Build and setup</h2><p>Build metadata belongs at the root. Every other planner section belongs to the selected setup.</p></div>
            <div class="actions"><button type="button" id="load-example">Load Full Example</button>
                <button type="button" class="secondary" id="new-build">New Blank Build</button></div>
        </div>
        <div id="build-fields" class="grid"></div>
        <hr style="border:0;border-top:1px solid var(--line);margin:22px 0">
        <div class="toolbar">
            <label class="grow">Selected setup<select id="setup-select"></select></label>
            <button type="button" id="add-setup">Add Setup</button>
            <button type="button" class="secondary" id="duplicate-setup">Duplicate</button>
            <button type="button" class="secondary" id="move-setup-up">Move Up</button>
            <button type="button" class="secondary" id="move-setup-down">Move Down</button>
            <button type="button" class="danger" id="remove-setup">Remove</button>
        </div>
        <div id="setup-fields" class="grid" style="margin-top:16px"></div>
    </section>

    <nav id="section-tabs" class="tabs" aria-label="Build sections"></nav>
    <section id="section-panel" class="panel" aria-live="polite"></section>
    <section id="errors" class="panel errors" aria-live="assertive" hidden>
        <h2>Review the build</h2><ul id="error-list"></ul>
    </section>

    <section class="panel" aria-labelledby="output-heading">
        <div class="section-head"><div><h2 id="output-heading">JSON and GBP1 output</h2>
            <p>The displayed object is the exact request body PHP receives.</p></div>
            <p id="output-status" class="status"></p></div>
        <div class="output-grid">
            <div><h3>$buildArray as JSON</h3><pre id="json-output"></pre>
                <div class="actions"><button type="button" class="secondary" data-copy="json-output">Copy JSON</button>
                    <button type="button" class="secondary" id="download-json">Download JSON</button></div></div>
            <div><h3>Encoded build</h3><textarea id="code-output" readonly></textarea>
                <div class="actions"><button type="button" class="secondary" data-copy="code-output">Copy GBP1 Code</button></div>
                <p class="hint">Paste the result into Build Planner's Share or Import window.</p></div>
        </div>
    </section>
</main>

<script>
window.BuildPlannerExampleEncoder = {
    name: "PHP",
    async encode(buildArray) {
        const response = await fetch(window.location.pathname, {
            method: "POST",
            headers: { "Content-Type": "application/json", "Accept": "application/json" },
            body: JSON.stringify(buildArray)
        });
        const result = await response.json();
        if (!response.ok || !result.code) throw new Error(result.error || `PHP returned HTTP ${response.status}.`);
        return result.code;
    }
};
</script>
<script src="../javascript/app.js"></script>
</body>
</html>
