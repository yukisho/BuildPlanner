# GBP1 build-code generators

These dependency-free helpers let build websites create codes that players can
paste into Build Planner. Implementations are provided for JavaScript, Python,
and PHP. All three write the current GBP1 format version 9 and accept the same
JSON structure.

## Quick start

```text
node javascript/gbp1.js example-build.json
python python/gbp1.py example-build.json
php php/gbp1.php example-build.json
```

Each command prints one `GBP1:` code. In a website, import or include the
JavaScript file and call `GBP1.encodeBuild(build)`. The function has no browser
or package dependencies.

For a working server-rendered tutorial, start PHP's local web server inside the
`php` directory and open the included interactive form:

```text
cd php
php -S localhost:8080
```

Then visit `http://localhost:8080/example.php`. The page lets you choose build
metadata and several gear requirements, displays the resulting JSON, and
generates a copyable GBP1 code.

The JavaScript directory contains `example.html`. Open it directly in a modern
browser, or serve that directory with any static web server. It calls
`GBP1.encodeBuild()` in the browser and refreshes its JSON and code immediately
whenever the form changes.

The Python directory contains a matching dependency-free web example. It uses
Python's standard HTTP server classes and sends form data to a real Python
`encode_build()` endpoint:

```text
cd python
python example.py
```

Then visit `http://127.0.0.1:8081`. Use `--host` or `--port` to change the local
listener. The example binds only to `127.0.0.1` by default.

The root object requires a non-empty `name` and a non-empty `setups` array.
`selectedSetup` is a one-based setup index and defaults to 1. A setup uses these
defaults when omitted:

```json
{
  "defaultQuality": 5,
  "defaultLevel": 50,
  "defaultChampionPoints": 160,
  "equipment": {},
  "alternatives": {},
  "skillBars": { "front": [], "back": [] },
  "character": {},
  "champion": {},
  "consumables": [],
  "checklist": [],
  "buffAssumptions": {}
}
```

Equipment keys are `head`, `shoulders`, `chest`, `hands`, `waist`, `legs`,
`feet`, `neck`, `ring1`, `ring2`, `frontMain`, `frontOff`, `backMain`, and
`backOff`. Numeric equipment values are ESO constants or IDs: `setId`,
`itemId`, `armorType`, `weaponType`, `traitType`, `enchantmentId`,
`enchantmentCategory`, `quality`, `level`, and `championPoints`. String values
are `setName`, `itemName`, `itemLink`, `enchantmentName`, and `note`.

An optional `preferredRoute` on an equipment requirement accepts `buy`,
`craft`, `farm`, `reconstruct`, `transmute`, or `unknown`. Alternatives use the
same requirement shape. Skill bars contain six array positions; the sixth is
the ultimate. See `example-build.json` for a complete practical example.

Generator input is untrusted data. The helpers validate container types,
integer bounds, duplicate Champion IDs, and required values before encoding.
Build Planner performs its own full model validation during import, including
slot-specific ESO enum checks. A generated code is therefore not a way to
bypass add-on validation.

`GBP1` is a versioned binary exchange format. Keep a copy of the generator that
matches the add-on release and update the implementation when the format
version changes.
