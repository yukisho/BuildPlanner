# Build Planner GBP1 developer examples

These examples show how a build website can create a `GBP1:` code for Gravvy's
Build Planner. JavaScript, Python, and PHP use the same input object and write
the same version 9 payload.

The generators encode portable build plans. They do not encode account-owned
items, inventory locations, readiness results, revisions, stat snapshots,
walkthrough progress, or other player-specific add-on state.

## Choose an implementation

- `javascript/gbp1.js` works in a browser or Node without packages.
- `python/gbp1.py` works as a Python module or command-line tool without packages.
- `python/index.html` runs the Python generator in a browser through Pyodide.
- `python/example.py` is a small standard-library development server.
- `php/gbp1.php` works as an include or command-line tool without Composer.

The PHP implementation requires PHP 7.3 or newer.

See `example-build.json` for a complete two-setup example. The labels, IDs, and
icons in that fixture are sample data, not a complete or authoritative ESO
catalog. A real build site should supply identities from its own maintained data.

Use IDs observed from the ESO API or a maintained game-data catalog. Do not infer
an ability, Champion star, item, set, enchantment, or checklist detector ID from
its display name: names are localized and several records may share one. When a
site cannot establish a reliable identity, omit the optional ID and automatic
detection fields instead of guessing.

## Generate a code

JavaScript:

```js
const code = GBP1.encodeBuild(buildObject);
```

Python:

```python
from gbp1 import encode_build

code = encode_build(build_dict)
```

PHP:

```php
require_once __DIR__ . '/gbp1.php';

$code = gbpEncodeBuild($buildArray);
```

Command line:

```text
node javascript/gbp1.js example-build.json
python python/gbp1.py example-build.json
php php/gbp1.php example-build.json
```

## Root build object

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | string | yes | 1-100 UTF-8 bytes |
| `role` | string | no | Up to 512 bytes |
| `patch` | string | no | Up to 512 bytes |
| `author` | string | no | Up to 512 bytes |
| `sourceUrl` | string | no | Up to 512 bytes |
| `notes` | string | no | Up to 4,000 bytes |
| `classId` | integer | no | Build Planner accepts 0-100 |
| `setups` | array | yes | 1-100 setup objects |
| `selectedSetup` | integer | no | One-based index; defaults to 1 |

## Setup object

| Field | Type | Default or limit |
| --- | --- | --- |
| `name` | string | Required; 1-100 bytes |
| `note` | string | Optional; up to 4,000 bytes |
| `defaultQuality` | integer | 1-5; defaults to 5 |
| `defaultLevel` | integer | 1-50; defaults to 50 |
| `defaultChampionPoints` | integer | 0-160; defaults to 160 |
| `equipment` | object | Canonical slot keys mapped to requirements |
| `alternatives` | object | Slot keys mapped to arrays of up to 8 requirements |
| `skillBars` | object | `front` and `back` arrays |
| `character` | object | Attributes and character choices |
| `champion` | object | Craft, Warfare, and Fitness plans |
| `consumables` | array | Up to 20 requirements |
| `checklist` | array | Up to 100 progression steps |
| `buffAssumptions` | object | Descriptive calculation assumptions |

## Equipment

Canonical slot keys are:

```text
head shoulders chest hands waist legs feet
neck ring1 ring2
frontMain frontOff backMain backOff
```

An equipment requirement may contain:

| Field | Type | Notes |
| --- | --- | --- |
| `setId` | integer | Optional ESO set ID |
| `setName` | string | Optional set or source name |
| `itemId` | integer | Optional ESO item ID |
| `itemName` | string | Optional exact item name |
| `itemLink` | string | Optional ESO item link; up to 2,048 bytes |
| `armorType` | integer | ESO armor-type constant; armor slots only |
| `weaponType` | integer | ESO weapon-type constant; weapon slots only |
| `traitType` | integer | ESO trait-type constant for the slot family |
| `enchantmentId` | integer | Optional ESO enchantment ID |
| `enchantmentCategory` | integer | ESO enchantment search category for the slot family |
| `enchantmentName` | string | Optional display fallback |
| `quality` | integer | Optional 1-5 override |
| `level` | integer | Optional 1-50 override |
| `championPoints` | integer | Optional 0-160 override in steps of 10 |
| `preferredRoute` | string | `buy`, `craft`, `farm`, `reconstruct`, `transmute`, or `unknown` |
| `note` | string | Optional; up to 4,000 bytes |

`preferredRoute` is only valid on a primary equipment requirement. An
alternative uses the same shape without that property, requires primary
equipment in the same slot, and must be compatible with the slot family.

A two-handed main-hand weapon must not be paired with an off-hand requirement.
Do not convert an empty optional numeric field to zero; omit it instead.

## Skill bars

Each bar is an array with at most six positions. Positions 1-5 are active skills
and position 6 is the ultimate. Preserve intentional gaps with `null`:

```json
{
  "skillBars": {
    "front": [
      { "abilityId": 1001, "name": "Deep Fissure", "icon": "ability.dds" },
      null,
      null,
      null,
      null,
      { "abilityId": 1006, "name": "Wild Guardian", "icon": "ultimate.dds" }
    ],
    "back": []
  }
}
```

`abilityId` is required for a populated position and must be a positive integer.
`name` is an optional 100-byte fallback and `icon` is an optional 512-byte path.

## Character

```json
{
  "character": {
    "attributes": { "health": 0, "magicka": 14, "stamina": 50 },
    "raceId": 9,
    "mundus": 10,
    "curse": 0,
    "subclassLines": ["Animal Companions", "Winter's Embrace", "Grave Lord"]
  }
}
```

Each attribute is 0-64 and their total cannot exceed 64. `raceId` is 0-10,
`mundus` is 0-13, and `curse` is 0 for none, 1 for vampire, or 2 for werewolf.
`subclassLines` contains up to three names of at most 100 bytes each.

## Champion Points

`champion` contains `craft`, `warfare`, and `fitness`. Every discipline has an
`allocations` array and a `slottables` array:

```json
{
  "warfare": {
    "allocations": [
      {
        "skillId": 2101,
        "name": "Wrathful Strikes",
        "icon": "champion.dds",
        "points": 50,
        "isSlottable": true
      }
    ],
    "slottables": [2101, null, null, null]
  }
}
```

- A discipline accepts up to 200 allocations.
- `skillId` must be positive and unique across all three disciplines.
- `points` is 1-1,000.
- `name` is required and limited to 100 bytes.
- `icon` is optional and limited to 512 bytes.
- A discipline has four fixed slottable positions.
- A slotted ID must reference an allocation in the same discipline whose
  `isSlottable` value is `true`.
- A star cannot occupy more than one position.

## Consumables

A setup accepts up to 20 consumables:

| Field | Type | Required or limit |
| --- | --- | --- |
| `category` | string | `food`, `drink`, `potion`, `poison`, or `other` |
| `name` | string | Required; 1-100 bytes |
| `itemId` | integer | Optional ESO item ID |
| `itemLink` | string | Optional; up to 2,048 bytes |
| `icon` | string | Optional; up to 512 bytes |
| `quantity` | integer | 1-9,999; defaults to 1 |
| `note` | string | Optional; up to 4,000 bytes |

Consumables are acquisition requirements. Buff assumptions below describe the
conditions under which a guide expects its stats or rotation to be evaluated.

## Progression checklist

A setup accepts up to 100 checklist entries:

| Field | Type | Required or limit |
| --- | --- | --- |
| `category` | string | `passive`, `skillLine`, `unlock`, or `other` |
| `name` | string | Required; 1-100 bytes |
| `targetRank` | integer | Optional; 1-50 |
| `completed` | boolean | Optional; defaults to false |
| `abilityId` | integer | Optional ESO ability ID |
| `icon` | string | Optional; up to 512 bytes |
| `note` | string | Optional; up to 4,000 bytes |
| `detection` | object | Optional automatic progress detector |

Detection `kind` accepts `passive`, `skillLine`, `ability`, `champion`,
`championSlotted`, or `trait`. Depending on that kind, the object may carry
`id`, `skillType`, `skillLineIndex`, `craftingType`, `researchLineIndex`, and
`traitIndex`. These are stable ESO API identifiers, not display labels or row
positions from the website. Omit detection when the site does not have reliable
identifiers; the imported checklist step will remain manually completable.

## Buff assumptions

```json
{
  "buffAssumptions": {
    "food": "Lava Foot Soup-and-Saltrice",
    "potion": "Essence of Weapon Power",
    "selfBuffs": ["Major Brutality"],
    "groupBuffs": ["Major Courage"],
    "targetConditions": ["Trial dummy", "Off Balance"]
  }
}
```

`food` and `potion` are optional strings of up to 512 bytes. Each list accepts
up to 20 required, non-empty strings of up to 512 bytes. These values are
descriptive and stay separate from exact or safely derived character stats.

## Validation and trust boundaries

Treat website form data as untrusted. Validate container types, collection
limits, integer bounds, equipment families, weapon occupancy, attribute totals,
Champion uniqueness, and required values before encoding. Render submitted names,
notes, links, and icons as text rather than HTML.

The language helpers perform format-level validation. Build Planner performs its
own model validation during import, so a generated code cannot bypass add-on
rules. Keep the generator version aligned with the add-on version you support.

## Hosting notes

The JavaScript example is static. The Python browser example is also static, but
downloads its pinned Pyodide runtime from jsDelivr on first load and fetches the
adjacent `gbp1.py`. Serve it over HTTP or HTTPS rather than opening it through a
`file:` URL.

To remove the CDN dependency, download the matching Pyodide full distribution,
serve it with the correct WebAssembly MIME type and CORS policy, and change
`PYODIDE_URL` in `python/browser-encoder.js` to that directory. Keep the version
pinned and test a cold browser cache after changing it.

`python/example.py` is a development server, not a production deployment recipe.
The PHP example requires normal PHP execution. Neither server example requires a
framework or third-party package.
