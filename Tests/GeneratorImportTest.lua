dofile("Tests/DataTests.lua")

local code = arg and arg[1]
assert(type(code) == "string" and code:sub(1, 5) == "GBP1:",
    "generator did not return a GBP1 code")
local build, message = GravvyBuildPlannerShare.DecodeCode(code)
assert(build, message)
assert(build.name == "Stamina Warden", "generated build name changed")
assert(build.selectedSetupIndex == 1, "generated selected setup changed")
assert(#build.setups == 2, "generator did not retain every setup")
assert(build.setups[1].name == "Base Setup", "generated setup name changed")
assert(build.setups[2].name == "Solo Setup", "generated second setup changed")
assert(build.setups[1].equipment.waist.setName == "Whorl of the Depths",
    "generated equipment changed")
assert(build.setups[1].acquisition.waist.preferredRoute == "farm",
    "generated route changed")
assert(build.setups[1].alternatives.waist[1].setName == "Order's Wrath",
    "generated alternative changed")
assert(build.setups[1].skillBars.front[1].abilityId == 1001,
    "generated front-bar skill changed")
assert(build.setups[1].skillBars.front[3] == nil,
    "generated empty skill position changed")
assert(build.setups[1].skillBars.front[6].abilityId == 1006,
    "generated ultimate changed")
assert(build.setups[1].character.attributes.stamina == 50,
    "generated attributes changed")
assert(build.setups[1].character.raceId == 9,
    "generated race changed")
assert(build.setups[1].character.subclassLines[3] == "Grave Lord",
    "generated subclass line changed")
assert(build.setups[1].champion.craft.allocations[1].skillId == 2001,
    "generated Craft allocation changed")
assert(build.setups[1].champion.warfare.slottables[2] == 2102,
    "generated Warfare slottable changed")
assert(build.setups[1].champion.fitness.allocations[2].points == 50,
    "generated Fitness allocation changed")
assert(build.setups[1].consumables[1].category == "food",
    "generated consumable category changed")
assert(build.setups[1].consumables[2].quantity == 100,
    "generated consumable quantity changed")
assert(build.setups[1].checklist[1].detection.kind == "passive",
    "generated passive detector changed")
assert(build.setups[1].checklist[2].detection.skillLineIndex == 1,
    "generated skill-line detector changed")
assert(build.setups[1].checklist[4].detection.traitIndex == 8,
    "generated crafting-trait detector changed")
assert(build.setups[1].buffAssumptions.targetConditions[1] == "Trial dummy",
    "generated assumptions changed")
assert(build.setups[2].buffAssumptions.selfBuffs[1] == "Major Resolve",
    "generated second-setup assumptions changed")

print("Build Planner generator import test passed")
