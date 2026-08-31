<?php
/**
 * Build Planner GBP1 generator — PHP
 *
 * Command line:
 *   php gbp1.php build.json
 *
 * Application code:
 *   require_once __DIR__ . '/gbp1.php';
 *   $code = gbpEncodeBuild($buildArray);
 *
 * Minimal $buildArray:
 *   $buildArray = [
 *       'name' => 'Stamina Warden',
 *       'classId' => 4,
 *       'selectedSetup' => 1,
 *       'setups' => [[
 *           'name' => 'Base Setup',
 *           'equipment' => [
 *               'waist' => [
 *                   'setId' => 602,
 *                   'setName' => 'Whorl of the Depths',
 *                   'armorType' => 1,
 *               ],
 *           ],
 *       ]],
 *   ];
 *
 * The build array must follow the schema documented in ../README.md.
 * gbpEncodeBuild returns a GBP1: string or throws InvalidArgumentException for
 * invalid input. The generator has no Composer or third-party dependencies.
 */

declare(strict_types=1);

const GBP_VERSION = 9;
const GBP_PREFIX = 'GBP1:';
const GBP_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const GBP_SLOTS = ['head', 'shoulders', 'chest', 'hands', 'waist', 'legs', 'feet', 'neck', 'ring1', 'ring2', 'frontMain', 'frontOff', 'backMain', 'backOff'];
const GBP_REQ_STRINGS = ['setName', 'itemName', 'itemLink', 'enchantmentName', 'note'];
const GBP_REQ_NUMBERS = ['setId', 'itemId', 'armorType', 'weaponType', 'traitType', 'enchantmentId', 'enchantmentCategory', 'quality', 'level', 'championPoints'];
const GBP_ROUTES = ['buy' => 1, 'craft' => 2, 'farm' => 3, 'reconstruct' => 4, 'transmute' => 5, 'unknown' => 6];
const GBP_CONSUMABLES = ['food' => 1, 'drink' => 2, 'potion' => 3, 'poison' => 4, 'other' => 5];
const GBP_CHECKLIST = ['passive' => 1, 'skillLine' => 2, 'unlock' => 3, 'other' => 4];
const GBP_DETECTION = ['passive' => 1, 'skillLine' => 2, 'ability' => 3, 'champion' => 4, 'championSlotted' => 5, 'trait' => 6];

function gbpIsList(array $value): bool
{
    if (!$value) return true;
    return array_keys($value) === range(0, count($value) - 1);
}

function gbpObject($value, string $name): array
{
    if (!is_array($value) || gbpIsList($value)) {
        throw new InvalidArgumentException("$name must be an object");
    }
    return $value;
}

function gbpList($value, string $name, int $maximum): array
{
    $value = $value ?? [];
    if (!is_array($value) || !gbpIsList($value) || count($value) > $maximum) {
        throw new InvalidArgumentException("$name must be an array of at most $maximum");
    }
    return $value;
}

function gbpInteger($value, int $minimum, int $maximum, string $name): int
{
    if (!is_int($value) || $value < $minimum || $value > $maximum) {
        throw new InvalidArgumentException("$name is out of range");
    }
    return $value;
}

final class GBPWriter
{
    public string $data = '';

    public function byte(int $value): void
    {
        $this->data .= chr(gbpInteger($value, 0, 255, 'byte'));
    }

    public function u16(int $value): void
    {
        $this->data .= pack('n', gbpInteger($value, 0, 65535, 'u16'));
    }

    public function u32(int $value): void
    {
        gbpInteger($value, 0, 4294967295, 'u32');
        $this->data .= chr(intdiv($value, 16777216) & 255)
            . chr(intdiv($value, 65536) & 255)
            . chr(intdiv($value, 256) & 255)
            . chr($value & 255);
    }

    public function optional($value, string $name): void
    {
        $this->u32($value === null ? 0 : gbpInteger($value, 0, 4294967294, $name) + 1);
    }

    public function string($value, string $name, int $maximum, bool $required = false): void
    {
        $value = $value === null ? '' : (string)$value;
        if (strlen($value) > $maximum || ($required && trim($value) === '')) {
            throw new InvalidArgumentException("$name is invalid");
        }
        $this->u16(strlen($value));
        $this->data .= $value;
    }
}

function gbpRequirement(GBPWriter $writer, array $value, string $name, bool $includeRoute): void
{
    foreach (GBP_REQ_STRINGS as $key) {
        $maximum = $key === 'itemLink' ? 2048 : ($key === 'note' ? 4000 : 512);
        $writer->string($value[$key] ?? null, "$name.$key", $maximum);
    }
    foreach (GBP_REQ_NUMBERS as $key) {
        $writer->optional($value[$key] ?? null, "$name.$key");
    }
    if ($includeRoute) {
        $route = $value['preferredRoute'] ?? null;
        if ($route !== null && !isset(GBP_ROUTES[$route])) {
            throw new InvalidArgumentException("$name.preferredRoute is invalid");
        }
        $writer->byte($route === null ? 0 : GBP_ROUTES[$route]);
    }
}

function gbpSkillBars(GBPWriter $writer, array $setup): void
{
    $skillBars = $setup['skillBars'] ?? [];
    foreach (['front', 'back'] as $barName) {
        $bar = gbpList($skillBars[$barName] ?? null, "skillBars.$barName", 6);
        $mask = 0;
        for ($index = 0; $index < 6; $index++) {
            if (!empty($bar[$index])) $mask += 2 ** $index;
        }
        $writer->byte($mask);
        for ($index = 0; $index < 6; $index++) {
            if (empty($bar[$index])) continue;
            $skill = gbpObject($bar[$index], "$barName skill");
            $writer->u32(gbpInteger($skill['abilityId'] ?? null, 1, 4294967295, 'abilityId'));
            $writer->string($skill['name'] ?? null, 'skill name', 100);
            $writer->string($skill['icon'] ?? null, 'skill icon', 512);
        }
    }
}

function gbpChampion(GBPWriter $writer, array $setup): void
{
    $champion = $setup['champion'] ?? [];
    $seen = [];
    foreach (['craft', 'warfare', 'fitness'] as $key) {
        $discipline = $champion[$key] ?? [];
        $allocations = gbpList($discipline['allocations'] ?? null, "$key allocations", 200);
        $writer->u16(count($allocations));
        $slottable = [];
        foreach ($allocations as $raw) {
            $entry = gbpObject($raw, 'Champion allocation');
            $skillId = gbpInteger($entry['skillId'] ?? null, 1, 4294967295, 'Champion skillId');
            if (isset($seen[$skillId])) throw new InvalidArgumentException('Champion skillId is duplicated');
            $seen[$skillId] = true;
            $writer->u32($skillId);
            $writer->u16(gbpInteger($entry['points'] ?? null, 1, 1000, 'Champion points'));
            $isSlottable = ($entry['isSlottable'] ?? false) === true;
            $writer->byte($isSlottable ? 1 : 0);
            if ($isSlottable) $slottable[$skillId] = true;
            $writer->string($entry['name'] ?? null, 'Champion name', 100, true);
            $writer->string($entry['icon'] ?? null, 'Champion icon', 512);
        }
        $slots = gbpList($discipline['slottables'] ?? null, "$key slottables", 4);
        $used = [];
        for ($index = 0; $index < 4; $index++) {
            $skillId = gbpInteger($slots[$index] ?? 0, 0, 4294967295, 'slottable');
            if ($skillId && (!isset($slottable[$skillId]) || isset($used[$skillId]))) {
                throw new InvalidArgumentException('invalid Champion slottable');
            }
            if ($skillId) $used[$skillId] = true;
            $writer->u32($skillId);
        }
    }
}

function gbpSetup(GBPWriter $writer, array $value): void
{
    $writer->string($value['name'] ?? null, 'setup name', 100, true);
    $writer->string($value['note'] ?? null, 'setup note', 4000);
    $writer->u16(gbpInteger($value['defaultQuality'] ?? 5, 1, 5, 'defaultQuality'));
    $writer->u16(gbpInteger($value['defaultLevel'] ?? 50, 1, 50, 'defaultLevel'));
    $writer->u32(gbpInteger($value['defaultChampionPoints'] ?? 160, 0, 160, 'defaultChampionPoints'));

    $equipment = $value['equipment'] ?? [];
    if (!is_array($equipment)) throw new InvalidArgumentException('equipment must be an object');
    $equipped = array_values(array_filter(GBP_SLOTS,
        static fn($slot) => array_key_exists($slot, $equipment) && $equipment[$slot] !== null));
    $writer->byte(count($equipped));
    foreach ($equipped as $slot) {
        $writer->byte(array_search($slot, GBP_SLOTS, true) + 1);
        gbpRequirement($writer, gbpObject($equipment[$slot], "equipment.$slot"), "equipment.$slot", true);
    }

    $alternatives = $value['alternatives'] ?? [];
    if (!is_array($alternatives)) throw new InvalidArgumentException('alternatives must be an object');
    $alternativeSlots = array_values(array_filter(GBP_SLOTS,
        static fn($slot) => isset($alternatives[$slot]) && is_array($alternatives[$slot]) && count($alternatives[$slot])));
    $writer->byte(count($alternativeSlots));
    foreach ($alternativeSlots as $slot) {
        if (!isset($equipment[$slot])) throw new InvalidArgumentException('alternatives require primary equipment');
        $entries = gbpList($alternatives[$slot], "alternatives.$slot", 8);
        $writer->byte(array_search($slot, GBP_SLOTS, true) + 1);
        $writer->byte(count($entries));
        foreach ($entries as $index => $entry) {
            gbpRequirement($writer, gbpObject($entry, 'alternative'), "alternatives.$slot[$index]", false);
        }
    }

    gbpSkillBars($writer, $value);
    $character = $value['character'] ?? [];
    $attributes = $character['attributes'] ?? [];
    $points = [];
    foreach (['health', 'magicka', 'stamina'] as $key) {
        $points[] = gbpInteger($attributes[$key] ?? 0, 0, 64, $key);
    }
    if (array_sum($points) > 64) throw new InvalidArgumentException('attribute total exceeds 64');
    $points[] = gbpInteger($character['raceId'] ?? 0, 0, 10, 'raceId');
    $points[] = gbpInteger($character['mundus'] ?? 0, 0, 13, 'mundus');
    $points[] = gbpInteger($character['curse'] ?? 0, 0, 2, 'curse');
    foreach ($points as $point) $writer->byte($point);
    $subclass = gbpList($character['subclassLines'] ?? null, 'subclassLines', 3);
    for ($index = 0; $index < 3; $index++) $writer->string($subclass[$index] ?? null, 'subclass line', 100);

    gbpChampion($writer, $value);
    $consumables = gbpList($value['consumables'] ?? null, 'consumables', 20);
    $writer->byte(count($consumables));
    foreach ($consumables as $raw) {
        $entry = gbpObject($raw, 'consumable');
        $category = $entry['category'] ?? null;
        if (!isset(GBP_CONSUMABLES[$category])) throw new InvalidArgumentException('invalid consumable category');
        $writer->byte(GBP_CONSUMABLES[$category]);
        $writer->string($entry['name'] ?? null, 'consumable name', 100, true);
        $writer->string($entry['itemLink'] ?? null, 'consumable itemLink', 2048);
        $writer->string($entry['icon'] ?? null, 'consumable icon', 512);
        $writer->u16(gbpInteger($entry['quantity'] ?? 1, 1, 9999, 'quantity'));
        $writer->string($entry['note'] ?? null, 'consumable note', 4000);
        $writer->optional($entry['itemId'] ?? null, 'consumable itemId');
    }

    $checklist = gbpList($value['checklist'] ?? null, 'checklist', 100);
    $writer->byte(count($checklist));
    foreach ($checklist as $raw) {
        $entry = gbpObject($raw, 'checklist entry');
        $category = $entry['category'] ?? null;
        if (!isset(GBP_CHECKLIST[$category])) throw new InvalidArgumentException('invalid checklist category');
        $writer->byte(GBP_CHECKLIST[$category]);
        $writer->string($entry['name'] ?? null, 'checklist name', 100, true);
        $writer->byte(isset($entry['targetRank']) ? gbpInteger($entry['targetRank'], 1, 50, 'targetRank') : 0);
        $writer->byte(($entry['completed'] ?? false) === true ? 1 : 0);
        $writer->optional($entry['abilityId'] ?? null, 'abilityId');
        $writer->string($entry['icon'] ?? null, 'checklist icon', 512);
        $writer->string($entry['note'] ?? null, 'checklist note', 4000);
        $detection = $entry['detection'] ?? null;
        if ($detection !== null && !isset(GBP_DETECTION[$detection['kind'] ?? null])) {
            throw new InvalidArgumentException('invalid checklist detection');
        }
        $writer->byte($detection === null ? 0 : GBP_DETECTION[$detection['kind']]);
        foreach (['id', 'skillType', 'skillLineIndex', 'craftingType', 'researchLineIndex', 'traitIndex'] as $key) {
            $writer->optional($detection[$key] ?? null, "detection.$key");
        }
    }

    $assumptions = $value['buffAssumptions'] ?? [];
    $writer->string($assumptions['food'] ?? null, 'assumption food', 512);
    $writer->string($assumptions['potion'] ?? null, 'assumption potion', 512);
    foreach (['selfBuffs', 'groupBuffs', 'targetConditions'] as $key) {
        $entries = gbpList($assumptions[$key] ?? null, $key, 20);
        $writer->byte(count($entries));
        foreach ($entries as $entry) $writer->string($entry, $key, 512, true);
    }
}

function gbpChecksum(string $data): int
{
    $first = 1;
    $second = 0;
    for ($index = 0, $length = strlen($data); $index < $length; $index++) {
        $first = ($first + ord($data[$index])) % 65521;
        $second = ($second + $first) % 65521;
    }
    return $second * 65536 + $first;
}

function gbpBase64(string $data): string
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function gbpEncodeBuild(array $build): string
{
    $setups = gbpList($build['setups'] ?? null, 'setups', 100);
    if (!$setups) throw new InvalidArgumentException('at least one setup is required');
    $writer = new GBPWriter();
    $writer->byte(GBP_VERSION);
    $writer->string($build['name'] ?? null, 'build name', 100, true);
    foreach (['role', 'patch', 'author', 'sourceUrl'] as $key) $writer->string($build[$key] ?? null, $key, 512);
    $writer->string($build['notes'] ?? null, 'notes', 4000);
    $writer->optional($build['classId'] ?? null, 'classId');
    $writer->u16(count($setups));
    $writer->u16(gbpInteger($build['selectedSetup'] ?? 1, 1, count($setups), 'selectedSetup'));
    foreach ($setups as $setup) gbpSetup($writer, gbpObject($setup, 'setup'));
    $writer->u32(gbpChecksum($writer->data));
    return GBP_PREFIX . gbpBase64($writer->data);
}

if (PHP_SAPI === 'cli' && realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if ($argc !== 2) {
        file_put_contents('php://stderr', "Usage: php gbp1.php build.json\n");
        exit(1);
    }
    try {
        $json = file_get_contents($argv[1]);
        if ($json === false) throw new RuntimeException('Unable to read input file');
        $build = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
        echo gbpEncodeBuild(gbpObject($build, 'build')), PHP_EOL;
    } catch (Throwable $error) {
        file_put_contents('php://stderr', $error->getMessage() . PHP_EOL);
        exit(1);
    }
}
