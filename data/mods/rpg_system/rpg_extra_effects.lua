-- Maps display labels to their corresponding flat JSON field names in traits.json.
-- Used only for startup validation; values in EXTRA_EFFECTS are hardcoded and
-- must be kept in sync with traits.json by hand.
local LABEL_TO_FIELD = {
  ["Attack Cost"]        = "attackcost_modifier",
  ["Move Cost"]          = "movecost_modifier",
  ["Reading Speed"]      = "reading_speed_multiplier",
  ["Fall Damage"]        = "falling_damage_multiplier",
  ["Noise"]              = "noise_modifier",
  ["Scent"]              = "scent_modifier",
  ["Crafting Speed"]     = "crafting_speed_modifier",
  ["Construction Speed"] = "construction_speed_modifier",
  ["Healing Awake"]      = "healing_awake",
  ["Healing Resting"]    = "healing_resting",
  ["Hearing"]            = "hearing_modifier",
  ["Mana Regen"]         = "mana_regen_multiplier",
  ["Max Stamina"]        = "max_stamina_modifier",
  ["Speed"]              = "speed_modifier",
  ["Stealth"]            = "stealth_modifier",
  ["Weight Capacity"]    = "weight_capacity_modifier",
  ["Night Vision"]       = "night_vision_range",
  ["Dodge"]              = "dodge_modifier",
  ["Mana"]               = "mana_modifier",
  ["Metabolism"]         = "metabolism_modifier",
  ["Bleed Resist"]       = "bleed_resist",
  ["Bash Damage"]        = "bash_dmg_bonus",
  ["Cut Damage"]         = "cut_dmg_bonus",
  ["Pierce Damage"]      = "pierce_dmg_bonus",
  ["Packmule"]           = "packmule_modifier",
  ["Mending"]            = "mending_modifier",
  ["Fatigue"]            = "fatigue_modifier",
  ["Fatigue Regen"]      = "fatigue_regen_modifier",
  ["Stamina Regen"]      = "stamina_regen_modifier",
  ["Mana Multiplier"]    = "mana_multiplier",
}

-- Labels that live inside array fields (craft_skill_bonus, encumbrance_always,
-- bodytemp_modifiers, lumination) and have no single JSON key.
local KNOWN_ARRAY_LABELS = {
  "Melee Skill", "Dodge Skill", "Unarmed Skill", "Survival Skill",
  "Fabrication Skill", "Electronics Skill", "Mechanics Skill",
  "Computers Skill", "Trapping Skill", "Cooking Skill", "First Aid Skill",
  "Rifles Skill", "Handguns Skill", "SMGs Skill", "Shotguns Skill",
  "Driving Skill", "Tailoring Skill", "Spellcraft Skill",
  "Encumbrance torso", "Encumbrance head", "Encumbrance eyes", "Encumbrance mouth",
  "Encumbrance arm_l", "Encumbrance arm_r", "Encumbrance hand_l", "Encumbrance hand_r",
  "Encumbrance leg_l", "Encumbrance leg_r", "Encumbrance foot_l", "Encumbrance foot_r",
  "Body Temp Low", "Body Temp High",
  "Lumination ARM_L", "Lumination ARM_R",
}

--- Checks every label in extra_effects, accumulates all unmapped ones, then
--- emits a single gdebug.log_warning with the full list.
local function validate_extra_effects(extra_effects)
  local array_set = {}
  for _, lbl in ipairs(KNOWN_ARRAY_LABELS) do
    array_set[lbl] = true
  end

  local warnings = {}
  for mutation_id, effects in pairs(extra_effects) do
    for _, effect in ipairs(effects) do
      local label = effect.label
      if not LABEL_TO_FIELD[label]
        and not label:match("^Armor%s+ALL%s+")
        and not array_set[label]
      then
        warnings[#warnings + 1] = "  " .. mutation_id .. ": unknown label '" .. label .. "'"
      end
    end
  end

  if #warnings > 0 then
    gdebug.log_warning(
      "RPG System: EXTRA_EFFECTS has " .. #warnings .. " unmapped label(s):\n"
      .. table.concat(warnings, "\n")
    )
  end
end

local EXTRA_EFFECTS = {
  ["RPG_ACROBAT"] = {
    { label = "Move Cost", value = 0.920, scalar = "benefit" },
    { label = "Dodge", value = 6.000, scalar = "benefit" },
  },
  ["RPG_AETHER_STRIDER"] = {
    { label = "Move Cost", value = 0.850, scalar = "benefit" },
    { label = "Mana", value = 2200.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.450, scalar = "benefit" },
  },
  ["RPG_ARCANE_TRICKSTER"] = {
    { label = "Move Cost", value = 0.900, scalar = "benefit" },
    { label = "Mana", value = 1000.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.200, scalar = "benefit" },
  },
  ["RPG_ARCHMAGE"] = {
    { label = "Mana", value = 5000.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.600, scalar = "benefit" },
  },
  ["RPG_ARTIFICER"] = {
    { label = "Crafting Speed", value = 3.000, scalar = "benefit" },
    { label = "Construction Speed", value = 3.000, scalar = "benefit" },
    { label = "Electronics Skill", value = 10.000, scalar = "benefit" },
    { label = "Fabrication Skill", value = 10.000, scalar = "benefit" },
    { label = "Mechanics Skill", value = 10.000, scalar = "benefit" },
    { label = "Computers Skill", value = 10.000, scalar = "benefit" },
    { label = "Trapping Skill", value = 10.000, scalar = "benefit" },
    { label = "Cooking Skill", value = 10.000, scalar = "benefit" },
    { label = "Survival Skill", value = 10.000, scalar = "benefit" },
    { label = "Driving Skill", value = 5.000, scalar = "benefit" },
    { label = "Handguns Skill", value = 5.000, scalar = "benefit" },
    { label = "Rifles Skill", value = 5.000, scalar = "benefit" },
    { label = "SMGs Skill", value = 5.000, scalar = "benefit" },
    { label = "Shotguns Skill", value = 5.000, scalar = "benefit" },
  },
  ["RPG_ASSASSIN"] = {
    { label = "Move Cost", value = 0.920, scalar = "benefit" },
    { label = "Hearing", value = 1.300, scalar = "benefit" },
    { label = "Noise", value = 0.600, scalar = "benefit" },
    { label = "Stealth", value = 1.500, scalar = "benefit" },
  },
  ["RPG_BATTLEMAGE"] = {
    { label = "Mana", value = 1500.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.200, scalar = "benefit" },
    { label = "Armor ALL Physical", value = 6.000, scalar = "benefit" },
  },
  ["RPG_BERSERKER"] = {
    { label = "Attack Cost", value = 0.850, scalar = "benefit" },
  },
  ["RPG_BLADE_SAINT"] = {
    { label = "Attack Cost", value = 0.700, scalar = "benefit" },
    { label = "Move Cost", value = 0.900, scalar = "benefit" },
    { label = "Dodge", value = 6.000, scalar = "benefit" },
  },
  ["RPG_BLOOD_REAVER"] = {
    { label = "Attack Cost", value = 0.750, scalar = "benefit" },
  },
  ["RPG_COLOSSUS"] = {
    { label = "Armor ALL Physical", value = 14.000, scalar = "benefit" },
  },
  ["RPG_CRAFTSMAN"] = {
    { label = "Electronics Skill", value = 6.000, scalar = "benefit" },
    { label = "Tailoring Skill", value = 6.000, scalar = "benefit" },
    { label = "Mechanics Skill", value = 6.000, scalar = "benefit" },
    { label = "First Aid Skill", value = 6.000, scalar = "benefit" },
    { label = "Computers Skill", value = 6.000, scalar = "benefit" },
    { label = "Trapping Skill", value = 6.000, scalar = "benefit" },
    { label = "Fabrication Skill", value = 6.000, scalar = "benefit" },
    { label = "Cooking Skill", value = 2.000, scalar = "benefit" },
    { label = "Survival Skill", value = 6.000, scalar = "benefit" },
    { label = "Rifles Skill", value = 2.000, scalar = "benefit" },
    { label = "Handguns Skill", value = 2.000, scalar = "benefit" },
    { label = "Crafting Speed", value = 2.000, scalar = "benefit" },
    { label = "Construction Speed", value = 2.000, scalar = "benefit" },
  },
  ["RPG_DEATH_STALKER"] = {
    { label = "Attack Cost", value = 0.820, scalar = "benefit" },
    { label = "Move Cost", value = 0.880, scalar = "benefit" },
  },
  ["RPG_DUELIST"] = {
    { label = "Attack Cost", value = 0.800, scalar = "benefit" },
    { label = "Move Cost", value = 0.900, scalar = "benefit" },
    { label = "Dodge", value = 4.000, scalar = "benefit" },
  },
  ["RPG_GUARDIAN"] = {
    { label = "Armor ALL Physical", value = 6.000, scalar = "benefit" },
  },
  ["RPG_HUNTER"] = {
    { label = "Move Cost", value = 0.900, scalar = "benefit" },
    { label = "Night Vision", value = 30.000, scalar = "benefit" },
  },
  ["RPG_MAGE"] = {
    { label = "Mana", value = 1000.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.250, scalar = "benefit" },
  },
  ["RPG_MYSTIC"] = {
    { label = "Mana", value = 2500.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.500, scalar = "benefit" },
    { label = "Lumination ARM_L", value = 15.000, scalar = "benefit" },
    { label = "Lumination ARM_R", value = 15.000, scalar = "benefit" },
  },
  ["RPG_PATHFINDER"] = {
    { label = "Move Cost", value = 0.700, scalar = "benefit" },
  },
  ["RPG_PHANTOM"] = {
    { label = "Move Cost", value = 0.850, scalar = "benefit" },
    { label = "Stealth", value = 1.800, scalar = "benefit" },
  },
  ["RPG_RANGER"] = {
    { label = "Move Cost", value = 0.950, scalar = "benefit" },
    { label = "Night Vision", value = 20.000, scalar = "benefit" },
  },
  ["RPG_SAGE"] = {
    { label = "Mana", value = 2800.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.400, scalar = "benefit" },
    { label = "Reading Speed", value = 0.350, scalar = "benefit" },
    { label = "Crafting Speed", value = 3.000, scalar = "benefit" },
    { label = "Construction Speed", value = 3.000, scalar = "benefit" },
    { label = "Electronics Skill", value = 10.000, scalar = "benefit" },
    { label = "Fabrication Skill", value = 10.000, scalar = "benefit" },
    { label = "Mechanics Skill", value = 10.000, scalar = "benefit" },
    { label = "Computers Skill", value = 10.000, scalar = "benefit" },
    { label = "Tailoring Skill", value = 10.000, scalar = "benefit" },
    { label = "First Aid Skill", value = 10.000, scalar = "benefit" },
    { label = "Dodge", value = 3.000, scalar = "benefit" },
  },
  ["RPG_SAGE_MN"] = {
    { label = "Mana", value = 2000.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.300, scalar = "benefit" },
    { label = "Reading Speed", value = 0.350, scalar = "benefit" },
    { label = "Crafting Speed", value = 3.000, scalar = "benefit" },
    { label = "Construction Speed", value = 3.000, scalar = "benefit" },
    { label = "Spellcraft Skill", value = 5.000, scalar = "benefit" },
    { label = "Electronics Skill", value = 10.000, scalar = "benefit" },
    { label = "Fabrication Skill", value = 10.000, scalar = "benefit" },
    { label = "Mechanics Skill", value = 10.000, scalar = "benefit" },
    { label = "Computers Skill", value = 10.000, scalar = "benefit" },
    { label = "Tailoring Skill", value = 10.000, scalar = "benefit" },
    { label = "First Aid Skill", value = 10.000, scalar = "benefit" },
    { label = "Dodge", value = 3.000, scalar = "benefit" },
  },
  ["RPG_SCHOLAR"] = {
    { label = "Mana", value = 800.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.200, scalar = "benefit" },
    { label = "Reading Speed", value = 0.500, scalar = "benefit" },
    { label = "Fabrication Skill", value = 6.000, scalar = "benefit" },
    { label = "Electronics Skill", value = 6.000, scalar = "benefit" },
    { label = "Mechanics Skill", value = 6.000, scalar = "benefit" },
    { label = "Computers Skill", value = 2.000, scalar = "benefit" },
    { label = "First Aid Skill", value = 2.000, scalar = "benefit" },
    { label = "Crafting Speed", value = 2.000, scalar = "benefit" },
  },
  ["RPG_SCOUT"] = {
    { label = "Move Cost", value = 0.950, scalar = "benefit" },
  },
  ["RPG_SENTINEL"] = {
    { label = "Armor ALL Physical", value = 9.000, scalar = "benefit" },
  },
  ["RPG_SPELLBLADE"] = {
    { label = "Mana", value = 1200.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.300, scalar = "benefit" },
  },
  ["RPG_SPELLSWORD"] = {
    { label = "Mana", value = 800.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.150, scalar = "benefit" },
  },
  ["RPG_SPELL_KNIGHT"] = {
    { label = "Mana", value = 1800.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.250, scalar = "benefit" },
    { label = "Armor ALL Physical", value = 8.000, scalar = "benefit" },
  },
  ["RPG_TRAILBLAZER"] = {
    { label = "Move Cost", value = 0.550, scalar = "benefit" },
  },
  ["RPG_TRAIT_ACROBAT"] = {
    { label = "Fall Damage", value = 0.050, scalar = "benefit" },
    { label = "Dodge", value = 2.000, scalar = "benefit" },
    { label = "Weight Capacity", value = 0.900, scalar = "penalty" },
  },
  ["RPG_TRAIT_APEX_PREDATOR"] = {
    { label = "Melee Skill", value = 3.000, scalar = "benefit" },
    { label = "Dodge", value = 3.000, scalar = "benefit" },
    { label = "Attack Cost", value = 0.900, scalar = "benefit" },
  },
  ["RPG_TRAIT_ARCANE_BATTERY"] = {
    { label = "Mana", value = 5000.000, scalar = "benefit" },
    { label = "Mana Regen", value = 0.500, scalar = "penalty" },
  },
  ["RPG_TRAIT_BLINK_STEP"] = {
    { label = "Move Cost", value = 0.850, scalar = "benefit" },
    { label = "Max Stamina", value = 0.900, scalar = "penalty" },
  },
  ["RPG_TRAIT_BLOOD_ECHO"] = {
    { label = "Melee Skill", value = 2.000, scalar = "benefit" },
    { label = "Survival Skill", value = 3.000, scalar = "benefit" },
    { label = "Healing Resting", value = 1.500, scalar = "benefit" },
    { label = "Metabolism", value = 0.100, scalar = "benefit" },
  },
  ["RPG_TRAIT_CLOTTING_FACTOR"] = {
    { label = "Bleed Resist", value = 1000.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_COLD_ADAPTATION"] = {
    { label = "Body Temp Low", value = -3000.000, scalar = "benefit" },
    { label = "Body Temp High", value = 0.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_COMBAT_REFLEXES"] = {
    { label = "Dodge", value = 3.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_EFFICIENT_METABOLISM"] = {
    { label = "Metabolism", value = -0.500, scalar = "benefit" },
    { label = "Fatigue", value = -0.500, scalar = "benefit" },
  },
  ["RPG_TRAIT_ENGINEER"] = {
    { label = "Fabrication Skill", value = 10.000, scalar = "benefit" },
    { label = "Electronics Skill", value = 10.000, scalar = "benefit" },
    { label = "Mechanics Skill", value = 10.000, scalar = "benefit" },
    { label = "Crafting Speed", value = 3.000, scalar = "benefit" },
    { label = "Dodge", value = -5.000, scalar = "penalty" },
  },
  ["RPG_TRAIT_ESSENCE_DRAIN"] = {
    { label = "Mana", value = 1200.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.100, scalar = "benefit" },
  },
  ["RPG_TRAIT_ESSENCE_DRAIN_MN"] = {
    { label = "Spellcraft Skill", value = 4.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_GHOST_STEP"] = {
    { label = "Stealth", value = 1.200, scalar = "benefit" },
    { label = "Dodge", value = 3.000, scalar = "benefit" },
    { label = "Move Cost", value = 0.850, scalar = "benefit" },
    { label = "Attack Cost", value = 1.100, scalar = "penalty" },
  },
  ["RPG_TRAIT_GLASS_CANNON"] = {
    { label = "Speed", value = 1.200, scalar = "benefit" },
    { label = "Armor ALL Physical", value = -5.000, scalar = "penalty" },
  },
  ["RPG_TRAIT_GODSLAYER"] = {
    { label = "Attack Cost", value = 0.700, scalar = "benefit" },
    { label = "Armor ALL Physical", value = 8.000, scalar = "benefit" },
    { label = "Move Cost", value = 1.250, scalar = "penalty" },
  },
  ["RPG_TRAIT_HEAT_ADAPTATION"] = {
    { label = "Body Temp Low", value = 0.000, scalar = "benefit" },
    { label = "Body Temp High", value = 3000.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_IMMORTAL"] = {
    { label = "Healing Resting", value = 2.000, scalar = "benefit" },
    { label = "Healing Awake", value = 2.000, scalar = "benefit" },
    { label = "Move Cost", value = 1.100, scalar = "penalty" },
  },
  ["RPG_TRAIT_IRON_FISTS"] = {
    { label = "Bash Damage", value = 6.000, scalar = "benefit" },
    { label = "Cut Damage", value = 4.000, scalar = "benefit" },
    { label = "Pierce Damage", value = 3.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_IRON_HIDE"] = {
    { label = "Armor ALL Acid", value = 8.000, scalar = "benefit" },
    { label = "Armor ALL Heat", value = 8.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_IRON_METABOLISM"] = {
    { label = "Metabolism", value = 0.200, scalar = "benefit" },
  },
  ["RPG_TRAIT_JUGGERNAUT"] = {
    { label = "Weight Capacity", value = 1.600, scalar = "benefit" },
    { label = "Armor ALL Physical", value = 6.000, scalar = "benefit" },
    { label = "Move Cost", value = 1.300, scalar = "penalty" },
    { label = "Speed", value = 0.850, scalar = "penalty" },
  },
  ["RPG_TRAIT_LIGHTNING_REFLEXES"] = {
    { label = "Move Cost", value = 0.900, scalar = "benefit" },
    { label = "Attack Cost", value = 0.900, scalar = "benefit" },
    { label = "Weight Capacity", value = 0.900, scalar = "penalty" },
  },
  ["RPG_TRAIT_LIGHTWEIGHT"] = {
    { label = "Move Cost", value = 0.750, scalar = "benefit" },
    { label = "Weight Capacity", value = 0.750, scalar = "penalty" },
  },
  ["RPG_TRAIT_MANA_FONT"] = {
    { label = "Mana", value = 1250.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.100, scalar = "benefit" },
    { label = "Mana Multiplier", value = 1.100, scalar = "benefit" },
    { label = "Max Stamina", value = 0.900, scalar = "penalty" },
  },
  ["RPG_TRAIT_MASTER_CRAFTSMAN"] = {
    { label = "Crafting Speed", value = 1.750, scalar = "benefit" },
    { label = "Construction Speed", value = 1.500, scalar = "benefit" },
    { label = "Attack Cost", value = 1.075, scalar = "penalty" },
  },
  ["RPG_TRAIT_NATURAL_HEALER"] = {
    { label = "Healing Awake", value = 1.300, scalar = "benefit" },
    { label = "Healing Resting", value = 1.750, scalar = "benefit" },
    { label = "Metabolism", value = 0.100, scalar = "benefit" },
  },
  ["RPG_TRAIT_OVERLOAD"] = {
    { label = "Move Cost", value = 0.800, scalar = "benefit" },
    { label = "Attack Cost", value = 0.800, scalar = "benefit" },
    { label = "Fatigue", value = 0.700, scalar = "penalty" },
    { label = "Max Stamina", value = 0.750, scalar = "penalty" },
  },
  ["RPG_TRAIT_PACK_MULE"] = {
    { label = "Weight Capacity", value = 1.600, scalar = "benefit" },
    { label = "Move Cost", value = 1.100, scalar = "penalty" },
  },
  ["RPG_TRAIT_PACK_RAT"] = {
    { label = "Packmule", value = 1.500, scalar = "benefit" },
    { label = "Move Cost", value = 1.050, scalar = "penalty" },
  },
  ["RPG_TRAIT_PERFECT_BALANCE"] = {
    { label = "Dodge", value = 3.000, scalar = "benefit" },
    { label = "Move Cost", value = 0.850, scalar = "benefit" },
  },
  ["RPG_TRAIT_PERFECT_CRAFTER"] = {
    { label = "Fabrication Skill", value = 5.000, scalar = "benefit" },
    { label = "Electronics Skill", value = 5.000, scalar = "benefit" },
    { label = "Mechanics Skill", value = 5.000, scalar = "benefit" },
    { label = "Crafting Speed", value = 3.000, scalar = "benefit" },
    { label = "Construction Speed", value = 3.000, scalar = "benefit" },
    { label = "Dodge", value = -5.000, scalar = "penalty" },
  },
  ["RPG_TRAIT_PREDATOR"] = {
    { label = "Survival Skill", value = 3.000, scalar = "benefit" },
    { label = "Melee Skill", value = 2.000, scalar = "benefit" },
    { label = "Attack Cost", value = 0.900, scalar = "benefit" },
    { label = "Night Vision", value = 10.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_PRIMAL_FURY"] = {
    { label = "Melee Skill", value = 2.000, scalar = "benefit" },
    { label = "Unarmed Skill", value = 2.000, scalar = "benefit" },
    { label = "Attack Cost", value = 0.800, scalar = "benefit" },
    { label = "Armor ALL Physical", value = -10.000, scalar = "penalty" },
  },
  ["RPG_TRAIT_RAPID_HEALER"] = {
    { label = "Healing Resting", value = 1.750, scalar = "benefit" },
    { label = "Healing Awake", value = 1.500, scalar = "benefit" },
    { label = "First Aid Skill", value = -5.000, scalar = "penalty" },
  },
  ["RPG_TRAIT_RAPID_METABOLISM"] = {
    { label = "Stamina Regen", value = 1.000, scalar = "benefit" },
    { label = "Metabolism", value = 0.750, scalar = "benefit" },
  },
  ["RPG_TRAIT_REGENERATOR"] = {
    { label = "Mending", value = 2.000, scalar = "benefit" },
    { label = "Metabolism", value = 0.100, scalar = "benefit" },
  },
  ["RPG_TRAIT_REINFORCED_SKELETON"] = {
    { label = "Armor ALL Physical", value = 6.000, scalar = "benefit" },
    { label = "Move Cost", value = 1.100, scalar = "penalty" },
  },
  ["RPG_TRAIT_SCENTLESS"] = {
    { label = "Scent", value = 0.100, scalar = "benefit" },
  },
  ["RPG_TRAIT_SHADOW_ASSASSIN"] = {
    { label = "Stealth", value = 1.200, scalar = "benefit" },
    { label = "Dodge", value = 2.000, scalar = "benefit" },
    { label = "Melee Skill", value = 2.000, scalar = "benefit" },
    { label = "Dodge Skill", value = 2.000, scalar = "benefit" },
    { label = "Attack Cost", value = 0.900, scalar = "benefit" },
    { label = "Move Cost", value = 0.900, scalar = "benefit" },
    { label = "Armor ALL Physical", value = -8.000, scalar = "penalty" },
  },
  ["RPG_TRAIT_SHADOW_CLONE"] = {
    { label = "Dodge", value = 2.000, scalar = "benefit" },
    { label = "Move Cost", value = 0.850, scalar = "benefit" },
    { label = "Attack Cost", value = 0.900, scalar = "benefit" },
    { label = "Encumbrance torso", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance head", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance eyes", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance mouth", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance arm_l", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance arm_r", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance hand_l", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance hand_r", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance leg_l", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance leg_r", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance foot_l", value = 6.000, scalar = "penalty" },
    { label = "Encumbrance foot_r", value = 6.000, scalar = "penalty" },
  },
  ["RPG_TRAIT_SHARPSHOOTER"] = {
    { label = "Rifles Skill", value = 5.000, scalar = "benefit" },
    { label = "Handguns Skill", value = 5.000, scalar = "benefit" },
    { label = "Melee Skill", value = -5.000, scalar = "penalty" },
  },
  ["RPG_TRAIT_SILENT_STEP"] = {
    { label = "Dodge", value = 2.000, scalar = "benefit" },
    { label = "Move Cost", value = 0.900, scalar = "benefit" },
  },
  ["RPG_TRAIT_SPELL_RESONANCE"] = {
    { label = "Mana", value = 1700.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.200, scalar = "benefit" },
    { label = "Max Stamina", value = 0.800, scalar = "penalty" },
  },
  ["RPG_TRAIT_SPELL_RESONANCE_MN"] = {
    { label = "Spellcraft Skill", value = 2.000, scalar = "benefit" },
    { label = "Mana", value = 1200.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.100, scalar = "benefit" },
    { label = "Max Stamina", value = 0.800, scalar = "penalty" },
  },
  ["RPG_TRAIT_TACTICAL_MIND"] = {
    { label = "Melee Skill", value = 4.000, scalar = "benefit" },
    { label = "Dodge", value = 3.000, scalar = "benefit" },
    { label = "Crafting Speed", value = 2.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_TIRELESS"] = {
    { label = "Max Stamina", value = 1.250, scalar = "benefit" },
    { label = "Speed", value = 0.950, scalar = "penalty" },
  },
  ["RPG_TRAIT_TIRELESS_WORKER"] = {
    { label = "Fatigue", value = -0.500, scalar = "benefit" },
    { label = "Fatigue Regen", value = 0.800, scalar = "benefit" },
    { label = "Move Cost", value = 1.100, scalar = "penalty" },
  },
  ["RPG_TRAIT_UNBREAKABLE"] = {
    { label = "Armor ALL Physical", value = 12.000, scalar = "benefit" },
    { label = "Mending", value = 2.000, scalar = "benefit" },
    { label = "Move Cost", value = 1.150, scalar = "penalty" },
  },
  ["RPG_TRAIT_UNSTOPPABLE_FORCE"] = {
    { label = "Attack Cost", value = 0.900, scalar = "benefit" },
    { label = "Bash Damage", value = 8.000, scalar = "benefit" },
  },
  ["RPG_TRAIT_WORLD_WALKER"] = {
    { label = "Survival Skill", value = 4.000, scalar = "benefit" },
    { label = "Dodge", value = 4.000, scalar = "benefit" },
    { label = "Move Cost", value = 0.500, scalar = "benefit" },
    { label = "Max Stamina", value = 0.750, scalar = "penalty" },
  },
  ["RPG_VOID_DANCER"] = {
    { label = "Move Cost", value = 0.700, scalar = "benefit" },
    { label = "Mana", value = 1600.000, scalar = "benefit" },
    { label = "Attack Cost", value = 0.850, scalar = "benefit" },
  },
  ["RPG_WAR_MAGUS"] = {
    { label = "Mana", value = 2200.000, scalar = "benefit" },
    { label = "Mana Regen", value = 1.350, scalar = "benefit" },
    { label = "Armor ALL Physical", value = 4.000, scalar = "benefit" },
  },
  ["RPG_WIND_DANCER"] = {
    { label = "Move Cost", value = 0.800, scalar = "benefit" },
    { label = "Dodge", value = 8.000, scalar = "benefit" },
  },
}

validate_extra_effects(EXTRA_EFFECTS)

return EXTRA_EFFECTS
