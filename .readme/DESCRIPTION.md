[SIZE="5"][B]Build Planner[/B][/SIZE]

Build Planner is an in-game notebook for ESO builds. It is meant for the point where you have a guide open on another screen and want to turn that guide into something easier to follow in game.

Enter the sets, weights, traits, enchantments, skills, Champion Points, supplies, and other requirements from a guide. Build Planner keeps them together as a named build with as many setups as you need: boss, trash, solo, crafted, no-trial, different armor weights, or anything else that makes sense for the build.

It does not scrape build websites and it never equips gear, spends points, or changes your action bars. The plan stays a plan until you make the changes yourself.

[SIZE="4"][B]Required Library[/B][/SIZE]

[LIST]
[*][URL="https://www.esoui.com/downloads/info2241-LibSetsAllsetitemsingamepreview.luaAPIexcelsheet.html"]LibSets[/URL]
[/LIST]

[SIZE="4"][B]Optional Add-ons and Libraries[/B][/SIZE]

[LIST]
[*][URL="https://www.esoui.com/downloads/info4775-ShoppingList.html"]Shopping List[/URL] - Creates a shopping list from tradeable gear and planned glyphs. When it is not installed, Build Planner provides an SL2 code instead.
[*][URL="https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html"]LibAddonMenu-2.0[/URL] - Adds font scale, contrast, and status-marker settings to Add-on Settings.
[*][URL="https://www.esoui.com/downloads/info2118-LibMainMenu-2.0.html"]LibMainMenu-2.0[/URL] - Adds a keyboard main-menu button.
[*]Tamriel Trade Centre, EsoHub, Master Merchant, or Arkadius Trade Tools - Supplies an optional local price estimate for buyable gear. Build Planner does not contact trader websites or search remote traders.
[/LIST]

[SIZE="5"][B][U][COLOR="DarkOrange"]BACK UP YOUR SAVED VARIABLES BEFORE TESTING A NEW RELEASE OR MIGRATION.[/COLOR][/U][/B][/SIZE]

[SIZE="4"][B]Gear Planning[/B][/SIZE]

[LIST]
[*]A familiar equipment layout for armor, jewelry, and both weapon bars
[*]Set-name autocomplete from ESO and LibSets
[*]Filtered armor weight, weapon type, trait, enchantment, quality, level, and Champion Point choices
[*]Correct two-handed weapon occupancy and compatible copy or move actions
[*]Primary requirements plus per-slot alternatives and set-wide replacements
[*]Native item icons and ESO tooltips using representative planned item links
[*]Setup defaults for quality, level, and Champion Points
[*]Notes and preferred acquisition routes for individual slots
[/LIST]

[SIZE="4"][B]Acquisition and Readiness[/B][/SIZE]

Build Planner checks equipped gear, backpacks, the bank, and equipment remembered from other characters. Exact matches are separated from pieces that still need a trait, enchantment, or quality change.

The Readiness report groups work into Buy, Craft, Farm, Reconstruct, Transmute, Owned, and Unknown. LibSets data is used to show known set zones, nearby crafting wayshrines, set type, and crafting trait requirements. Installed price add-ons may provide a local estimate for buyable pieces.

ESO add-ons cannot query every guild trader or choose the nearest live listing. Export buyable requirements to Shopping List and search the guild stores available to your account normally.

[LIST]
[*]Ready, adjustable, missing, and conflicting equipment counts
[*]Character, backpack, equipped, or bank location for matched pieces
[*]Warnings when multiple setups depend on the same physical item
[*]Upgrade, glyph, and estimated transmute-material summaries
[*]Automatic recalculation after inventory, bank, equipment, and collection changes
[/LIST]

[SIZE="4"][B]The Rest of the Build[/B][/SIZE]

[LIST]
[*]Front-bar and back-bar skill planning with native ability tooltips
[*]Health, Magicka, and Stamina attributes; race; Mundus Stone; curse; and class or subclass lines
[*]Craft, Warfare, and Fitness Champion allocations with four slottable positions per discipline
[*]Food, drink, potion, poison, and other supply requirements
[*]Passive, skill-line, unlock, crafting-research, and other progression checklists
[*]Automatic checklist detection where ESO exposes the required information
[*]Food, potion, self-buff, group-buff, and target-condition assumptions kept separate from calculated stats
[/LIST]

[SIZE="4"][B]Guided Walkthrough[/B][/SIZE]

The walkthrough turns the current setup into an ordered list of work. Every task answers three questions: what the build calls for, what your account currently has, and what to do next.

Use Next Needed to skip completed tasks. Related Planner buttons open the exact gear page, skill bar, Champion plan, checklist entry, or stat-capture view named by the task. The walkthrough finishes with separate front-bar and back-bar stat captures.

[SIZE="4"][B]Compare, Capture, and Stat Impact[/B][/SIZE]

[LIST]
[*]Compare any two setups and show only the gear, skills, character, Champion, supplies, checklist, or assumption values that changed
[*]Create named boss, trash, solo, parse, or no-trial variations from an existing setup
[*]Capture a new build from the character's currently equipped gear, action bars, attributes, race, Mundus Stone, curse, class lines, and Champion setup
[*]Save exact front-bar and back-bar character-sheet snapshots
[*]Mark captures stale when a stat-affecting part of the plan changes
[*]Show safely derived armor, weapon, set-bonus, trait, and enchantment effects separately from exact character-sheet totals
[/LIST]

Planned gear effects are descriptive where ESO has conditional bonuses that cannot be simulated reliably. Build Planner does not pretend those effects are exact character-sheet math.

[SIZE="4"][B]Sharing and Recovery[/B][/SIZE]

GBP1 codes contain one complete build and all of its setups. They include equipment, alternatives, skills, character choices, Champion Points, supplies, checklists, acquisition preferences, and buff assumptions. Character-specific stat snapshots and local revision history stay on your account.

Build websites can generate compatible GBP1 codes with the dependency-free JavaScript, Python, and PHP reference generators included in the project source.

Build Planner also provides:

[LIST]
[*]Named revision checkpoints for adapting a build to a new game update
[*]Undo for recently deleted builds and setups
[*]Bounded, checksummed recovery snapshots stored separately from the primary saved data
[*]Transactional migration, import, and restore validation
[/LIST]

[SIZE="4"][B]Keyboard and Gamepad[/B][/SIZE]

Keyboard/mouse and native gamepad interfaces are both supported. User-facing text is localized in English, Spanish, and French. Accessibility options include font scaling, stronger contrast, clearer focus states, and optional non-color status indicators.

[SIZE="4"][B]Getting Started[/B][/SIZE]

[LIST=1]
[*]Open Build Planner with [CODE]/buildplanner[/CODE], [CODE]/gbp[/CODE], the keybind, or the optional main-menu button.
[*]Create a build for the guide and add a setup for each gear variation.
[*]Select a gear slot and begin typing the set name. Choose the remaining values from the filtered controls and save the slot.
[*]Fill in Skills, Character, Champion, Supplies, Checklist, and Assumptions as needed.
[*]Open Readiness or Walkthrough to work through the setup.
[*]Use Shopping List for tradeable pieces and capture both weapon-bar stat snapshots when the setup is complete.
[/LIST]

[SIZE="4"][B]Commands[/B][/SIZE]

[CODE]/buildplanner[/CODE] or [CODE]/gbp[/CODE] - Open or close Build Planner

[CODE]/buildplannerhelp[/CODE] - Open the in-game guide

[CODE]/gbpaudit[/CODE] - Run live API, item-link, layout, and build checks for troubleshooting and release testing

[SIZE="4"][B]What Build Planner Does Not Do[/B][/SIZE]

[LIST]
[*]No website scraping or automatic reading of build pages
[*]No remote guild-trader search
[*]No automatic gear equipping, skill-bar changes, or Champion Point spending
[*]No invented stat totals for conditional effects ESO does not expose safely
[/LIST]

If something is unclear or a source is wrong, include the build code, setup name, item slot, language, and whether you use keyboard or gamepad when reporting it. That usually makes the problem much easier to reproduce.
