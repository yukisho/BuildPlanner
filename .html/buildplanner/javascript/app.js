(function () {
    "use strict";

    const SLOT_DEFINITIONS = {
        head: ["Head", "armor"], shoulders: ["Shoulders", "armor"],
        chest: ["Chest", "armor"], hands: ["Hands", "armor"],
        waist: ["Waist", "armor"], legs: ["Legs", "armor"], feet: ["Feet", "armor"],
        neck: ["Neck", "jewelry"], ring1: ["Ring 1", "jewelry"], ring2: ["Ring 2", "jewelry"],
        frontMain: ["Front Bar Main Hand", "weapon"], frontOff: ["Front Bar Off Hand", "weapon"],
        backMain: ["Back Bar Main Hand", "weapon"], backOff: ["Back Bar Off Hand", "weapon"]
    };
    const ARMOR_TYPES = [[1, "Light"], [2, "Medium"], [3, "Heavy"]];
    const WEAPON_TYPES = [[1, "Axe"], [2, "Mace"], [3, "Sword"], [4, "Battle Axe"],
        [5, "Maul"], [6, "Greatsword"], [8, "Bow"], [9, "Restoration Staff"],
        [11, "Dagger"], [12, "Inferno Staff"], [13, "Ice Staff"], [14, "Shield"],
        [15, "Lightning Staff"]];
    const TWO_HANDED = new Set([4, 5, 6, 8, 9, 12, 13, 15]);
    const TRAITS = {
        armor: [[11, "Sturdy"], [12, "Impenetrable"], [13, "Reinforced"], [14, "Well-fitted"],
            [15, "Training"], [16, "Infused"], [17, "Invigorating"], [18, "Divines"], [19, "Nirnhoned"]],
        jewelry: [[21, "Healthy"], [22, "Arcane"], [23, "Robust"], [30, "Triune"],
            [31, "Infused"], [32, "Protective"], [33, "Swift"], [34, "Harmony"], [35, "Bloodthirsty"]],
        weapon: [[1, "Powered"], [2, "Charged"], [3, "Precise"], [4, "Infused"],
            [5, "Defending"], [6, "Training"], [7, "Sharpened"], [8, "Decisive"], [26, "Nirnhoned"]]
    };
    const CLASSES = [[0, "Not specified"], [1, "Dragonknight"], [2, "Sorcerer"],
        [3, "Nightblade"], [4, "Warden"], [5, "Necromancer"], [6, "Templar"], [7, "Arcanist"]];
    const QUALITIES = [[1, "Normal"], [2, "Fine"], [3, "Superior"], [4, "Epic"], [5, "Legendary"]];
    const ROUTES = [["", "Automatic"], ["buy", "Buy"], ["craft", "Craft"], ["farm", "Farm"],
        ["reconstruct", "Reconstruct"], ["transmute", "Transmute"], ["unknown", "Unknown"]];
    const CONSUMABLE_CATEGORIES = [["food", "Food"], ["drink", "Drink"], ["potion", "Potion"],
        ["poison", "Poison"], ["other", "Other"]];
    const CHECKLIST_CATEGORIES = [["passive", "Passive"], ["skillLine", "Skill Line"],
        ["unlock", "Unlock"], ["other", "Other"]];
    const DETECTION_KINDS = [["", "Manual only"], ["passive", "Passive"], ["skillLine", "Skill Line"],
        ["ability", "Ability"], ["champion", "Champion allocation"],
        ["championSlotted", "Champion slotted"], ["trait", "Crafting trait"]];
    const DISCIPLINES = [["craft", "Craft"], ["warfare", "Warfare"], ["fitness", "Fitness"]];
    const SECTIONS = [
        ["overview", "Overview"], ["gear", "Gear"], ["skills", "Skills"],
        ["character", "Character"], ["champion", "Champion Points"],
        ["consumables", "Consumables"], ["checklist", "Checklist"],
        ["assumptions", "Buff Assumptions"]
    ];

    const buildFields = document.getElementById("build-fields");
    const setupFields = document.getElementById("setup-fields");
    const setupSelect = document.getElementById("setup-select");
    const tabs = document.getElementById("section-tabs");
    const sectionPanel = document.getElementById("section-panel");
    const errorPanel = document.getElementById("errors");
    const errorList = document.getElementById("error-list");
    const jsonOutput = document.getElementById("json-output");
    const codeOutput = document.getElementById("code-output");
    const outputStatus = document.getElementById("output-status");
    const encoder = window.BuildPlannerExampleEncoder;

    if (!encoder || typeof encoder.encode !== "function") {
        throw new Error("BuildPlannerExampleEncoder.encode(buildObject) is required before app.js loads.");
    }

    let build = blankBuild();
    let selectedSetup = 0;
    let activeSection = "overview";
    let cachedExample = null;
    let dirty = false;
    let generationTimer = null;
    let generationNumber = 0;

    function blankChampion() {
        return {
            craft: { allocations: [], slottables: [] },
            warfare: { allocations: [], slottables: [] },
            fitness: { allocations: [], slottables: [] }
        };
    }

    function blankSetup(name) {
        return {
            name: name || "Base Setup",
            note: "",
            defaultQuality: 5,
            defaultLevel: 50,
            defaultChampionPoints: 160,
            equipment: {},
            alternatives: {},
            skillBars: { front: [], back: [] },
            character: {
                attributes: { health: 0, magicka: 0, stamina: 64 },
                raceId: 0, mundus: 0, curse: 0, subclassLines: []
            },
            champion: blankChampion(),
            consumables: [],
            checklist: [],
            buffAssumptions: { food: "", potion: "", selfBuffs: [], groupBuffs: [], targetConditions: [] }
        };
    }

    function blankBuild() {
        return {
            name: "New Build", role: "", patch: "", author: "", sourceUrl: "", notes: "",
            classId: 0, selectedSetup: 1, setups: [blankSetup()]
        };
    }

    function clone(value) {
        return typeof structuredClone === "function"
            ? structuredClone(value)
            : JSON.parse(JSON.stringify(value));
    }

    function currentSetup() {
        return build.setups[selectedSetup];
    }

    function create(tag, className, text) {
        const element = document.createElement(tag);
        if (className) element.className = className;
        if (text != null) element.textContent = text;
        return element;
    }

    function append(parent, ...children) {
        children.flat().filter(Boolean).forEach(child => parent.appendChild(child));
        return parent;
    }

    function button(text, className, handler) {
        const control = create("button", className, text);
        control.type = "button";
        control.addEventListener("click", handler);
        return control;
    }

    function options(control, values, selected, includeDefault) {
        if (includeDefault) control.appendChild(new Option(includeDefault, ""));
        values.forEach(([value, label]) => control.appendChild(new Option(label, String(value), false,
            String(value) === String(selected == null ? "" : selected))));
    }

    function setText(target, key, value, keepEmpty) {
        if (value !== "" || keepEmpty) target[key] = value;
        else delete target[key];
        changed();
    }

    function setNumber(target, key, value, keepZero) {
        if (value === "") delete target[key];
        else {
            const number = Number(value);
            if (Number.isFinite(number) && (keepZero || number !== 0)) target[key] = number;
            else if (number === 0) delete target[key];
        }
        changed();
    }

    function textField(parent, labelText, target, key, settings = {}) {
        const label = create("label", settings.className || "");
        label.append(document.createTextNode(labelText));
        const control = create(settings.multiline ? "textarea" : "input");
        if (!settings.multiline) control.type = settings.type || "text";
        if (settings.maxLength) control.maxLength = settings.maxLength;
        if (settings.placeholder) control.placeholder = settings.placeholder;
        if (settings.min != null) control.min = settings.min;
        if (settings.max != null) control.max = settings.max;
        if (settings.step != null) control.step = settings.step;
        control.value = target[key] == null ? "" : target[key];
        control.addEventListener("input", () => {
            if (settings.type === "number") setNumber(target, key, control.value, settings.keepZero);
            else setText(target, key, control.value, settings.keepEmpty);
            if (settings.afterChange) settings.afterChange(control.value);
        });
        label.appendChild(control);
        parent.appendChild(label);
        return control;
    }

    function selectField(parent, labelText, target, key, values, settings = {}) {
        const label = create("label");
        label.append(document.createTextNode(labelText));
        const control = create("select");
        options(control, values, target[key], settings.defaultLabel);
        control.value = target[key] == null ? "" : String(target[key]);
        control.addEventListener("change", () => {
            if (control.value === "" && settings.optional) delete target[key];
            else target[key] = settings.numeric ? Number(control.value) : control.value;
            changed();
            if (settings.afterChange) settings.afterChange(control.value);
        });
        label.appendChild(control);
        parent.appendChild(label);
        return control;
    }

    function checkboxField(parent, labelText, target, key, afterChange) {
        const label = create("label", "inline-check");
        const control = create("input");
        control.type = "checkbox";
        control.checked = target[key] === true;
        control.addEventListener("change", () => {
            target[key] = control.checked;
            changed();
            if (afterChange) afterChange(control.checked);
        });
        append(label, control, document.createTextNode(labelText));
        parent.appendChild(label);
        return control;
    }

    function renderBuildAndSetup() {
        buildFields.replaceChildren();
        textField(buildFields, "Build name", build, "name", { maxLength: 100, keepEmpty: true });
        selectField(buildFields, "Class", build, "classId", CLASSES, { numeric: true });
        textField(buildFields, "Role", build, "role", { maxLength: 512 });
        textField(buildFields, "Patch or update", build, "patch", { maxLength: 512 });
        textField(buildFields, "Guide author", build, "author", { maxLength: 512 });
        textField(buildFields, "Guide URL", build, "sourceUrl", { maxLength: 512, type: "url" });
        textField(buildFields, "Build notes", build, "notes", { maxLength: 4000, multiline: true });

        setupSelect.replaceChildren();
        build.setups.forEach((setup, index) => setupSelect.appendChild(new Option(
            `${index + 1}. ${setup.name || "Unnamed Setup"}`, String(index), false, index === selectedSetup)));
        setupSelect.value = String(selectedSetup);
        document.getElementById("remove-setup").disabled = build.setups.length <= 1;

        const setup = currentSetup();
        setupFields.replaceChildren();
        textField(setupFields, "Setup name", setup, "name", { maxLength: 100, keepEmpty: true,
            afterChange: () => updateSetupOption() });
        textField(setupFields, "Setup note", setup, "note", { maxLength: 4000, multiline: true });
        selectField(setupFields, "Default quality", setup, "defaultQuality", QUALITIES, { numeric: true });
        textField(setupFields, "Default level", setup, "defaultLevel", { type: "number", min: 1, max: 50 });
        textField(setupFields, "Default Champion Points", setup, "defaultChampionPoints",
            { type: "number", min: 0, max: 160, step: 10, keepZero: true });
    }

    function updateSetupOption() {
        const option = setupSelect.options[selectedSetup];
        if (option) option.textContent = `${selectedSetup + 1}. ${currentSetup().name || "Unnamed Setup"}`;
    }

    function sectionCount(key) {
        const setup = currentSetup();
        if (key === "gear") return Object.keys(setup.equipment || {}).length;
        if (key === "skills") return ["front", "back"].reduce((sum, bar) => sum +
            ((setup.skillBars && setup.skillBars[bar]) || []).filter(Boolean).length, 0);
        if (key === "character") {
            const values = setup.character || {};
            const attributes = values.attributes || {};
            return (attributes.health || 0) + (attributes.magicka || 0) + (attributes.stamina || 0);
        }
        if (key === "champion") return DISCIPLINES.reduce((sum, [name]) => sum +
            (((setup.champion || {})[name] || {}).allocations || []).length, 0);
        if (key === "consumables") return (setup.consumables || []).length;
        if (key === "checklist") return (setup.checklist || []).length;
        if (key === "assumptions") {
            const values = setup.buffAssumptions || {};
            return (values.food ? 1 : 0) + (values.potion ? 1 : 0) +
                ["selfBuffs", "groupBuffs", "targetConditions"].reduce((sum, name) => sum + (values[name] || []).length, 0);
        }
        return build.setups.length;
    }

    function renderTabs() {
        tabs.replaceChildren();
        SECTIONS.forEach(([key, label]) => {
            const control = button(label, "tab", () => {
                activeSection = key;
                renderTabs();
                renderSection();
            });
            control.setAttribute("role", "tab");
            control.setAttribute("aria-selected", key === activeSection ? "true" : "false");
            const count = create("span", "count", String(sectionCount(key)));
            control.appendChild(count);
            tabs.appendChild(control);
        });
    }

    function sectionHeading(title, description, action) {
        const head = create("div", "section-head");
        const copy = create("div");
        append(copy, create("h2", "", title), create("p", "", description));
        append(head, copy, action);
        sectionPanel.appendChild(head);
    }

    function renderSection() {
        sectionPanel.replaceChildren();
        const renderers = {
            overview: renderOverview, gear: renderGear, skills: renderSkills,
            character: renderCharacter, champion: renderChampion,
            consumables: renderConsumables, checklist: renderChecklist,
            assumptions: renderAssumptions
        };
        renderers[activeSection]();
    }

    function renderOverview() {
        const setup = currentSetup();
        sectionHeading("Portable build overview", "This is the data a website can send to Build Planner. Account inventory, readiness, revisions, and captured stats stay in the add-on.");
        const grid = create("div", "grid four");
        const items = [
            ["Planned gear", sectionCount("gear")], ["Planned skills", sectionCount("skills")],
            ["Champion allocations", sectionCount("champion")], ["Consumables", sectionCount("consumables")],
            ["Checklist steps", sectionCount("checklist")], ["Assumptions", sectionCount("assumptions")],
            ["Attribute points", sectionCount("character")], ["Setups in build", build.setups.length]
        ];
        items.forEach(([label, value]) => {
            const card = create("fieldset");
            append(card, create("legend", "", label), create("strong", "", String(value)));
            grid.appendChild(card);
        });
        sectionPanel.appendChild(grid);
        const snippet = create("pre");
        snippet.textContent = JSON.stringify({
            name: setup.name,
            equipment: setup.equipment,
            skillBars: setup.skillBars,
            character: setup.character,
            champion: setup.champion,
            consumables: setup.consumables,
            checklist: setup.checklist,
            buffAssumptions: setup.buffAssumptions
        }, null, 2);
        sectionPanel.appendChild(snippet);
    }

    function renderRequirementFields(parent, requirement, family, includeRoute) {
        const grid = create("div", "grid four");
        textField(grid, "Set name", requirement, "setName", { maxLength: 512 });
        textField(grid, "ESO set ID", requirement, "setId", { type: "number", min: 1, max: 4294967294 });
        textField(grid, "Exact item name", requirement, "itemName", { maxLength: 512 });
        textField(grid, "ESO item ID", requirement, "itemId", { type: "number", min: 1, max: 4294967294 });
        textField(grid, "ESO item link", requirement, "itemLink", { maxLength: 2048 });
        if (family === "armor") selectField(grid, "Armor weight", requirement, "armorType", ARMOR_TYPES,
            { numeric: true, optional: true, defaultLabel: "Not specified" });
        if (family === "weapon") selectField(grid, "Weapon type", requirement, "weaponType", WEAPON_TYPES,
            { numeric: true, optional: true, defaultLabel: "Not specified" });
        selectField(grid, "Trait", requirement, "traitType", TRAITS[family],
            { numeric: true, optional: true, defaultLabel: "Not specified" });
        textField(grid, "Enchantment name", requirement, "enchantmentName", { maxLength: 512 });
        textField(grid, "Enchantment ID", requirement, "enchantmentId", { type: "number", min: 1, max: 4294967294 });
        textField(grid, "Enchantment category", requirement, "enchantmentCategory", { type: "number", min: 0, max: 255, keepZero: true });
        selectField(grid, "Quality override", requirement, "quality", QUALITIES,
            { numeric: true, optional: true, defaultLabel: "Use setup default" });
        textField(grid, "Level override", requirement, "level", { type: "number", min: 1, max: 50 });
        textField(grid, "CP override", requirement, "championPoints", { type: "number", min: 0, max: 160, step: 10, keepZero: true });
        if (includeRoute) selectField(grid, "Preferred route", requirement, "preferredRoute", ROUTES,
            { optional: true });
        textField(grid, "Slot note", requirement, "note", { maxLength: 4000, multiline: true });
        parent.appendChild(grid);
    }

    function renderGear() {
        sectionHeading("Gear and alternatives", "Every requirement is stored under a canonical slot key. Alternatives use the same shape without preferredRoute.");
        const setup = currentSetup();
        setup.equipment = setup.equipment || {};
        setup.alternatives = setup.alternatives || {};

        Object.entries(SLOT_DEFINITIONS).forEach(([slot, definition]) => {
            const [label, family] = definition;
            const fieldset = create("fieldset");
            fieldset.appendChild(create("legend", "", label));
            const requirement = setup.equipment[slot];
            if (!requirement) {
                append(fieldset, create("p", "empty", "Not planned"), button("Plan This Slot", "secondary", () => {
                    setup.equipment[slot] = {};
                    markAndRender();
                }));
                sectionPanel.appendChild(fieldset);
                return;
            }

            const head = create("div", "row-head");
            append(head, create("h3", "", requirement.itemName || requirement.setName || "New requirement"),
                button("Clear Slot", "danger", () => {
                    delete setup.equipment[slot];
                    delete setup.alternatives[slot];
                    markAndRender();
                }));
            fieldset.appendChild(head);
            renderRequirementFields(fieldset, requirement, family, true);

            const alternatives = setup.alternatives[slot] || [];
            alternatives.forEach((alternative, index) => {
                const nested = create("fieldset");
                nested.appendChild(create("legend", "", `Alternative ${index + 1}`));
                renderRequirementFields(nested, alternative, family, false);
                nested.appendChild(button("Remove Alternative", "danger", () => {
                    alternatives.splice(index, 1);
                    if (!alternatives.length) delete setup.alternatives[slot];
                    markAndRender();
                }));
                fieldset.appendChild(nested);
            });
            const addAlternative = button("Add Alternative", "secondary", () => {
                if (!setup.alternatives[slot]) setup.alternatives[slot] = [];
                if (setup.alternatives[slot].length < 8) setup.alternatives[slot].push({});
                markAndRender();
            });
            addAlternative.disabled = alternatives.length >= 8;
            fieldset.appendChild(addAlternative);
            sectionPanel.appendChild(fieldset);
        });
    }

    function skillObject(bar, index) {
        if (!bar[index]) bar[index] = {};
        return bar[index];
    }

    function renderSkills() {
        sectionHeading("Skill bars", "Positions 1-5 are active abilities. Position 6 is the ultimate. Empty positions are preserved with null.");
        const skillBars = currentSetup().skillBars || (currentSetup().skillBars = { front: [], back: [] });
        const barGrid = create("div", "skill-bars");
        [["front", "Front Bar"], ["back", "Back Bar"]].forEach(([barKey, label]) => {
            const fieldset = create("fieldset");
            fieldset.appendChild(create("legend", "", label));
            const bar = skillBars[barKey] || (skillBars[barKey] = []);
            for (let index = 0; index < 6; index += 1) {
                const slot = create("div", "skill-slot");
                slot.appendChild(create("div", `slot-number${index === 5 ? " ultimate" : ""}`, index === 5 ? "U" : String(index + 1)));
                const fields = create("div", "grid");
                const skill = bar[index] || {};
                const ability = textField(fields, "Ability ID", skill, "abilityId", { type: "number", min: 1, max: 4294967294 });
                const name = textField(fields, "Ability name", skill, "name", { maxLength: 100 });
                const icon = textField(fields, "Icon path", skill, "icon", { maxLength: 512 });
                [ability, name, icon].forEach(control => control.addEventListener("input", () => {
                    if (Object.keys(skill).length) bar[index] = skill;
                    else bar[index] = null;
                    updateTabs();
                }));
                const clear = button("Clear", "secondary", () => { bar[index] = null; markAndRender(); });
                clear.disabled = !bar[index];
                append(fields, clear);
                slot.appendChild(fields);
                fieldset.appendChild(slot);
            }
            barGrid.appendChild(fieldset);
        });
        sectionPanel.appendChild(barGrid);
    }

    function renderCharacter() {
        sectionHeading("Character choices", "Attributes may total no more than 64. Race, Mundus, curse, and subclass lines are setup-specific.");
        const character = currentSetup().character || (currentSetup().character = {});
        const attributes = character.attributes || (character.attributes = { health: 0, magicka: 0, stamina: 0 });
        const grid = create("div", "grid");
        const total = create("p", "attribute-total");
        const updateTotal = () => {
            const value = (attributes.health || 0) + (attributes.magicka || 0) + (attributes.stamina || 0);
            total.textContent = `${value} of 64 attribute points allocated`;
            total.className = `attribute-total${value > 64 ? " invalid" : ""}`;
            updateTabs();
        };
        ["health", "magicka", "stamina"].forEach(key => textField(grid,
            key[0].toUpperCase() + key.slice(1), attributes, key,
            { type: "number", min: 0, max: 64, keepZero: true, afterChange: updateTotal }));
        sectionPanel.appendChild(grid);
        sectionPanel.appendChild(total);
        updateTotal();

        const choices = create("div", "grid");
        const races = [[0, "Not specified"], [1, "Breton"], [2, "Redguard"], [3, "Orc"], [4, "Dark Elf"],
            [5, "Nord"], [6, "Argonian"], [7, "High Elf"], [8, "Wood Elf"], [9, "Khajiit"], [10, "Imperial"]];
        const mundus = Array.from({ length: 14 }, (_, value) => [value, value === 0 ? "Not specified" : `Mundus ID ${value}`]);
        selectField(choices, "Race", character, "raceId", races, { numeric: true });
        selectField(choices, "Mundus Stone", character, "mundus", mundus, { numeric: true });
        selectField(choices, "Curse", character, "curse", [[0, "None"], [1, "Vampire"], [2, "Werewolf"]], { numeric: true });
        sectionPanel.appendChild(choices);

        const lines = create("fieldset");
        lines.appendChild(create("legend", "", "Class and subclass lines"));
        const lineGrid = create("div", "grid");
        character.subclassLines = character.subclassLines || [];
        for (let index = 0; index < 3; index += 1) {
            const holder = { value: character.subclassLines[index] || "" };
            textField(lineGrid, `Skill line ${index + 1}`, holder, "value", { maxLength: 100,
                afterChange: value => { character.subclassLines[index] = value; changed(); } });
        }
        lines.appendChild(lineGrid);
        sectionPanel.appendChild(lines);
    }

    function ensureDiscipline(setup, key) {
        setup.champion = setup.champion || blankChampion();
        if (!setup.champion[key]) setup.champion[key] = { allocations: [], slottables: [] };
        setup.champion[key].allocations = setup.champion[key].allocations || [];
        setup.champion[key].slottables = setup.champion[key].slottables || [];
        return setup.champion[key];
    }

    function renderChampion() {
        sectionHeading("Champion Points", "Allocation IDs must be unique across all disciplines. Only allocations marked slottable may occupy one of the four positions.");
        const setup = currentSetup();
        DISCIPLINES.forEach(([key, label]) => {
            const discipline = ensureDiscipline(setup, key);
            const fieldset = create("fieldset", "discipline");
            const head = create("div", "row-head");
            append(head, create("h3", "", label), button("Add Allocation", "secondary", () => {
                if (discipline.allocations.length < 200) discipline.allocations.push({ name: "", points: 1, isSlottable: false });
                markAndRender();
            }));
            fieldset.appendChild(head);

            if (!discipline.allocations.length) fieldset.appendChild(create("p", "empty", "No Champion allocations planned"));
            discipline.allocations.forEach((allocation, index) => {
                const row = create("div", "allocation");
                const rowHead = create("div", "row-head");
                append(rowHead, create("h4", "", allocation.name || `Allocation ${index + 1}`),
                    button("Remove", "danger", () => {
                        const oldId = allocation.skillId;
                        discipline.allocations.splice(index, 1);
                        discipline.slottables = discipline.slottables.map(id => id === oldId ? null : id);
                        markAndRender();
                    }));
                row.appendChild(rowHead);
                const grid = create("div", "grid four");
                const idControl = textField(grid, "Champion skill ID", allocation, "skillId", { type: "number", min: 1, max: 4294967294 });
                textField(grid, "Star name", allocation, "name", { maxLength: 100, keepEmpty: true });
                textField(grid, "Points", allocation, "points", { type: "number", min: 1, max: 1000 });
                textField(grid, "Icon path", allocation, "icon", { maxLength: 512 });
                checkboxField(grid, "This star is slottable", allocation, "isSlottable", checked => {
                    if (!checked) discipline.slottables = discipline.slottables.map(id => id === allocation.skillId ? null : id);
                    renderSection();
                });
                idControl.addEventListener("change", () => renderSection());
                row.appendChild(grid);
                fieldset.appendChild(row);
            });

            const slots = create("fieldset");
            slots.appendChild(create("legend", "", "Slottable positions"));
            const slotGrid = create("div", "grid four");
            for (let index = 0; index < 4; index += 1) {
                const labelElement = create("label");
                labelElement.append(document.createTextNode(`Slot ${index + 1}`));
                const select = create("select");
                select.appendChild(new Option("Empty", ""));
                discipline.allocations.filter(entry => entry.isSlottable && entry.skillId).forEach(entry =>
                    select.appendChild(new Option(entry.name || `Star ${entry.skillId}`, String(entry.skillId))));
                select.value = discipline.slottables[index] == null ? "" : String(discipline.slottables[index]);
                select.addEventListener("change", () => {
                    discipline.slottables[index] = select.value === "" ? null : Number(select.value);
                    changed();
                });
                append(labelElement, select);
                slotGrid.appendChild(labelElement);
            }
            slots.appendChild(slotGrid);
            fieldset.appendChild(slots);
            sectionPanel.appendChild(fieldset);
        });
    }

    function renderConsumables() {
        const setup = currentSetup();
        setup.consumables = setup.consumables || [];
        const add = button("Add Consumable", "", () => {
            if (setup.consumables.length < 20) setup.consumables.push({ category: "food", name: "", quantity: 1 });
            markAndRender();
        });
        add.disabled = setup.consumables.length >= 20;
        sectionHeading("Consumables", "These are item requirements, not the descriptive food and potion assumptions used for stat context.", add);
        if (!setup.consumables.length) sectionPanel.appendChild(create("p", "empty", "No consumables planned"));
        setup.consumables.forEach((entry, index) => {
            const fieldset = create("fieldset");
            const head = create("div", "row-head");
            append(head, create("h3", "", entry.name || `Consumable ${index + 1}`), button("Remove", "danger", () => {
                setup.consumables.splice(index, 1); markAndRender();
            }));
            fieldset.appendChild(head);
            const grid = create("div", "grid four");
            selectField(grid, "Category", entry, "category", CONSUMABLE_CATEGORIES);
            textField(grid, "Name", entry, "name", { maxLength: 100, keepEmpty: true });
            textField(grid, "Quantity", entry, "quantity", { type: "number", min: 1, max: 9999 });
            textField(grid, "ESO item ID", entry, "itemId", { type: "number", min: 1, max: 4294967294 });
            textField(grid, "ESO item link", entry, "itemLink", { maxLength: 2048 });
            textField(grid, "Icon path", entry, "icon", { maxLength: 512 });
            textField(grid, "Note", entry, "note", { maxLength: 4000, multiline: true });
            fieldset.appendChild(grid);
            sectionPanel.appendChild(fieldset);
        });
    }

    function detectionFields(kind) {
        if (["passive", "ability", "champion", "championSlotted"].includes(kind)) return [["id", "ESO ID"]];
        if (kind === "skillLine") return [["skillType", "Skill type"], ["skillLineIndex", "Skill-line index"]];
        if (kind === "trait") return [["craftingType", "Crafting type"], ["researchLineIndex", "Research-line index"], ["traitIndex", "Trait index"]];
        return [];
    }

    function renderChecklist() {
        const setup = currentSetup();
        setup.checklist = setup.checklist || [];
        const add = button("Add Checklist Step", "", () => {
            if (setup.checklist.length < 100) setup.checklist.push({ category: "passive", name: "", completed: false });
            markAndRender();
        });
        add.disabled = setup.checklist.length >= 100;
        sectionHeading("Progression checklist", "Detection metadata is optional. Use it only when the website has reliable ESO API identifiers.", add);
        if (!setup.checklist.length) sectionPanel.appendChild(create("p", "empty", "No progression steps planned"));
        setup.checklist.forEach((entry, index) => {
            const fieldset = create("fieldset");
            const head = create("div", "row-head");
            append(head, create("h3", "", entry.name || `Checklist step ${index + 1}`), button("Remove", "danger", () => {
                setup.checklist.splice(index, 1); markAndRender();
            }));
            fieldset.appendChild(head);
            const grid = create("div", "grid four");
            selectField(grid, "Category", entry, "category", CHECKLIST_CATEGORIES);
            textField(grid, "Name", entry, "name", { maxLength: 100, keepEmpty: true });
            textField(grid, "Target rank", entry, "targetRank", { type: "number", min: 1, max: 50 });
            textField(grid, "Ability ID", entry, "abilityId", { type: "number", min: 1, max: 4294967294 });
            textField(grid, "Icon path", entry, "icon", { maxLength: 512 });
            checkboxField(grid, "Completed", entry, "completed");
            textField(grid, "Note", entry, "note", { maxLength: 4000, multiline: true });
            fieldset.appendChild(grid);

            const detection = entry.detection || {};
            const detectionBox = create("fieldset");
            detectionBox.appendChild(create("legend", "", "Automatic detection (advanced)"));
            const detectionGrid = create("div", "grid four");
            const kindHolder = { kind: detection.kind || "" };
            selectField(detectionGrid, "Detection kind", kindHolder, "kind", DETECTION_KINDS, {
                afterChange: value => {
                    if (!value) delete entry.detection;
                    else entry.detection = { kind: value };
                    markAndRender();
                }
            });
            detectionFields(detection.kind).forEach(([key, label]) => textField(detectionGrid, label, detection, key,
                { type: "number", min: 1, max: 4294967294 }));
            detectionBox.appendChild(detectionGrid);
            fieldset.appendChild(detectionBox);
            sectionPanel.appendChild(fieldset);
        });
    }

    function renderAssumptions() {
        sectionHeading("Buff assumptions", "These are descriptive conditions for the guide. They are separate from consumable acquisition and exact stat snapshots.");
        const setup = currentSetup();
        const assumptions = setup.buffAssumptions || (setup.buffAssumptions = {});
        const grid = create("div", "grid two");
        textField(grid, "Food assumption", assumptions, "food", { maxLength: 512 });
        textField(grid, "Potion assumption", assumptions, "potion", { maxLength: 512 });
        sectionPanel.appendChild(grid);
        const listGrid = create("div", "grid");
        [["selfBuffs", "Self buffs"], ["groupBuffs", "Group buffs"], ["targetConditions", "Target conditions"]]
            .forEach(([key, labelText]) => {
                const holder = { value: (assumptions[key] || []).join("\n") };
                textField(listGrid, `${labelText} (one per line)`, holder, "value", { multiline: true,
                    afterChange: value => {
                        assumptions[key] = value.split(/\r?\n/).map(line => line.trim()).filter(Boolean).slice(0, 20);
                        changed();
                    } });
            });
        sectionPanel.appendChild(listGrid);
    }

    function cleanBuild() {
        const value = clone(build);
        value.selectedSetup = selectedSetup + 1;
        value.setups.forEach(setup => {
            ["front", "back"].forEach(barKey => {
                const bar = ((setup.skillBars || {})[barKey] || []).map(skill =>
                    skill && Object.keys(skill).length ? skill : null);
                while (bar.length && !bar[bar.length - 1]) bar.pop();
                setup.skillBars[barKey] = bar;
            });
            Object.keys(setup.alternatives || {}).forEach(slot => {
                if (!setup.alternatives[slot] || !setup.alternatives[slot].length) delete setup.alternatives[slot];
            });
            DISCIPLINES.forEach(([key]) => {
                const discipline = setup.champion[key];
                if (!discipline) return;
                while (discipline.slottables.length && discipline.slottables[discipline.slottables.length - 1] == null) {
                    discipline.slottables.pop();
                }
            });
        });
        return value;
    }

    function websiteValidation(value) {
        const errors = [];
        if (!String(value.name || "").trim()) errors.push("Build: a name is required.");
        value.setups.forEach((setup, setupIndex) => {
            const prefix = `Setup ${setupIndex + 1}`;
            if (!String(setup.name || "").trim()) errors.push(`${prefix}: a name is required.`);
            const attributes = (setup.character || {}).attributes || {};
            const total = (attributes.health || 0) + (attributes.magicka || 0) + (attributes.stamina || 0);
            if (total > 64) errors.push(`${prefix}: attribute points total ${total}; the maximum is 64.`);
            [["frontMain", "frontOff"], ["backMain", "backOff"]].forEach(([main, off]) => {
                if (TWO_HANDED.has(Number((setup.equipment[main] || {}).weaponType)) && setup.equipment[off]) {
                    errors.push(`${prefix}: ${SLOT_DEFINITIONS[main][0]} is two-handed, so ${SLOT_DEFINITIONS[off][0]} must be empty.`);
                }
            });
            Object.entries(setup.alternatives || {}).forEach(([slot, alternatives]) => {
                if (alternatives.length && !setup.equipment[slot]) errors.push(`${prefix}: ${SLOT_DEFINITIONS[slot][0]} alternatives require primary equipment.`);
            });
        });
        return errors;
    }

    function showErrors(messages) {
        errorList.replaceChildren(...messages.map(message => create("li", "", message)));
        errorPanel.hidden = messages.length === 0;
    }

    async function generate() {
        clearTimeout(generationTimer);
        const requestNumber = ++generationNumber;
        try {
            const value = cleanBuild();
            const errors = websiteValidation(value);
            if (errors.length) throw new Error(errors.join("\n"));
            jsonOutput.textContent = JSON.stringify(value, null, 2);
            codeOutput.value = "";
            outputStatus.textContent = `Encoding with ${encoder.name || "the selected implementation"}\u2026`;
            outputStatus.className = "status";
            const code = await encoder.encode(value);
            if (requestNumber !== generationNumber) return;
            codeOutput.value = code;
            outputStatus.textContent = `${value.setups.length} setup${value.setups.length === 1 ? "" : "s"} encoded`;
            outputStatus.className = "status success";
            showErrors([]);
        } catch (error) {
            if (requestNumber !== generationNumber) return;
            const value = cleanBuild();
            jsonOutput.textContent = JSON.stringify(value, null, 2);
            codeOutput.value = "";
            outputStatus.textContent = "Current form is not valid";
            outputStatus.className = "status";
            showErrors(String(error.message || error).split("\n"));
        }
    }

    function updateTabs() {
        renderTabs();
    }

    function changed() {
        dirty = true;
        clearTimeout(generationTimer);
        generationTimer = setTimeout(() => {
            updateTabs();
            generate();
        }, 100);
    }

    function markAndRender() {
        dirty = true;
        renderBuildAndSetup();
        renderTabs();
        renderSection();
        generate();
    }

    function replaceBuild(value) {
        build = clone(value);
        selectedSetup = Math.max(0, Math.min((build.selectedSetup || 1) - 1, build.setups.length - 1));
        build.setups.forEach(setup => {
            setup.equipment = setup.equipment || {};
            setup.alternatives = setup.alternatives || {};
            setup.skillBars = setup.skillBars || { front: [], back: [] };
            setup.character = setup.character || { attributes: {}, subclassLines: [] };
            setup.champion = setup.champion || blankChampion();
            setup.consumables = setup.consumables || [];
            setup.checklist = setup.checklist || [];
            setup.buffAssumptions = setup.buffAssumptions || {};
        });
        dirty = false;
        renderBuildAndSetup();
        renderTabs();
        renderSection();
        generate();
    }

    async function getExample() {
        if (cachedExample) return clone(cachedExample);
        const response = await fetch("../example-build.json", { cache: "no-cache" });
        if (!response.ok) throw new Error(`Unable to load example-build.json (HTTP ${response.status}).`);
        cachedExample = await response.json();
        return clone(cachedExample);
    }

    async function loadExample(force) {
        if (!force && dirty && !window.confirm("Replace the current form with the full example?")) return;
        try {
            replaceBuild(await getExample());
        } catch (error) {
            showErrors([`${error.message} Serve the buildplanner directory over HTTP or HTTPS so the browser can fetch the shared fixture.`]);
            outputStatus.textContent = "Full example could not be loaded";
        }
    }

    setupSelect.addEventListener("change", () => {
        selectedSetup = Number(setupSelect.value);
        build.selectedSetup = selectedSetup + 1;
        renderBuildAndSetup(); renderTabs(); renderSection(); generate();
    });
    document.getElementById("add-setup").addEventListener("click", () => {
        if (build.setups.length >= 100) return;
        build.setups.push(blankSetup(`Setup ${build.setups.length + 1}`));
        selectedSetup = build.setups.length - 1;
        build.selectedSetup = selectedSetup + 1;
        markAndRender();
    });
    document.getElementById("duplicate-setup").addEventListener("click", () => {
        if (build.setups.length >= 100) return;
        const copy = clone(currentSetup());
        copy.name = `${copy.name || "Setup"} Copy`;
        build.setups.splice(selectedSetup + 1, 0, copy);
        selectedSetup += 1;
        build.selectedSetup = selectedSetup + 1;
        markAndRender();
    });
    document.getElementById("remove-setup").addEventListener("click", () => {
        if (build.setups.length <= 1 || !window.confirm(`Remove ${currentSetup().name || "this setup"}?`)) return;
        build.setups.splice(selectedSetup, 1);
        selectedSetup = Math.min(selectedSetup, build.setups.length - 1);
        build.selectedSetup = selectedSetup + 1;
        markAndRender();
    });
    document.getElementById("load-example").addEventListener("click", () => loadExample(false));
    document.getElementById("new-build").addEventListener("click", () => {
        if (dirty && !window.confirm("Discard the current form and start a blank build?")) return;
        replaceBuild(blankBuild());
    });
    document.getElementById("download-json").addEventListener("click", () => {
        const value = JSON.stringify(cleanBuild(), null, 2);
        const blob = new Blob([value], { type: "application/json" });
        const link = create("a");
        link.href = URL.createObjectURL(blob);
        const safeName = String(build.name || "build").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "build";
        link.download = `${safeName}.json`;
        link.click();
        URL.revokeObjectURL(link.href);
    });
    document.querySelectorAll("[data-copy]").forEach(control => control.addEventListener("click", async () => {
        const source = document.getElementById(control.dataset.copy);
        const value = source.value == null ? source.textContent : source.value;
        try {
            await navigator.clipboard.writeText(value);
            const original = control.textContent;
            control.textContent = "Copied";
            setTimeout(() => { control.textContent = original; }, 1200);
        } catch (_) {
            if (source.select) source.select();
        }
    }));

    renderBuildAndSetup();
    renderTabs();
    renderSection();
    generate();
    loadExample(true);
})();
