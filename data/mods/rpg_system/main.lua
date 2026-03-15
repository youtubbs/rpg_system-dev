-- main.lua
gdebug.log_info("RPG System: Main")

local mod = game.mod_runtime[game.current_mod]
local storage = game.mod_storage[game.current_mod]
local mutations = require("rpg_mutations")
local EXTRA_EFFECTS = require("rpg_extra_effects")
local Mutation = mutations.Mutation
local MUTATIONS = mutations.MUTATIONS
local ALL_CLASS_IDS = mutations.ALL_CLASS_IDS
local ALL_TRAIT_IDS = mutations.ALL_TRAIT_IDS
local BASE_CLASS_IDS = mutations.BASE_CLASS_IDS
local PRESTIGE_CLASS_IDS = mutations.PRESTIGE_CLASS_IDS
local STAT_BONUS_IDS = mutations.STAT_BONUS_IDS
local PERIODIC_BONUS_IDS = mutations.PERIODIC_BONUS_IDS
local KILL_MONSTER_BONUS_IDS = mutations.KILL_MONSTER_BONUS_IDS
local register_mutation = mutations.register_mutation
local gettext = locale.gettext
local vgettext = locale.vgettext
local function color_text(text, color) return string.format("<color_%s>%s</color>", color, text) end

local function color_good(text) return color_text(text, "light_green") end

local function color_bad(text) return color_text(text, "light_red") end

local function color_warning(text) return color_text(text, "yellow") end

local function color_info(text) return color_text(text, "light_cyan") end

local function color_highlight(text) return color_text(text, "white") end

local function create_progress_bar(current, max, width)
  width = width or 20
  local filled = math.floor((current / max) * width)
  local empty = width - filled
  local bar = color_good(string.rep("█", filled)) .. color_text(string.rep("░", empty), "dark_gray")
  local percent = math.floor((current / max) * 100)
  return string.format("[%s] %d%%", bar, percent)
end

local function wrap_text(text, width, indent)
  width = width or 60
  indent = indent or ""

  if #text <= width then return indent .. text end

  local lines = {}
  local current_line = ""

  for word in text:gmatch("%S+") do
    local test_line = current_line == "" and word or (current_line .. " " .. word)
    if #test_line <= width then
      current_line = test_line
    else
      if current_line ~= "" then table.insert(lines, indent .. current_line) end
      current_line = word
    end
  end

  if current_line ~= "" then table.insert(lines, indent .. current_line) end

  return table.concat(lines, "\n")
end

-- Experience Curve Functions for Levels 1-40
-- Formula: XP = 2.2387 * level^3.65
local XP_COEFFICIENT = 2.2387
local XP_EXPONENT = 3.65

-- Progression Constants
local LEVELS_PER_STAT_POINT = 2
local LEVELS_PER_TRAIT_SLOT = 5
local DEFAULT_SYSTEM_MENU_KEY = "END"
local TRAIT_LEVEL_STEP = 0.02

local get_scalars
local get_char_value
local get_scalar_value
local get_nonplayer_scalars
local apply_nonplayer_stat_points
local strip_scaling_block
local format_decimal

local COST_LIKE_LABELS = {
  ["Attack Cost"] = true,
  ["Move Cost"] = true,
  ["Reading Speed"] = true,
  ["Fall Damage"] = true,
  ["Noise"] = true,
  ["Scent"] = true,
}

local MULTIPLIER_LABELS = {
  ["Crafting Speed"] = true,
  ["Construction Speed"] = true,
  ["Healing Awake"] = true,
  ["Healing Resting"] = true,
  ["Hearing"] = true,
  ["Mana Regen"] = true,
  ["Max Stamina"] = true,
  ["Speed"] = true,
  ["Stealth"] = true,
  ["Weight Capacity"] = true,
}

local SCALAR_DEFAULTS = {
  rpg_class_benefit_scalar = 1.0,
  rpg_class_penalty_scalar = 1.0,
  rpg_trait_benefit_scalar = 1.0,
  rpg_trait_penalty_scalar = 1.0,
  rpg_trait_level_scalar = 0.5,
  rpg_xp_multiplier = 1.0,
  rpg_effect_growth_cap = 0.30,
  rpg_nonplayer_passive_xp_scalar = 1.0,
  rpg_nonplayer_kill_xp_scalar = 1.0,
  rpg_nonplayer_min_level = 0,
  rpg_nonplayer_max_level = 40,
  rpg_nonplayer_class_benefit_scalar = 1.0,
  rpg_nonplayer_class_penalty_scalar = 1.0,
  rpg_nonplayer_trait_benefit_scalar = 1.0,
  rpg_nonplayer_trait_penalty_scalar = 1.0,
  rpg_nonplayer_xp_multiplier = 1.0,
  rpg_nonplayer_trait_level_scalar = 0.5,
  rpg_nonplayer_effect_growth_cap = 0.30,
  rpg_nonplayer_background_rate = 0.05,
  rpg_nonplayer_spawn_level_chance_scalar = 0.90,
  rpg_nonplayer_speed_per_level_bonus = 2.5,
  rpg_nonplayer_levels_per_stat_point = 2,
  rpg_nonplayer_levels_per_trait_slot = 5,
}

local NONPLAYER_LEVEL_KEY = "rpg_nonplayer_level"
local NONPLAYER_EXP_KEY = "rpg_nonplayer_exp"
local NONPLAYER_XP_NEXT_KEY = "rpg_nonplayer_xp_to_next"
local NONPLAYER_INIT_KEY = "rpg_nonplayer_initialized"
local NONPLAYER_LAST_PASSIVE_TURN_KEY = "rpg_nonplayer_last_passive_turn"
local NONPLAYER_BACKGROUND_XP_BANK_KEY = "rpg_nonplayer_background_xp_bank"
local NONPLAYER_CLASS_KEY = "rpg_nonplayer_class"
local NONPLAYER_TRAITS_KEY = "rpg_nonplayer_traits"
local NONPLAYER_BUILD_LEVEL_KEY = "rpg_nonplayer_build_level"
local NONPLAYER_CLASS_BONUS_STR_KEY = "rpg_nonplayer_class_bonus_str"
local NONPLAYER_CLASS_BONUS_DEX_KEY = "rpg_nonplayer_class_bonus_dex"
local NONPLAYER_CLASS_BONUS_INT_KEY = "rpg_nonplayer_class_bonus_int"
local NONPLAYER_CLASS_BONUS_PER_KEY = "rpg_nonplayer_class_bonus_per"
local NONPLAYER_TRAIT_BONUS_STR_KEY = "rpg_nonplayer_trait_bonus_str"
local NONPLAYER_TRAIT_BONUS_DEX_KEY = "rpg_nonplayer_trait_bonus_dex"
local NONPLAYER_TRAIT_BONUS_INT_KEY = "rpg_nonplayer_trait_bonus_int"
local NONPLAYER_TRAIT_BONUS_PER_KEY = "rpg_nonplayer_trait_bonus_per"
local NONPLAYER_STAT_POINTS_KEY = "rpg_nonplayer_stat_points"
local NONPLAYER_STAT_BONUS_STR_KEY = "rpg_nonplayer_stat_bonus_str"
local NONPLAYER_STAT_BONUS_DEX_KEY = "rpg_nonplayer_stat_bonus_dex"
local NONPLAYER_STAT_BONUS_INT_KEY = "rpg_nonplayer_stat_bonus_int"
local NONPLAYER_STAT_BONUS_PER_KEY = "rpg_nonplayer_stat_bonus_per"
local NONPLAYER_MAX_TRAITS_KEY = "rpg_nonplayer_max_traits"
local ANALYSIS_LENS_SCAN_RADIUS = 20
local NONPLAYER_PASSIVE_INTERVAL_TURNS = 300

local LEGACY_TRAIT_IDS = {
  "RPG_TRAIT_BIONIC_SYMBIOTE",
  "RPG_TRAIT_VITAL_ESSENCE",
  "RPG_TRAIT_RADIOACTIVE_BLOOD",
  "RPG_TRAIT_IRON_HIDE",
  "RPG_TRAIT_LIGHTWEIGHT",
  "RPG_TRAIT_PACK_MULE",
  "RPG_TRAIT_TIRELESS",
  "RPG_TRAIT_MANA_FONT",
  "RPG_TRAIT_BLINK_STEP",
  "RPG_TRAIT_NATURAL_HEALER",
  "RPG_TRAIT_ADAPTIVE_BIOLOGY",
  "RPG_TRAIT_GLASS_CANNON",
  "RPG_TRAIT_JUGGERNAUT",
  "RPG_TRAIT_ARCANE_BATTERY",
  "RPG_TRAIT_IRON_FISTS",
  "RPG_TRAIT_EFFICIENT_METABOLISM",
  "RPG_TRAIT_COMBAT_REFLEXES",
  "RPG_TRAIT_ACROBAT",
  "RPG_TRAIT_TIRELESS_WORKER",
  "RPG_TRAIT_RAPID_METABOLISM",
  "RPG_TRAIT_SCENTLESS",
  "RPG_TRAIT_CLOTTING_FACTOR",
  "RPG_TRAIT_REGENERATOR",
  "RPG_TRAIT_MASTER_CRAFTSMAN",
  "RPG_TRAIT_PACK_RAT",
  "RPG_TRAIT_NATURAL_BUTCHER",
  "RPG_TRAIT_VAMPIRIC",
}

local FORCED_OBSOLETE_TRAIT_IDS = {
  RPG_TRAIT_ADAPTIVE_BIOLOGY = true,
}

--- Maps canonical trait IDs (strings) to their MagicalNights variant IDs.
--- Variants apply old spellcraft bonuses when MagicalNights is active;
--- canonical entries apply mana bonuses when it is not.
local MN_TRAIT_VARIANTS = {
  ["RPG_TRAIT_SPELL_RESONANCE"] = "RPG_TRAIT_SPELL_RESONANCE_MN",
  ["RPG_TRAIT_ESSENCE_DRAIN"]   = "RPG_TRAIT_ESSENCE_DRAIN_MN",
}
local MN_CLASS_VARIANTS = {
  ["RPG_SAGE"] = "RPG_SAGE_MN",
}

-- Function to register a new mutation with the RPG system (can be called by other mods)
-- config: table with mutation properties (id, type, symbol, requirements, stat_bonuses, etc.)
-- See rpg_mutations.lua Mutation class for full structure
mod.add_mutation = function(config)
  if not config or not config.id then
    gdebug.log_error("RPG System: add_mutation called without valid config or id")
    return false
  end

  if MUTATIONS[config.id] then
    -- If it's already there, just ignore.
    return false
  end

  local mutation = Mutation.new(config)
  MUTATIONS[config.id] = mutation
  register_mutation(mutation)

  gdebug.log_info("RPG System: Registered new mutation: " .. config.id)
  return true
end

local function get_rpg_level(exp)
  local level = math.floor((exp / XP_COEFFICIENT) ^ (1 / XP_EXPONENT))
  return math.min(level, 40)
end

local function rpg_xp_needed(level)
  if level >= 40 then return XP_COEFFICIENT * (40 ^ XP_EXPONENT) end
  return XP_COEFFICIENT * (level ^ XP_EXPONENT)
end

local function get_nonplayer_level_limits(player)
  local min_level = math.floor(get_scalar_value(player, "rpg_nonplayer_min_level"))
  local max_level = math.floor(get_scalar_value(player, "rpg_nonplayer_max_level"))
  min_level = math.max(0, min_level)
  max_level = math.max(0, math.min(40, max_level))
  if min_level > max_level then
    min_level = max_level
  end
  return min_level, max_level
end

local function clamp_nonplayer_level(level, player)
  local min_level, max_level = get_nonplayer_level_limits(player)
  return math.max(min_level, math.min(max_level, level))
end

local function get_elapsed_turns_now()
  return (gapi.current_turn() - gapi.turn_zero()):to_turns()
end

local function rng_int(min_value, max_value)
  if gapi and gapi.rng then
    return gapi.rng(min_value, max_value)
  end
  return math.random(min_value, max_value)
end

local function parse_nonplayer_trait_ids(raw_value)
  local ids = {}
  if not raw_value or raw_value == "" then
    return ids
  end
  for id in raw_value:gmatch("[^,]+") do
    ids[#ids + 1] = id
  end
  return ids
end

local function join_nonplayer_trait_ids(ids)
  if #ids == 0 then
    return ""
  end
  return table.concat(ids, ",")
end

local function get_nonplayer_bonus_component(creature, key)
  return tonumber(creature:get_value(key)) or 0
end

local function add_nonplayer_trait_bonus(creature, delta)
  creature:set_value(NONPLAYER_TRAIT_BONUS_STR_KEY, tostring(get_nonplayer_bonus_component(creature, NONPLAYER_TRAIT_BONUS_STR_KEY) + (delta.str or 0)))
  creature:set_value(NONPLAYER_TRAIT_BONUS_DEX_KEY, tostring(get_nonplayer_bonus_component(creature, NONPLAYER_TRAIT_BONUS_DEX_KEY) + (delta.dex or 0)))
  creature:set_value(NONPLAYER_TRAIT_BONUS_INT_KEY, tostring(get_nonplayer_bonus_component(creature, NONPLAYER_TRAIT_BONUS_INT_KEY) + (delta.int or 0)))
  creature:set_value(NONPLAYER_TRAIT_BONUS_PER_KEY, tostring(get_nonplayer_bonus_component(creature, NONPLAYER_TRAIT_BONUS_PER_KEY) + (delta.per or 0)))
end

local function set_nonplayer_class_bonus(creature, delta)
  creature:set_value(NONPLAYER_CLASS_BONUS_STR_KEY, tostring(delta.str or 0))
  creature:set_value(NONPLAYER_CLASS_BONUS_DEX_KEY, tostring(delta.dex or 0))
  creature:set_value(NONPLAYER_CLASS_BONUS_INT_KEY, tostring(delta.int or 0))
  creature:set_value(NONPLAYER_CLASS_BONUS_PER_KEY, tostring(delta.per or 0))
end

local function get_nonplayer_effective_speed(creature, player, level)
  local base_speed = creature:get_speed() or 100
  local lv = level or (tonumber(creature:get_value(NONPLAYER_LEVEL_KEY)) or 0)

  local speed_per_level = SCALAR_DEFAULTS.rpg_nonplayer_speed_per_level_bonus
  if player then
    speed_per_level = get_scalar_value(player, "rpg_nonplayer_speed_per_level_bonus")
  end

  local speed_bonus = lv * speed_per_level
  return math.max(1, math.floor(base_speed + speed_bonus))
end

--- Returns effective stats for any non-player creature.
--- Optional `player` enables non-player scalar scaling; `level` overrides stored level for class formulas.
local function get_nonplayer_effective_stats(creature, player, level)
  local spt_str = get_nonplayer_bonus_component(creature, NONPLAYER_STAT_BONUS_STR_KEY)
  local spt_dex = get_nonplayer_bonus_component(creature, NONPLAYER_STAT_BONUS_DEX_KEY)
  local spt_int = get_nonplayer_bonus_component(creature, NONPLAYER_STAT_BONUS_INT_KEY)
  local spt_per = get_nonplayer_bonus_component(creature, NONPLAYER_STAT_BONUS_PER_KEY)

  local ch = creature:as_character()
  if ch then
    return {
      STR = ch:get_str() + spt_str,
      DEX = ch:get_dex() + spt_dex,
      INT = ch:get_int() + spt_int,
      PER = ch:get_per() + spt_per,
    }
  end

  local class_str = get_nonplayer_bonus_component(creature, NONPLAYER_CLASS_BONUS_STR_KEY)
  local class_dex = get_nonplayer_bonus_component(creature, NONPLAYER_CLASS_BONUS_DEX_KEY)
  local class_int = get_nonplayer_bonus_component(creature, NONPLAYER_CLASS_BONUS_INT_KEY)
  local class_per = get_nonplayer_bonus_component(creature, NONPLAYER_CLASS_BONUS_PER_KEY)
  local trait_str = get_nonplayer_bonus_component(creature, NONPLAYER_TRAIT_BONUS_STR_KEY)
  local trait_dex = get_nonplayer_bonus_component(creature, NONPLAYER_TRAIT_BONUS_DEX_KEY)
  local trait_int = get_nonplayer_bonus_component(creature, NONPLAYER_TRAIT_BONUS_INT_KEY)
  local trait_per = get_nonplayer_bonus_component(creature, NONPLAYER_TRAIT_BONUS_PER_KEY)

  local scaled_cls_str, scaled_cls_dex, scaled_cls_int, scaled_cls_per = class_str, class_dex, class_int, class_per
  local scaled_trt_str, scaled_trt_dex, scaled_trt_int, scaled_trt_per = trait_str, trait_dex, trait_int, trait_per

  if player then
    local np = get_nonplayer_scalars(player)
    local lv = level or (tonumber(creature:get_value(NONPLAYER_LEVEL_KEY)) or 0)
    local cls_b = np.class_benefit
    local cls_p = np.class_penalty
    local trt_b = np.trait_benefit
    local trt_p = np.trait_penalty
    scaled_cls_str = math.floor(class_str * (class_str < 0 and cls_p or cls_b) * lv)
    scaled_cls_dex = math.floor(class_dex * (class_dex < 0 and cls_p or cls_b) * lv)
    scaled_cls_int = math.floor(class_int * (class_int < 0 and cls_p or cls_b) * lv)
    scaled_cls_per = math.floor(class_per * (class_per < 0 and cls_p or cls_b) * lv)
    scaled_trt_str = math.floor(trait_str * (trait_str >= 0 and trt_b or trt_p))
    scaled_trt_dex = math.floor(trait_dex * (trait_dex >= 0 and trt_b or trt_p))
    scaled_trt_int = math.floor(trait_int * (trait_int >= 0 and trt_b or trt_p))
    scaled_trt_per = math.floor(trait_per * (trait_per >= 0 and trt_b or trt_p))
  end

  local base_str = math.floor((creature:get_hp_max() or 1) / 8 + (creature:get_melee() or 0) * 1.5)
  local effective_speed = get_nonplayer_effective_speed(creature, player, level)
  local base_dex = math.floor((creature:get_dodge() or 0) * 2 + math.max(0, effective_speed - 80) / 10)
  local base_int = math.floor((creature:power_rating() or 0) * 2)
  local base_per = math.floor((creature:get_dodge() or 0) + (creature:get_melee() or 0) * 0.5 + (creature:power_rating() or 0))

  return {
    STR = math.max(1, base_str + scaled_cls_str + scaled_trt_str + spt_str),
    DEX = math.max(1, base_dex + scaled_cls_dex + scaled_trt_dex + spt_dex),
    INT = math.max(1, base_int + scaled_cls_int + scaled_trt_int + spt_int),
    PER = math.max(1, base_per + scaled_cls_per + scaled_trt_per + spt_per),
  }
end

local function get_focus_stat(stats)
  local best = "STR"
  if stats.DEX > stats[best] then best = "DEX" end
  if stats.INT > stats[best] then best = "INT" end
  if stats.PER > stats[best] then best = "PER" end
  return best
end

local function get_mutation_stat_vector(mutation)
  local bonuses = mutation.stat_bonuses or {}
  return {
    str = bonuses.str or 0,
    dex = bonuses.dex or 0,
    int = bonuses.int or 0,
    per = bonuses.per or 0,
  }
end

local function get_critter_skill_conversion_bonus(mutation_id)
  local delta = { str = 0, dex = 0, int = 0, per = 0 }
  local effects = EXTRA_EFFECTS[mutation_id]
  if not effects then
    return delta
  end

  local stat_keys = { "str", "dex", "int", "per" }
  for _, effect in ipairs(effects) do
    if effect.label:find(" Skill$") and effect.value > 0 then
      local gain = math.max(1, math.floor(effect.value / 2))
      local random_stat = stat_keys[rng_int(1, #stat_keys)]
      delta[random_stat] = delta[random_stat] + gain
    end
  end

  return delta
end

local function add_stat_vectors(a, b)
  return {
    str = (a.str or 0) + (b.str or 0),
    dex = (a.dex or 0) + (b.dex or 0),
    int = (a.int or 0) + (b.int or 0),
    per = (a.per or 0) + (b.per or 0),
  }
end

local function nonplayer_meets_requirements(creature, mutation, level)
  local reqs = mutation.requirements
  if not reqs then
    return true
  end

  if reqs.level and level < reqs.level then
    return false
  end

  if reqs.stats then
    local stats = get_nonplayer_effective_stats(creature)
    for stat_label, required in pairs(reqs.stats) do
      local current = stats[stat_label] or 0
      if current < required then
        return false
      end
    end
  end

  if reqs.skills then
    local ch = creature:as_character()
    if not ch then
      for _, required in pairs(reqs.skills) do
        if required > 0 then
          return false
        end
      end
    else
      for skill_name, required in pairs(reqs.skills) do
        local current = ch:get_skill_level(SkillId.new(skill_name))
        if current < required then
          return false
        end
      end
    end
  end

  return true
end

local function score_mutation_for_focus(mutation, focus_stat)
  local vector = get_mutation_stat_vector(mutation)
  local focus_key = string.lower(focus_stat)
  local focus_value = vector[focus_key] or 0
  local sum = vector.str + vector.dex + vector.int + vector.per
  return focus_value * 100 + sum * 10
end

local function weighted_pick(candidates, score_fn)
  if #candidates == 0 then
    return nil
  end

  local weights = {}
  local total = 0
  for i, candidate in ipairs(candidates) do
    local score = score_fn(candidate)
    local weight = math.max(1, math.floor(score + 100))
    weights[i] = weight
    total = total + weight
  end

  local roll = rng_int(1, total)
  local cumulative = 0
  for i, candidate in ipairs(candidates) do
    cumulative = cumulative + weights[i]
    if roll <= cumulative then
      return candidate
    end
  end
  return candidates[#candidates]
end

local function apply_nonplayer_class_choice(creature, class_id, class_mutation)
  local character = creature:as_character()
  if character then
    for _, existing_id in ipairs(ALL_CLASS_IDS) do
      if character:has_trait(existing_id) then
        character:remove_mutation(existing_id, true)
      end
    end
    character:set_mutation(MutationBranchId.new(class_id))
  else
    set_nonplayer_class_bonus(creature, get_mutation_stat_vector(class_mutation))
  end
  creature:set_value(NONPLAYER_CLASS_KEY, class_id)
end

local function apply_nonplayer_trait_choice(creature, trait_id, trait_mutation)
  local character = creature:as_character()
  if character then
    character:set_mutation(MutationBranchId.new(trait_id))
  else
    local delta = get_mutation_stat_vector(trait_mutation)
    local converted = get_critter_skill_conversion_bonus(trait_id)
    add_nonplayer_trait_bonus(creature, add_stat_vectors(delta, converted))
  end

  local traits = parse_nonplayer_trait_ids(creature:get_value(NONPLAYER_TRAITS_KEY))
  traits[#traits + 1] = trait_id
  creature:set_value(NONPLAYER_TRAITS_KEY, join_nonplayer_trait_ids(traits))
end

local function try_nonplayer_choose_class(creature, level)
  local current_class = creature:get_value(NONPLAYER_CLASS_KEY)
  local stats = get_nonplayer_effective_stats(creature)
  local focus_stat = get_focus_stat(stats)
  local candidates = {}

  for _, class_id in ipairs(ALL_CLASS_IDS) do
    local mutation = MUTATIONS[class_id:str()]
    if mutation and mutation.type == "class" then
      local class_key = class_id:str()
      local valid_path = false
      if current_class == "" then
        valid_path = not mutation.is_prestige
      else
        valid_path = mutation.is_prestige and mutation.base_class == current_class
      end

      if valid_path and nonplayer_meets_requirements(creature, mutation, level) then
        candidates[#candidates + 1] = { id = class_key, mutation = mutation }
      end
    end
  end

  local chosen = weighted_pick(candidates, function(candidate)
    return score_mutation_for_focus(candidate.mutation, focus_stat)
  end)

  if chosen then
    apply_nonplayer_class_choice(creature, chosen.id, chosen.mutation)
  end
end

local function try_nonplayer_choose_traits(creature, level, player)
  local traits = parse_nonplayer_trait_ids(creature:get_value(NONPLAYER_TRAITS_KEY))
  local trait_set = {}
  for _, id in ipairs(traits) do
    trait_set[id] = true
  end

  local stats = get_nonplayer_effective_stats(creature)
  local focus_stat = get_focus_stat(stats)
  local lv_per_slot = player and math.max(1, math.floor(get_scalar_value(player, "rpg_nonplayer_levels_per_trait_slot"))) or LEVELS_PER_TRAIT_SLOT
  local slots = 1 + math.floor(level / lv_per_slot)
  creature:set_value(NONPLAYER_MAX_TRAITS_KEY, tostring(slots))

  while #traits < slots do
    local candidates = {}
    for _, trait_id in ipairs(ALL_TRAIT_IDS) do
      local trait_key = trait_id:str()
      if not trait_set[trait_key] then
        local mutation = MUTATIONS[trait_key]
        if mutation and mutation.type == "trait" and nonplayer_meets_requirements(creature, mutation, level) then
          candidates[#candidates + 1] = { id = trait_key, mutation = mutation }
        end
      end
    end

    local chosen = weighted_pick(candidates, function(candidate)
      return score_mutation_for_focus(candidate.mutation, focus_stat)
    end)

    if not chosen then
      break
    end

    apply_nonplayer_trait_choice(creature, chosen.id, chosen.mutation)
    trait_set[chosen.id] = true
    traits[#traits + 1] = chosen.id
  end
end

local function sync_nonplayer_build(creature, level, player)
  local old_synced_level = tonumber(creature:get_value(NONPLAYER_BUILD_LEVEL_KEY)) or -1
  if old_synced_level >= level and creature:get_value(NONPLAYER_CLASS_KEY) ~= "" then
    return
  end

  if creature:get_value(NONPLAYER_CLASS_KEY) == "" or level > old_synced_level then
    try_nonplayer_choose_class(creature, level)
    try_nonplayer_choose_traits(creature, level, player)
    if player then
      apply_nonplayer_stat_points(creature, player, math.max(0, old_synced_level), level)
    end
  end

  creature:set_value(NONPLAYER_BUILD_LEVEL_KEY, tostring(level))
end

local function estimate_nonplayer_level(creature, player)
  local stats = get_nonplayer_effective_stats(creature)
  local hp_max = creature:get_hp_max() or 0
  local speed = creature:get_speed() or 100
  local melee = creature:get_melee() or 0
  local dodge = creature:get_dodge() or 0
  local power_rating = creature:power_rating() or 0

  local base = 0
  base = base + hp_max * 0.03
  base = base + math.max(0, speed - 90) * 0.08
  base = base + math.max(0, melee) * 0.9
  base = base + math.max(0, dodge) * 1.2
  base = base + math.max(0, power_rating) * 1.5
  base = base + (stats.STR + stats.DEX + stats.INT + stats.PER) * 0.05

  return clamp_nonplayer_level(math.floor(base), player)
end

local function sample_spawn_level_exp(player, baseline_level)
  local min_level, max_level = get_nonplayer_level_limits(player)
  local start_level = math.max(min_level, math.min(max_level, baseline_level))
  local level = start_level
  local chance_scalar = math.max(0.10, get_scalar_value(player, "rpg_nonplayer_spawn_level_chance_scalar"))
  local chance_thousand = math.max(1, math.floor(480 * chance_scalar))

  while level < max_level and rng_int(1, 1000) <= chance_thousand do
    level = level + 1
    chance_thousand = math.max(15, math.floor(chance_thousand * 0.62))
  end

  return level
end

local function sample_spawn_exp_for_level(level)
  if level >= 40 then
    return math.floor(rpg_xp_needed(40))
  end
  local lower = math.floor(rpg_xp_needed(level))
  local upper = math.max(lower, math.floor(rpg_xp_needed(level + 1)) - 1)
  return rng_int(lower, upper)
end

local function apply_nonplayer_background_passive_xp(creature, player, level)
  local last_turn = tonumber(creature:get_value(NONPLAYER_LAST_PASSIVE_TURN_KEY)) or get_elapsed_turns_now()
  local now_turn = get_elapsed_turns_now()
  if now_turn <= last_turn then
    return
  end

  local elapsed = now_turn - last_turn
  local intervals = math.floor(elapsed / NONPLAYER_PASSIVE_INTERVAL_TURNS)
  if intervals <= 0 then
    return
  end

  local scalars = get_scalars(player)
  local nearby_gain_per_tick = math.max(1, math.floor((3 + math.floor(level * 0.2)) * scalars.nonplayer_passive_xp))
  local bank = tonumber(creature:get_value(NONPLAYER_BACKGROUND_XP_BANK_KEY)) or 0
  bank = bank + (nearby_gain_per_tick * scalars.nonplayer_background_rate * intervals)

  local gained = math.floor(bank)
  bank = bank - gained
  creature:set_value(NONPLAYER_BACKGROUND_XP_BANK_KEY, tostring(bank))

  if gained > 0 then
    local current_exp = tonumber(creature:get_value(NONPLAYER_EXP_KEY)) or 0
    local old_level, new_level = update_nonplayer_level(creature, current_exp + gained, player)
    if new_level > old_level then
      sync_nonplayer_build(creature, new_level, player)
    end
  end

  creature:set_value(NONPLAYER_LAST_PASSIVE_TURN_KEY, tostring(last_turn + intervals * NONPLAYER_PASSIVE_INTERVAL_TURNS))
end

local function ensure_nonplayer_progress(creature, player)
  if not creature or creature:is_avatar() then
    return 0, 0, rpg_xp_needed(1)
  end

  local initialized = creature:get_value(NONPLAYER_INIT_KEY)
  if initialized ~= "1" then
    local baseline_level = estimate_nonplayer_level(creature, player)
    local sampled_level = sample_spawn_level_exp(player, baseline_level)
    local sampled_exp = sample_spawn_exp_for_level(sampled_level)

    creature:set_value(NONPLAYER_LEVEL_KEY, tostring(sampled_level))
    creature:set_value(NONPLAYER_EXP_KEY, tostring(sampled_exp))
    creature:set_value(NONPLAYER_XP_NEXT_KEY, tostring(math.max(0, rpg_xp_needed(math.min(sampled_level + 1, 40)) - sampled_exp)))
    creature:set_value(NONPLAYER_INIT_KEY, "1")
    creature:set_value(NONPLAYER_LAST_PASSIVE_TURN_KEY, tostring(get_elapsed_turns_now()))
    creature:set_value(NONPLAYER_BACKGROUND_XP_BANK_KEY, "0")
    creature:set_value(NONPLAYER_STAT_POINTS_KEY, "0")
    creature:set_value(NONPLAYER_STAT_BONUS_STR_KEY, "0")
    creature:set_value(NONPLAYER_STAT_BONUS_DEX_KEY, "0")
    creature:set_value(NONPLAYER_STAT_BONUS_INT_KEY, "0")
    creature:set_value(NONPLAYER_STAT_BONUS_PER_KEY, "0")
    creature:set_value(NONPLAYER_MAX_TRAITS_KEY, "0")
    if creature:get_value(NONPLAYER_CLASS_KEY) == "" then
      creature:set_value(NONPLAYER_CLASS_KEY, "")
    end
    if creature:get_value(NONPLAYER_TRAITS_KEY) == "" then
      creature:set_value(NONPLAYER_TRAITS_KEY, "")
    end
    sync_nonplayer_build(creature, sampled_level, player)
  end

  local level = tonumber(creature:get_value(NONPLAYER_LEVEL_KEY)) or 0
  local exp = tonumber(creature:get_value(NONPLAYER_EXP_KEY)) or 0
  local xp_to_next = tonumber(creature:get_value(NONPLAYER_XP_NEXT_KEY))

  level = clamp_nonplayer_level(level, player)
  if level >= 40 then
    exp = math.floor(rpg_xp_needed(40))
    xp_to_next = 0
  else
    exp = math.max(math.floor(rpg_xp_needed(level)), exp)
    xp_to_next = math.max(0, rpg_xp_needed(level + 1) - exp)
  end

  creature:set_value(NONPLAYER_LEVEL_KEY, tostring(level))
  creature:set_value(NONPLAYER_EXP_KEY, tostring(exp))
  creature:set_value(NONPLAYER_XP_NEXT_KEY, tostring(xp_to_next))

  apply_nonplayer_background_passive_xp(creature, player, level)

  level = tonumber(creature:get_value(NONPLAYER_LEVEL_KEY)) or level
  exp = tonumber(creature:get_value(NONPLAYER_EXP_KEY)) or exp
  xp_to_next = tonumber(creature:get_value(NONPLAYER_XP_NEXT_KEY)) or xp_to_next
  sync_nonplayer_build(creature, level, player)

  return level, exp, xp_to_next
end

local function get_creature_system_level(creature, player)
  if not creature then
    return 0
  end
  if creature:is_avatar() then
    return get_char_value(creature:as_character(), "rpg_level", 0)
  end
  local level = ensure_nonplayer_progress(creature, player)
  return level
end

local function compute_kill_xp(victim, killer_level)
  local hp_factor = (victim:get_hp_max() or 0) * 0.12
  local victim_level = get_creature_system_level(victim, gapi.get_avatar())
  local speed_value = victim:get_speed() or 100
  if not victim:is_avatar() then
    speed_value = get_nonplayer_effective_speed(victim, gapi.get_avatar(), victim_level)
  end
  local speed_factor = math.max(0, speed_value - 80) * 0.45
  local melee_factor = math.max(0, victim:get_melee() or 0) * 4.0
  local dodge_factor = math.max(0, victim:get_dodge() or 0) * 3.5
  local power_factor = math.max(0, victim:power_rating() or 0) * 25.0

  local stat_factor = 0
  local character = victim:as_character()
  if character then
    stat_factor = (character:get_str() + character:get_dex() + character:get_int() + character:get_per()) * 2.0
  else
    local effective_stats = get_nonplayer_effective_stats(victim)
    stat_factor = (effective_stats.STR + effective_stats.DEX + effective_stats.INT + effective_stats.PER) * 1.0
  end

  local base_xp = 4.0 + hp_factor + speed_factor + melee_factor + dodge_factor + power_factor + stat_factor + (victim_level * 6.0)
  local level_delta = victim_level - killer_level

  local level_mult
  if level_delta >= 0 then
    level_mult = 1.0 + (level_delta * 0.08)
  else
    level_mult = math.max(0.65, 1.0 + (level_delta * 0.03))
  end

  return math.max(1, math.floor(base_xp * level_mult))
end

local function update_nonplayer_level(creature, exp, player)
  local old_level = tonumber(creature:get_value(NONPLAYER_LEVEL_KEY)) or 0
  local min_level, max_level = get_nonplayer_level_limits(player)
  local new_level = clamp_nonplayer_level(get_rpg_level(exp), player)
  new_level = math.max(min_level, math.min(max_level, new_level))

  if new_level >= 40 then
    exp = math.floor(rpg_xp_needed(40))
  else
    exp = math.max(math.floor(rpg_xp_needed(new_level)), exp)
  end

  creature:set_value(NONPLAYER_LEVEL_KEY, tostring(new_level))
  creature:set_value(NONPLAYER_EXP_KEY, tostring(exp))
  creature:set_value(NONPLAYER_XP_NEXT_KEY, tostring(math.max(0, rpg_xp_needed(math.min(new_level + 1, 40)) - exp)))

  return old_level, new_level
end

local function add_nonplayer_xp(creature, amount, player, skip_ensure)
  if not creature or creature:is_avatar() then
    return false, 0, 0
  end

  local exp
  if skip_ensure then
    exp = tonumber(creature:get_value(NONPLAYER_EXP_KEY)) or 0
  else
    local _, ensured_exp = ensure_nonplayer_progress(creature, player)
    exp = ensured_exp
  end

  local xp_mult = player and get_scalar_value(player, "rpg_nonplayer_xp_multiplier") or 1.0
  local clamped_gain = math.max(1, math.floor(amount * xp_mult))
  local new_exp = exp + clamped_gain
  local old_level, new_level = update_nonplayer_level(creature, new_exp, player)
  if new_level > old_level then
    sync_nonplayer_build(creature, new_level, player)
  end
  return new_level > old_level, old_level, new_level
end

local function collect_nearby_creatures(center, radius)
  local map = gapi.get_map()
  local points = map:points_in_radius(center, radius, 0)
  local creatures = {}
  local seen = {}

  for _, point in ipairs(points) do
    local creature = gapi.get_creature_at(point, false)
    if creature then
      local key = tostring(creature:get_pos_ms())
      if not seen[key] then
        seen[key] = true
        table.insert(creatures, creature)
      end
    end
  end

  return creatures
end

local function format_creature_kind(creature)
  if creature:is_avatar() then
    return gettext("Avatar")
  end
  if creature:is_npc() then
    return gettext("NPC")
  end
  if creature:is_monster() then
    return gettext("Critter")
  end
  return gettext("Creature")
end

local function get_creature_progress(creature, player)
  if creature:is_avatar() then
    local c = creature:as_character()
    local level = get_char_value(c, "rpg_level", 0)
    local exp = get_char_value(c, "rpg_exp", 0)
    local xp_to_next = get_char_value(c, "rpg_xp_to_next_level", 0)
    return level, exp, xp_to_next
  end
  return ensure_nonplayer_progress(creature, player)
end

local function show_analysis_lens_screen(viewer, target)
  local target_level, target_exp, target_xp_to_next = ensure_nonplayer_progress(target, viewer)
  local np_scalars = get_nonplayer_scalars(viewer)
  local killer_level = get_char_value(viewer, "rpg_level", 0)
  local predicted_xp = compute_kill_xp(target, killer_level)

  -- Effective stats (with non-player scaling applied)
  local effective = get_nonplayer_effective_stats(target, viewer, target_level)

  -- Raw bonus components for breakdown display
  local cls_str = get_nonplayer_bonus_component(target, NONPLAYER_CLASS_BONUS_STR_KEY)
  local cls_dex = get_nonplayer_bonus_component(target, NONPLAYER_CLASS_BONUS_DEX_KEY)
  local cls_int = get_nonplayer_bonus_component(target, NONPLAYER_CLASS_BONUS_INT_KEY)
  local cls_per = get_nonplayer_bonus_component(target, NONPLAYER_CLASS_BONUS_PER_KEY)
  local trt_str = get_nonplayer_bonus_component(target, NONPLAYER_TRAIT_BONUS_STR_KEY)
  local trt_dex = get_nonplayer_bonus_component(target, NONPLAYER_TRAIT_BONUS_DEX_KEY)
  local trt_int = get_nonplayer_bonus_component(target, NONPLAYER_TRAIT_BONUS_INT_KEY)
  local trt_per = get_nonplayer_bonus_component(target, NONPLAYER_TRAIT_BONUS_PER_KEY)
  local spt_str = get_nonplayer_bonus_component(target, NONPLAYER_STAT_BONUS_STR_KEY)
  local spt_dex = get_nonplayer_bonus_component(target, NONPLAYER_STAT_BONUS_DEX_KEY)
  local spt_int = get_nonplayer_bonus_component(target, NONPLAYER_STAT_BONUS_INT_KEY)
  local spt_per = get_nonplayer_bonus_component(target, NONPLAYER_STAT_BONUS_PER_KEY)
  local total_stat_pts = get_nonplayer_bonus_component(target, NONPLAYER_STAT_POINTS_KEY)

  local class_total_str = math.floor(cls_str * (cls_str < 0 and np_scalars.class_penalty or np_scalars.class_benefit) * target_level)
  local class_total_dex = math.floor(cls_dex * (cls_dex < 0 and np_scalars.class_penalty or np_scalars.class_benefit) * target_level)
  local class_total_int = math.floor(cls_int * (cls_int < 0 and np_scalars.class_penalty or np_scalars.class_benefit) * target_level)
  local class_total_per = math.floor(cls_per * (cls_per < 0 and np_scalars.class_penalty or np_scalars.class_benefit) * target_level)

  -- Class display
  local class_key = target:get_value(NONPLAYER_CLASS_KEY)
  local class_display = gettext("[None]")
  local class_desc = nil
  if class_key ~= "" then
    local class_mut = MUTATIONS[class_key]
    if class_mut then
      local class_obj = class_mut:get_mutation_id():obj()
      class_display = class_obj:name()
      class_desc = strip_scaling_block(class_obj:desc())
    else
      class_display = class_key
    end
  end

  -- Trait display
  local trait_ids = parse_nonplayer_trait_ids(target:get_value(NONPLAYER_TRAITS_KEY))
  local max_trait_slots = tonumber(target:get_value(NONPLAYER_MAX_TRAITS_KEY)) or (1 + math.floor(target_level / np_scalars.levels_per_trait_slot))

  local ui = UiList.new()
  ui:title(gettext("=== [Analysis Lens] ==="))

  local text = ""

  -- Header: name, type, level
  text = text .. color_highlight(gettext("Name:")) .. " " .. color_good(target:get_name())
  text = text .. "   " .. color_highlight(gettext("Type:")) .. " " .. color_info(format_creature_kind(target)) .. "\n"
  text = text .. color_highlight(gettext("Level:")) .. " " .. color_good(target_level)
  if target_level < 40 then
    text = text .. color_text(string.format(" (Next: %.0f XP)", target_xp_to_next), "light_gray")
  else
    text = text .. " " .. color_warning(gettext("[MAX]"))
  end
  text = text .. "\n"

  if target_level < 40 then
    local current_level_xp = rpg_xp_needed(target_level)
    local next_level_xp = rpg_xp_needed(target_level + 1)
    local xp_in_level = math.max(0, target_exp - current_level_xp)
    local xp_for_level = math.max(1, next_level_xp - current_level_xp)
    text = text .. "XP: " .. create_progress_bar(xp_in_level, xp_for_level, 30) .. "\n"
  end
  text = text .. color_highlight(gettext("Total XP:")) .. " " .. color_text(string.format("%.0f", target_exp), "light_gray") .. "\n"
  text = text .. color_text("─────────────────────────────────────────", "light_gray") .. "\n"

  -- Stats
  text = text .. color_highlight(gettext("Stats:")) .. "\n"
  text = text .. string.format(
    "  %s %s  %s %s  %s %s  %s %s\n",
    color_text("STR:", "light_gray"), color_good(effective.STR),
    color_text("DEX:", "light_gray"), color_good(effective.DEX),
    color_text("INT:", "light_gray"), color_good(effective.INT),
    color_text("PER:", "light_gray"), color_good(effective.PER)
  )

  -- Bonus breakdown (critters have virtual derived stats — show the breakdown)
  local function signed_stat_text(label, value)
    local sign = value >= 0 and "+" or ""
    return string.format("%s %s%s", label, sign, format_decimal(value))
  end

  if target:is_monster() then
    if cls_str ~= 0 or cls_dex ~= 0 or cls_int ~= 0 or cls_per ~= 0 then
      local parts = {}
      if cls_str ~= 0 then parts[#parts+1] = signed_stat_text("STR", cls_str) end
      if cls_dex ~= 0 then parts[#parts+1] = signed_stat_text("DEX", cls_dex) end
      if cls_int ~= 0 then parts[#parts+1] = signed_stat_text("INT", cls_int) end
      if cls_per ~= 0 then parts[#parts+1] = signed_stat_text("PER", cls_per) end
      text = text .. color_text("  Class Bonuses / Level: ", "light_gray") .. color_info(table.concat(parts, "  ")) .. "\n"
    end
    if class_total_str ~= 0 or class_total_dex ~= 0 or class_total_int ~= 0 or class_total_per ~= 0 then
      local parts = {}
      if class_total_str ~= 0 then parts[#parts+1] = signed_stat_text("STR", class_total_str) end
      if class_total_dex ~= 0 then parts[#parts+1] = signed_stat_text("DEX", class_total_dex) end
      if class_total_int ~= 0 then parts[#parts+1] = signed_stat_text("INT", class_total_int) end
      if class_total_per ~= 0 then parts[#parts+1] = signed_stat_text("PER", class_total_per) end
      text = text .. color_text(string.format("  Class Total @ L%.0f: ", target_level), "light_gray") .. color_info(table.concat(parts, "  ")) .. "\n"
    end
    if trt_str ~= 0 or trt_dex ~= 0 or trt_int ~= 0 or trt_per ~= 0 then
      local parts = {}
      if trt_str ~= 0 then parts[#parts+1] = signed_stat_text("STR", trt_str) end
      if trt_dex ~= 0 then parts[#parts+1] = signed_stat_text("DEX", trt_dex) end
      if trt_int ~= 0 then parts[#parts+1] = signed_stat_text("INT", trt_int) end
      if trt_per ~= 0 then parts[#parts+1] = signed_stat_text("PER", trt_per) end
      text = text .. color_text("  Trait Bonuses: ", "light_gray") .. color_good(table.concat(parts, "  ")) .. "\n"
    end
  end
  if spt_str ~= 0 or spt_dex ~= 0 or spt_int ~= 0 or spt_per ~= 0 then
    local parts = {}
    if spt_str ~= 0 then parts[#parts+1] = signed_stat_text("STR", spt_str) end
    if spt_dex ~= 0 then parts[#parts+1] = signed_stat_text("DEX", spt_dex) end
    if spt_int ~= 0 then parts[#parts+1] = signed_stat_text("INT", spt_int) end
    if spt_per ~= 0 then parts[#parts+1] = signed_stat_text("PER", spt_per) end
    text = text .. color_text(string.format("  Level-up Points (%.0f total): ", total_stat_pts), "light_gray")
    text = text .. color_warning(table.concat(parts, "  ")) .. "\n"
  elseif total_stat_pts > 0 then
    text = text .. color_text(string.format("  Level-up Points: %.0f (distributed)", total_stat_pts), "light_gray") .. "\n"
  end

  text = text .. color_text("─────────────────────────────────────────", "light_gray") .. "\n"

  -- Class
  if class_display == gettext("[None]") then
    text = text .. color_highlight(gettext("Class:")) .. " " .. color_warning(gettext("[None]")) .. "\n"
  else
    text = text .. color_highlight(gettext("Class:")) .. " " .. color_good(class_display) .. "\n"
    if class_desc and class_desc ~= "" then
      text = text .. color_text(wrap_text(class_desc, 58, "  "), "light_gray") .. "\n"
    end
  end
  text = text .. color_text("─────────────────────────────────────────", "light_gray") .. "\n"

  -- Traits
  text = text .. color_highlight(gettext("Trait Slots:")) .. " "
    .. color_good(tostring(#trait_ids)) .. color_text("/", "light_gray") .. color_highlight(tostring(max_trait_slots)) .. "\n"
  if #trait_ids > 0 then
    text = text .. color_highlight(gettext("Active Traits:")) .. "\n"
    for _, tid in ipairs(trait_ids) do
      local tmut = MUTATIONS[tid]
      local tname = tid
      local tdesc = nil
      if tmut then
        tname = tmut:get_mutation_id():obj():name()
        tdesc = strip_scaling_block(tmut:get_mutation_id():obj():desc())
      end
      text = text .. color_good("  • " .. tname) .. "\n"
      if tdesc and tdesc ~= "" then
        text = text .. color_text(wrap_text(tdesc, 56, "    "), "light_gray") .. "\n"
      end
    end
  else
    text = text .. color_text(gettext("  No traits selected yet."), "dark_gray") .. "\n"
  end
  text = text .. color_text("─────────────────────────────────────────", "light_gray") .. "\n"

  -- Combat stats
  local shown_speed = target:get_speed() or 100
  if not target:is_avatar() then
    shown_speed = get_nonplayer_effective_speed(target, viewer, target_level)
  end
  text = text .. color_highlight(gettext("Combat:")) .. "\n"
  text = text .. string.format("  %s %d/%d   %s %d   %s %.1f   %s %.1f\n",
    color_text("HP:", "light_gray"), target:get_hp(), target:get_hp_max(),
    color_text("Speed:", "light_gray"), shown_speed,
    color_text("Melee:", "light_gray"), target:get_melee(),
    color_text("Dodge:", "light_gray"), target:get_dodge())
  text = text .. string.format("  %s %.2f\n",
    color_text("Power Rating:", "light_gray"), target:power_rating())
  text = text .. color_text("─────────────────────────────────────────", "light_gray") .. "\n"

  text = text .. color_highlight(gettext("Predicted XP on Kill:")) .. " " .. color_good(predicted_xp) .. "\n"

  ui:text(text)
  ui:add(1, color_text(gettext("← Close"), "light_gray"))
  ui:query()
end

get_char_value = function(char, key, default)
  local val = char:get_value(key)
  if val == "" then return default end
  return tonumber(val) or default
end

local function set_char_value(char, key, value) char:set_value(key, tostring(value)) end

get_scalar_value = function(char, key)
  local default = SCALAR_DEFAULTS[key] or 1.0
  return get_char_value(char, key, default)
end

local function ensure_scalar_value(char, key)
  local normalized = get_scalar_value(char, key)
  set_char_value(char, key, normalized)
  return normalized
end

format_decimal = function(value)
  return string.format("%.3f", value)
end

local function is_core_stat_label(label)
  return label == "STR" or label == "DEX" or label == "INT" or label == "PER"
end

local function get_effect_mode(label)
  if COST_LIKE_LABELS[label] then
    return "cost"
  end
  if MULTIPLIER_LABELS[label] then
    return "multiplier"
  end
  return "additive"
end

local function get_effect_scalar_kind(label, value, scalar_kind)
  local effect_mode = get_effect_mode(label)
  if effect_mode == "cost" then
    return value < 1 and "benefit" or "penalty"
  end
  if effect_mode == "multiplier" then
    return value < 1 and "penalty" or "benefit"
  end
  if label == "Metabolism" then
    return value > 0 and "penalty" or "benefit"
  end
  return scalar_kind
end

local function uses_level_scaling(mutation_type, label)
  if mutation_type == "trait" then
    return true
  end
  return is_core_stat_label(label)
end

local function get_mutation_unlock_level(mutation)
  if not mutation or not mutation.requirements or not mutation.requirements.level then
    return 1
  end
  return math.max(1, mutation.requirements.level)
end

local function get_level_factor_for_effect(mutation_type, level, scalars, apply_level_scaling, unlock_level)
  if not apply_level_scaling then
    return 1.0
  end
  local scaled_levels = math.max(level - unlock_level, 0)
  if mutation_type == "class" then
    return 1 + scaled_levels
  end
  return 1 + scaled_levels * TRAIT_LEVEL_STEP * scalars.trait_level_scalar
end

local function get_adjusted_level_factor(mutation_type, label, level, scalars, scalar_kind, unlock_level)
  local base_factor = get_level_factor_for_effect(mutation_type, level, scalars, uses_level_scaling(mutation_type, label), unlock_level)
  local growth = base_factor - 1.0
  local cap = math.max(0.0, scalars.effect_growth_cap or 0.30)

  if growth > cap then
    growth = cap
  elseif growth < -cap then
    growth = -cap
  end

  return 1.0 + growth
end

local function clamp_relative_effect_value(label, value)
  if label == "Scent" then
    return math.max(0.0, value)
  end
  if label == "Fall Damage" then
    return math.max(0.0, math.min(value, 1.0))
  end
  return value
end

local function get_relative_effect_value(effect_mode, scalar_kind, value, scalar_value, level_factor)
  local distance_from_neutral = math.abs(value - 1.0)
  local scaled_distance = distance_from_neutral * scalar_value * level_factor

  if effect_mode == "cost" then
    if scalar_kind == "benefit" then
      return 1.0 - scaled_distance, distance_from_neutral, "-"
    end
    return 1.0 + scaled_distance, distance_from_neutral, "+"
  end

  if scalar_kind == "benefit" then
    return 1.0 + scaled_distance, distance_from_neutral, "+"
  end
  return 1.0 - scaled_distance, distance_from_neutral, "-"
end

local function get_relative_expression(value)
  if value >= 1.0 then
    return string.format("(%s - 1.000)", format_decimal(value))
  end
  return string.format("(1.000 - %s)", format_decimal(value))
end

--- Build a single formula display line.
--- mode == "compact": "LABEL: orig => final"  (for @ mutations tab)
--- mode == "detailed": "LABEL: orig => calculation = final"  (for System menu)
local function build_formula_line(mutation, label, value, scalar_kind, level, scalars, mode)
  local mutation_type = mutation.type
  local resolved_scalar_kind = get_effect_scalar_kind(label, value, scalar_kind)
  local effect_mode = get_effect_mode(label)
  local apply_level_scaling = uses_level_scaling(mutation_type, label)
  local unlock_level = get_mutation_unlock_level(mutation)
  local is_class_core = (mutation_type == "class") and is_core_stat_label(label)
  local scalar_value = mutation_type == "class"
    and (resolved_scalar_kind == "penalty" and scalars.class_penalty or scalars.class_benefit)
    or (resolved_scalar_kind == "penalty" and scalars.trait_penalty or scalars.trait_benefit)

  local orig_str = format_decimal(value)
  local final_value, formula_str

  if is_class_core then
    -- STR/DEX/INT/PER for class mutations: direct linear scaling (base * scalar * level)
    local is_penalty = value < 0
    local sc = is_penalty and scalars.class_penalty or scalars.class_benefit
    final_value = math.floor(value * sc * level)
    formula_str = string.format("%s * %s * %d", format_decimal(value), format_decimal(sc), level)
  elseif effect_mode ~= "additive" then
    local level_factor = get_adjusted_level_factor(mutation_type, label, level, scalars, resolved_scalar_kind, unlock_level)
    local fv, distance_from_neutral, direction = get_relative_effect_value(
      effect_mode, resolved_scalar_kind, value, scalar_value, level_factor
    )
    final_value = clamp_relative_effect_value(label, fv)
    local relative_expr = get_relative_expression(value)
    local scalar_expr = string.format("%s * %s", format_decimal(distance_from_neutral), format_decimal(scalar_value))
    if apply_level_scaling then
      scalar_expr = scalar_expr .. " * " .. format_decimal(level_factor)
    end
    formula_str = string.format("1.000 %s (%s * %s)", direction, relative_expr, scalar_expr)
  else
    local level_factor = get_adjusted_level_factor(mutation_type, label, level, scalars, resolved_scalar_kind, unlock_level)
    local scaled_value = value * scalar_value
    if apply_level_scaling then
      final_value = scaled_value * level_factor
    else
      final_value = scaled_value
    end
    formula_str = string.format("%s * %s", format_decimal(value), format_decimal(scalar_value))
    if apply_level_scaling then
      formula_str = formula_str .. " * " .. format_decimal(level_factor)
    end
  end

  if mode == "compact" then
    return string.format("%s: %s => %s", label, orig_str, format_decimal(final_value))
  end
  return string.format("%s: %s => %s = %s", label, orig_str, formula_str, format_decimal(final_value))
end

strip_scaling_block = function(text)
  if not text then return "" end
  local marker = text:find("\n\n[Scaling]", 1, true)
  if marker then
    return text:sub(1, marker - 1)
  end
  return text
end

local function get_base_mutation_description(mutation)
  return strip_scaling_block(mutation:get_mutation_id():obj():desc())
end

local function add_formula_line(lines, level, scalars, mutation, label, value, scalar_kind, mode)
  table.insert(lines, build_formula_line(mutation, label, value, scalar_kind, level, scalars, mode))
end

local function add_stat_formula_lines(lines, level, scalars, mutation, mode)
  local bonuses = mutation.stat_bonuses
  if bonuses.str then add_formula_line(lines, level, scalars, mutation, "STR", bonuses.str, bonuses.str < 0 and "penalty" or "benefit", mode) end
  if bonuses.dex then add_formula_line(lines, level, scalars, mutation, "DEX", bonuses.dex, bonuses.dex < 0 and "penalty" or "benefit", mode) end
  if bonuses.int then add_formula_line(lines, level, scalars, mutation, "INT", bonuses.int, bonuses.int < 0 and "penalty" or "benefit", mode) end
  if bonuses.per then add_formula_line(lines, level, scalars, mutation, "PER", bonuses.per, bonuses.per < 0 and "penalty" or "benefit", mode) end
  if bonuses.speed then add_formula_line(lines, level, scalars, mutation, "Speed Bonus", bonuses.speed, bonuses.speed < 0 and "penalty" or "benefit", mode) end
end

local function add_periodic_formula_lines(lines, level, scalars, mutation, mode)
  local bonuses = mutation.periodic_bonuses
  if bonuses.fatigue then add_formula_line(lines, level, scalars, mutation, "Fatigue", bonuses.fatigue, bonuses.fatigue > 0 and "penalty" or "benefit", mode) end
  if bonuses.stamina then add_formula_line(lines, level, scalars, mutation, "Stamina", bonuses.stamina, bonuses.stamina < 0 and "penalty" or "benefit", mode) end
  if bonuses.thirst then add_formula_line(lines, level, scalars, mutation, "Thirst", bonuses.thirst, bonuses.thirst > 0 and "penalty" or "benefit", mode) end
  if bonuses.rad then add_formula_line(lines, level, scalars, mutation, "Radiation", bonuses.rad, bonuses.rad > 0 and "penalty" or "benefit", mode) end
  if bonuses.healthy_mod then add_formula_line(lines, level, scalars, mutation, "Health", bonuses.healthy_mod, bonuses.healthy_mod < 0 and "penalty" or "benefit", mode) end
  if bonuses.power_level then add_formula_line(lines, level, scalars, mutation, "Power", bonuses.power_level, bonuses.power_level < 0 and "penalty" or "benefit", mode) end
  if bonuses.morale then add_formula_line(lines, level, scalars, mutation, "Morale", bonuses.morale, bonuses.morale < 0 and "penalty" or "benefit", mode) end
end

local function add_kill_formula_lines(lines, level, scalars, mutation, mode)
  local bonuses = mutation.kill_monster_bonuses
  if bonuses.heal_percent then
    add_formula_line(lines, level, scalars, mutation, "Heal On Kill", bonuses.heal_percent, bonuses.heal_percent < 0 and "penalty" or "benefit", mode)
  end
end

local function build_formula_text(player, mutation, mode)
  local lines = {}
  local level = get_char_value(player, "rpg_level", 0)
  local scalars = get_scalars(player)

  add_stat_formula_lines(lines, level, scalars, mutation, mode)
  add_periodic_formula_lines(lines, level, scalars, mutation, mode)
  add_kill_formula_lines(lines, level, scalars, mutation, mode)

  local extra_effects = EXTRA_EFFECTS[mutation.id]
  if extra_effects then
    for _, effect in ipairs(extra_effects) do
      add_formula_line(lines, level, scalars, mutation, effect.label, effect.value, effect.scalar, mode)
    end
  end

  local sep = mode == "compact" and "; " or "\n"
  return table.concat(lines, sep)
end

local function get_mutation_description(mutation, player, include_formula, mode)
  local base_desc = get_base_mutation_description(mutation)
  if not include_formula or not player then
    return base_desc
  end

  local formula_mode = mode or "detailed"
  local formula_text = build_formula_text(player, mutation, formula_mode)
  if formula_text == "" then
    return base_desc
  end
  if base_desc == "" then
    return formula_text
  end
  return base_desc .. "\n\n" .. formula_text
end

local function prompt_scalar_value(options)
  local input = PopupInputStr.new()
  input:title(options.title)
  input:desc(options.desc .. "\nCurrent: " .. format_decimal(options.current))

  local raw_value = input:query_str()
  if raw_value == "" then
    return nil
  end

  local numeric_value = tonumber(raw_value)
  if not numeric_value then
    gapi.add_msg(MsgType.warning, color_warning(gettext("Enter a valid number.")))
    return nil
  end

  if numeric_value < options.minimum then
    gapi.add_msg(MsgType.warning, color_warning(string.format(gettext("Value must be at least %.3f."), options.minimum)))
    return nil
  end

  return numeric_value
end

local function update_level_rewards(player, old_level, new_level)
  if old_level == new_level then
    return
  end

  local stat_points = get_char_value(player, "rpg_stat_points", 0)
  local max_traits = get_char_value(player, "rpg_max_traits", 1)

  if new_level > old_level then
    for current_level = old_level + 1, new_level do
      if current_level % LEVELS_PER_STAT_POINT == 0 then
        stat_points = stat_points + 1
      end
      if current_level % LEVELS_PER_TRAIT_SLOT == 0 then
        max_traits = max_traits + 1
      end
    end
  else
    for current_level = old_level, new_level + 1, -1 do
      if current_level % LEVELS_PER_STAT_POINT == 0 then
        stat_points = math.max(0, stat_points - 1)
      end
      if current_level % LEVELS_PER_TRAIT_SLOT == 0 then
        max_traits = math.max(1, max_traits - 1)
      end
    end
    -- Reset XP to the start of new_level so no excess XP remains
    local new_exp = math.floor(rpg_xp_needed(new_level))
    set_char_value(player, "rpg_exp", new_exp)
  end

  set_char_value(player, "rpg_level", new_level)
  set_char_value(player, "rpg_stat_points", stat_points)
  set_char_value(player, "rpg_max_traits", max_traits)
  set_char_value(player, "rpg_xp_to_next_level", math.max(0, rpg_xp_needed(math.min(new_level + 1, 40)) - get_char_value(player, "rpg_exp", 0)))
end

local function apply_level_effects(player)
  if not player then return end

  local delta = 0
  if player:has_effect(EffectTypeId.new("level_upper")) then
    delta = delta + 1
  end
  if player:has_effect(EffectTypeId.new("level_downer")) then
    delta = delta - 1
  end
  if delta == 0 then return end

  local old_level = get_char_value(player, "rpg_level", 0)
  local new_level = math.max(0, math.min(40, old_level + delta))
  if new_level == old_level then return end

  update_level_rewards(player, old_level, new_level)
  player:reset()
end

local function is_mod_active(mod_id)
  if not game.active_mods then return false end
  for _, active_mod in pairs(game.active_mods) do
    if tostring(active_mod) == mod_id then
      return true
    end
  end
  return false
end

local function has_magical_nights()
  return is_mod_active("MagicalNights")
end

local function is_obsolete_trait_id(trait_id)
  if FORCED_OBSOLETE_TRAIT_IDS[trait_id] then
    return true
  end
  if MUTATIONS[trait_id] ~= nil then
    return false
  end
  for _, legacy_id in ipairs(LEGACY_TRAIT_IDS) do
    if legacy_id == trait_id then
      return true
    end
  end
  return false
end

--- Returns true if the character has the mutation directly or via its MagicalNights variant.
local function player_has_mod_mutation(character, mutation_id)
  if character:has_trait(mutation_id) then return true end
  local variant = MN_TRAIT_VARIANTS[mutation_id:str()] or MN_CLASS_VARIANTS[mutation_id:str()]
  return variant ~= nil and character:has_trait(MutationBranchId.new(variant))
end

local function reapply_active_mutations(player)
  local active_class_strs = {}
  local active_trait_strs = {}

  for _, class_id in ipairs(ALL_CLASS_IDS) do
    local s = class_id:str()
    local variant = MN_CLASS_VARIANTS[s]
    if player:has_trait(class_id) or (variant ~= nil and player:has_trait(MutationBranchId.new(variant))) then
      table.insert(active_class_strs, s)
    end
  end

  for _, trait_id in ipairs(ALL_TRAIT_IDS) do
    local s = trait_id:str()
    local variant = MN_TRAIT_VARIANTS[s]
    if player:has_trait(trait_id) or (variant ~= nil and player:has_trait(MutationBranchId.new(variant))) then
      table.insert(active_trait_strs, s)
    end
  end

  for _, s in ipairs(active_class_strs) do
    player:remove_mutation(MutationBranchId.new(s), true)
    local variant = MN_CLASS_VARIANTS[s]
    if variant then player:remove_mutation(MutationBranchId.new(variant), true) end
  end

  for _, s in ipairs(active_trait_strs) do
    player:remove_mutation(MutationBranchId.new(s), true)
    local variant = MN_TRAIT_VARIANTS[s]
    if variant then player:remove_mutation(MutationBranchId.new(variant), true) end
  end

  local mn = has_magical_nights()
  for _, s in ipairs(active_class_strs) do
    local apply_id = (mn and MN_CLASS_VARIANTS[s]) or s
    player:set_mutation(MutationBranchId.new(apply_id))
  end

  for _, s in ipairs(active_trait_strs) do
    local apply_id = (mn and MN_TRAIT_VARIANTS[s]) or s
    player:set_mutation(MutationBranchId.new(apply_id))
  end
end

local function remove_obsolete_traits_and_refund(player)
  local removed_count = 0
  for _, legacy_id in ipairs(LEGACY_TRAIT_IDS) do
    if is_obsolete_trait_id(legacy_id) then
      local trait_id = MutationBranchId.new(legacy_id)
      if player:has_trait(trait_id) then
        player:remove_mutation(trait_id, true)
        removed_count = removed_count + 1
      end
    end
  end

  if removed_count > 0 then
    local current_traits = get_char_value(player, "rpg_num_traits", 0)
    set_char_value(player, "rpg_num_traits", math.max(0, current_traits - removed_count))
    gapi.add_msg(
      MsgType.info,
      color_info(
        string.format(
          vgettext(
            "Removed %d obsolete RPG trait and refunded one trait slot.",
            "Removed %d obsolete RPG traits and refunded trait slots.",
            removed_count
          ),
          removed_count
        )
      )
    )
  end
end

function get_scalars(player)
  return {
    class_benefit = get_scalar_value(player, "rpg_class_benefit_scalar"),
    class_penalty = get_scalar_value(player, "rpg_class_penalty_scalar"),
    trait_benefit = get_scalar_value(player, "rpg_trait_benefit_scalar"),
    trait_penalty = get_scalar_value(player, "rpg_trait_penalty_scalar"),
    trait_level_scalar = get_scalar_value(player, "rpg_trait_level_scalar"),
    xp_multiplier = get_scalar_value(player, "rpg_xp_multiplier"),
    effect_growth_cap = get_scalar_value(player, "rpg_effect_growth_cap"),
    nonplayer_passive_xp = get_scalar_value(player, "rpg_nonplayer_passive_xp_scalar"),
    nonplayer_kill_xp = get_scalar_value(player, "rpg_nonplayer_kill_xp_scalar"),
    nonplayer_min_level = get_scalar_value(player, "rpg_nonplayer_min_level"),
    nonplayer_max_level = get_scalar_value(player, "rpg_nonplayer_max_level"),
    nonplayer_class_benefit = get_scalar_value(player, "rpg_nonplayer_class_benefit_scalar"),
    nonplayer_class_penalty = get_scalar_value(player, "rpg_nonplayer_class_penalty_scalar"),
    nonplayer_trait_benefit = get_scalar_value(player, "rpg_nonplayer_trait_benefit_scalar"),
    nonplayer_trait_penalty = get_scalar_value(player, "rpg_nonplayer_trait_penalty_scalar"),
    nonplayer_xp_multiplier = get_scalar_value(player, "rpg_nonplayer_xp_multiplier"),
    nonplayer_trait_level_scalar = get_scalar_value(player, "rpg_nonplayer_trait_level_scalar"),
    nonplayer_effect_growth_cap = get_scalar_value(player, "rpg_nonplayer_effect_growth_cap"),
    nonplayer_background_rate = get_scalar_value(player, "rpg_nonplayer_background_rate"),
    nonplayer_spawn_level_chance = get_scalar_value(player, "rpg_nonplayer_spawn_level_chance_scalar"),
    nonplayer_speed_per_level_bonus = get_scalar_value(player, "rpg_nonplayer_speed_per_level_bonus"),
    nonplayer_levels_per_stat_point = get_scalar_value(player, "rpg_nonplayer_levels_per_stat_point"),
    nonplayer_levels_per_trait_slot = get_scalar_value(player, "rpg_nonplayer_levels_per_trait_slot"),
  }
end

--- Returns non-player scalars in a player-like layout (reusable with formula helpers).
function get_nonplayer_scalars(player)
  local all = get_scalars(player)
  return {
    class_benefit = all.nonplayer_class_benefit,
    class_penalty = all.nonplayer_class_penalty,
    trait_benefit = all.nonplayer_trait_benefit,
    trait_penalty = all.nonplayer_trait_penalty,
    xp_multiplier = all.nonplayer_xp_multiplier,
    trait_level_scalar = all.nonplayer_trait_level_scalar,
    effect_growth_cap = all.nonplayer_effect_growth_cap,
    background_rate = all.nonplayer_background_rate,
    spawn_level_chance = all.nonplayer_spawn_level_chance,
    speed_per_level_bonus = all.nonplayer_speed_per_level_bonus,
    levels_per_stat_point = math.max(1, math.floor(all.nonplayer_levels_per_stat_point)),
    levels_per_trait_slot = math.max(1, math.floor(all.nonplayer_levels_per_trait_slot)),
  }
end

--- Distributes level-up stat points to the creature's focus stat.
function apply_nonplayer_stat_points(creature, player, old_level, new_level)
  if old_level >= new_level then return end
  local np = get_nonplayer_scalars(player)
  local lv_per_pt = np.levels_per_stat_point
  local new_points = 0
  for lv = old_level + 1, new_level do
    if lv % lv_per_pt == 0 then
      new_points = new_points + 1
    end
  end
  if new_points <= 0 then return end

  local stats = get_nonplayer_effective_stats(creature)
  local focus = get_focus_stat(stats)
  local focus_key_map = {
    STR = NONPLAYER_STAT_BONUS_STR_KEY,
    DEX = NONPLAYER_STAT_BONUS_DEX_KEY,
    INT = NONPLAYER_STAT_BONUS_INT_KEY,
    PER = NONPLAYER_STAT_BONUS_PER_KEY,
  }
  local bonus_key = focus_key_map[focus]
  local current_bonus = get_nonplayer_bonus_component(creature, bonus_key)
  creature:set_value(bonus_key, tostring(current_bonus + new_points))
  local total_pts = get_nonplayer_bonus_component(creature, NONPLAYER_STAT_POINTS_KEY)
  creature:set_value(NONPLAYER_STAT_POINTS_KEY, tostring(total_pts + new_points))
end

local function scale_for_type(value, mutation_type, is_penalty, scalars)
  if mutation_type == "class" then
    return value * (is_penalty and scalars.class_penalty or scalars.class_benefit)
  end
  return value * (is_penalty and scalars.trait_penalty or scalars.trait_benefit)
end

local function level_factor_for_mutation(mutation, label, level, scalars, is_penalty)
  local scalar_kind = is_penalty and "penalty" or "benefit"
  local unlock_level = get_mutation_unlock_level(mutation)
  return get_adjusted_level_factor(mutation.type, label, level, scalars, scalar_kind, unlock_level)
end

local function dynamic_mutation_desc_key(mutation_id)
  return "rpg_mutation_desc_" .. mutation_id
end

local function cache_dynamic_mutation_descriptions(player)
  if not player then return end

  local all_ids = {}
  for _, class_id in ipairs(ALL_CLASS_IDS) do
    table.insert(all_ids, class_id)
  end
  for _, trait_id in ipairs(ALL_TRAIT_IDS) do
    table.insert(all_ids, trait_id)
  end

  for _, mutation_id in ipairs(all_ids) do
    local id_str = mutation_id:str()
    local mutation = MUTATIONS[id_str]
    local has_mutation = player_has_mod_mutation(player, mutation_id)
    local desc = ""

    if mutation and has_mutation then
      desc = get_mutation_description(mutation, player, true, "compact")
    end

    player:set_value(dynamic_mutation_desc_key(id_str), desc)

    local variant = MN_CLASS_VARIANTS[id_str] or MN_TRAIT_VARIANTS[id_str]
    if variant then
      player:set_value(dynamic_mutation_desc_key(variant), desc)
    end
  end
end

--- Rebuild all active RPG mutations from current mod data.
--- This ensures edited mutation json/lua values are reapplied on start/load.
local function reevaluate_all_mutations(player)
  if not player then return end
  remove_obsolete_traits_and_refund(player)
  reapply_active_mutations(player)
  player:reset()
  cache_dynamic_mutation_descriptions(player)
end

-- Common requirement checking and formatting
local function check_requirements(player, mutation, current_level)
  local reqs = mutation.requirements
  if not reqs or (not reqs.level and not reqs.stats and not reqs.skills) then return true, {}, {} end

  local unmet = {}
  local all_reqs = {}

  -- Check level requirement
  if reqs.level then
    local met = current_level >= reqs.level
    local req_info = { type = "level", label = "Lv", current = current_level, required = reqs.level, met = met }
    table.insert(all_reqs, req_info)
    if not met then
      table.insert(unmet, req_info)
    end
  end

  -- Check stat requirements
  if reqs.stats then
    local stats_map = {
      STR = player:get_str(),
      DEX = player:get_dex(),
      INT = player:get_int(),
      PER = player:get_per(),
    }
    for stat, required in pairs(reqs.stats) do
      local current = stats_map[stat]
      local met = current >= required
      local req_info = { type = "stat", label = stat, current = current, required = required, met = met }
      table.insert(all_reqs, req_info)
      if not met then
        table.insert(unmet, req_info)
      end
    end
  end

  -- Check skill requirements
  if reqs.skills then
    for skill_name, required in pairs(reqs.skills) do
      if skill_name == "spellcraft" and not has_magical_nights() then
        local req_info = { type = "skill", label = "Spellcraft", current = required, required = required, met = true }
        table.insert(all_reqs, req_info)
      else
      local current = player:get_skill_level(SkillId.new(skill_name))
      local met = current >= required
      local display_name = skill_name:gsub("^%l", string.upper)
      local req_info = { type = "skill", label = display_name, current = current, required = required, met = met }
      table.insert(all_reqs, req_info)
      if not met then
        table.insert(unmet, req_info)
      end
      end
    end
  end

  return #unmet == 0, unmet, all_reqs
end

local function format_requirement(label, current, required, show_current, met)
  local color_fn = met and color_good or color_bad
  if show_current then
    return color_fn(string.format("%s %d/%d", label, current, required))
  else
    return color_fn(string.format("%s %d+", label, required))
  end
end

local function format_requirements_list(all_reqs, show_current)
  local parts = {}
  for _, req in ipairs(all_reqs) do
    table.insert(parts, format_requirement(req.label, req.current, req.required, show_current, req.met))
  end
  return table.concat(parts, ", ")
end

local function has_class(char)
  for _, class_id in ipairs(ALL_CLASS_IDS) do
    if char:has_trait(class_id) then return true end
  end
  return false
end

local function get_class_info(char)
  for _, class_id in ipairs(ALL_CLASS_IDS) do
    if char:has_trait(class_id) then
      local mutation = MUTATIONS[class_id:str()]
      return class_id:obj():name(), mutation and get_mutation_description(mutation, char, false) or strip_scaling_block(class_id:obj():desc())
    end
  end
  return "[None]", nil
end

local function get_current_traits(char)
  local current = {}
  for _, trait_id in ipairs(ALL_TRAIT_IDS) do
    if char:has_trait(trait_id) then
      local mutation = MUTATIONS[trait_id:str()]
      table.insert(current, { name = trait_id:obj():name(), desc = mutation and get_mutation_description(mutation, char, false) or strip_scaling_block(trait_id:obj():desc()) })
    end
  end
  return current
end

local function get_elapsed_turns()
  return (gapi.current_turn() - gapi.turn_zero()):to_turns()
end

local function get_class_name_by_key(class_key)
  local mutation = MUTATIONS[class_key]
  if not mutation then return class_key end
  local class_obj = mutation:get_mutation_id():obj()
  return class_obj:name()
end

local function build_class_tree_text()
  local class_keys = {}
  local children_by_parent = {}

  for key, mutation in pairs(MUTATIONS) do
    if mutation.type == "class" then
      class_keys[#class_keys + 1] = key
      if mutation.base_class and MUTATIONS[mutation.base_class] and MUTATIONS[mutation.base_class].type == "class" then
        children_by_parent[mutation.base_class] = children_by_parent[mutation.base_class] or {}
        children_by_parent[mutation.base_class][#children_by_parent[mutation.base_class] + 1] = key
      end
    end
  end

  table.sort(class_keys)
  for _, children in pairs(children_by_parent) do
    table.sort(children)
  end

  local roots = {}
  for _, key in ipairs(class_keys) do
    local base_key = MUTATIONS[key].base_class
    if not base_key or not MUTATIONS[base_key] or MUTATIONS[base_key].type ~= "class" then
      roots[#roots + 1] = key
    end
  end

  table.sort(roots)

  local lines = {}

  local function walk(class_key, tier)
    local indent = string.rep("  ", tier - 1)
    lines[#lines + 1] = indent .. "- " .. get_class_name_by_key(class_key) .. string.format(" (Tier %d)", tier)
    local children = children_by_parent[class_key] or {}
    for _, child_key in ipairs(children) do
      walk(child_key, tier + 1)
    end
  end

  for _, root in ipairs(roots) do
    walk(root, 1)
  end

  if #lines == 0 then
    return gettext("No classes are currently registered.")
  end

  return table.concat(lines, "\n")
end

mod.register_system_keybind = function()
  -- Always re-register on game start/load since action menu entries don't persist

  local function open_system_from_action()
    local avatar = gapi.get_avatar()
    if not avatar then return end
    local integrated = get_char_value(avatar, "rpg_system_integrated", 0)
    if integrated ~= 1 then
      gapi.add_msg(MsgType.info, color_info(gettext("Use the [System Interface] item first to integrate the [System].")))
      return
    end
    mod.open_rpg_menu({ user = avatar, item = nil, pos = nil })
  end

  local ok = false

  -- Register through the keybind-aware action-menu API when available.
  if gapi.register_action_menu_action then
    ok = pcall(function()
      gapi.register_action_menu_action({
        id = "rpg_system:misc_open_menu",
        name = "Open [System] Menu",
        category = "misc",
        hotkey = DEFAULT_SYSTEM_MENU_KEY,
        fn = open_system_from_action,
      })
    end)
  elseif gapi.register_action_menu_entry then
    ok = pcall(function()
      gapi.register_action_menu_entry({
        id = "rpg_system:misc_open_menu",
        name = "Open [System] Menu",
        category = "misc",
        hotkey = DEFAULT_SYSTEM_MENU_KEY,
        fn = open_system_from_action,
      })
    end)
  end

  -- Compatibility fallback for builds that don't expose the new API yet.
  if (not ok) and game.register_action then
    ok = pcall(function()
      game.register_action("RPG_SYSTEM_OPEN_MENU", "Open [System] Menu", open_system_from_action, DEFAULT_SYSTEM_MENU_KEY)
    end)
    if not ok then
      ok = pcall(function()
        game.register_action("RPG_SYSTEM_OPEN_MENU", "Open [System] Menu", open_system_from_action)
      end)
    end
  end

  if ok then
    gdebug.log_info("RPG System: Keybind registered successfully")
  else
    gdebug.log_info("RPG System: Failed to register keybind action")
  end
end

----------------------------------------------------------------
-- Soul state enforcement and helpers
----------------------------------------------------------------

-- Keys (saved per-character):
-- rpg_reset_history -> comma-separated timestamps of resets in format "timestamp:type"
-- rpg_shatter_stat_refund_done -> 0/1 flag to prevent duplicate stat refunds during shatter
-- When cumulative resets (class + trait) exceed 2 within a 30-day period, trigger soul_shattered.

local function add_reset_to_history(player, reset_type)
  local current_time = get_elapsed_turns()
  local history = player:get_value("rpg_reset_history")
  if history == "" then
    history = string.format("%d:%s", current_time, reset_type)
  else
    history = history .. "," .. string.format("%d:%s", current_time, reset_type)
  end
  player:set_value("rpg_reset_history", history)
end

local function count_recent_resets(player)
  local history = player:get_value("rpg_reset_history")
  if history == "" then return 0 end

  local current_time = get_elapsed_turns()
  local thirty_days = 60 * 60 * 24 * 30 -- 30 days in seconds
  local count = 0

  for entry in history:gmatch("[^,]+") do
    local timestamp_str = entry:match("^(%d+):")
    if timestamp_str then
      local timestamp = tonumber(timestamp_str)
      if current_time - timestamp <= thirty_days then
        count = count + 1
      end
    end
  end

  return count
end

local function clean_old_reset_history(player)
  local history = player:get_value("rpg_reset_history")
  if history == "" then return end

  local current_time = get_elapsed_turns()
  local thirty_days = 60 * 60 * 24 * 30
  local new_entries = {}

  for entry in history:gmatch("[^,]+") do
    local timestamp_str = entry:match("^(%d+):")
    if timestamp_str then
      local timestamp = tonumber(timestamp_str)
      if current_time - timestamp <= thirty_days then
        table.insert(new_entries, entry)
      end
    end
  end

  if #new_entries > 0 then
    player:set_value("rpg_reset_history", table.concat(new_entries, ","))
  else
    player:set_value("rpg_reset_history", "")
  end
end

local function strip_all_class_and_traits(player)
  for _, class_id in ipairs(ALL_CLASS_IDS) do
    if player:has_trait(class_id) then
      player:remove_mutation(class_id, true)
    end
  end

  for _, trait_id in ipairs(ALL_TRAIT_IDS) do
    if player:has_trait(trait_id) then
      player:remove_mutation(trait_id, true)
    end
  end

  set_char_value(player, "rpg_num_traits", 0)
end

local function escalate_to_shatter(player)
  -- Remove damaged_soul, apply soul_shattered for 6 days (144 hours)
  player:remove_effect(EffectTypeId.new("damaged_soul"))
  player:remove_effect(EffectTypeId.new("soul_shattered"))
  player:add_effect(EffectTypeId.new("soul_shattered"), TimeDuration.from_hours(144))

  -- Shattered soul always strips both classes and traits immediately.
  strip_all_class_and_traits(player)

  -- Refund stat points exactly once per shatter event.
  -- For pre-existing saves where rpg_assigned_* might be zero or absent,
  -- we calculate expected total points from level and compare to what is
  -- currently unassigned to infer the true assigned amount.
  local refund_done = get_char_value(player, "rpg_shatter_stat_refund_done", 0)
  if refund_done == 0 then
    local assigned_str = get_char_value(player, "rpg_assigned_str", 0)
    local assigned_dex = get_char_value(player, "rpg_assigned_dex", 0)
    local assigned_int = get_char_value(player, "rpg_assigned_int", 0)
    local assigned_per = get_char_value(player, "rpg_assigned_per", 0)
    local tracked_total = assigned_str + assigned_dex + assigned_int + assigned_per

    -- Calculate how many stat points this level should have earned in total
    local level = get_char_value(player, "rpg_level", 0)
    local expected_total_points = 0
    for lv = 1, level do
      if lv % LEVELS_PER_STAT_POINT == 0 then expected_total_points = expected_total_points + 1 end
    end

    local unassigned = get_char_value(player, "rpg_stat_points", 0)
    local total_refund

    if tracked_total > 0 then
      -- Assigned values are tracked, use them directly
      total_refund = tracked_total
    else
      -- Pre-existing save: infer assigned = expected_total - unassigned
      total_refund = math.max(0, expected_total_points - unassigned)
    end

    if total_refund > 0 then
      set_char_value(player, "rpg_assigned_str", 0)
      set_char_value(player, "rpg_assigned_dex", 0)
      set_char_value(player, "rpg_assigned_int", 0)
      set_char_value(player, "rpg_assigned_per", 0)
      set_char_value(player, "rpg_stat_points", expected_total_points)

      gapi.add_msg(
        MsgType.mixed,
        color_info(string.format(gettext("Your shattered soul releases your bound stat points. %d points refunded."), total_refund))
      )
    else
      -- Nothing to refund but ensure pool is correct
      set_char_value(player, "rpg_assigned_str", 0)
      set_char_value(player, "rpg_assigned_dex", 0)
      set_char_value(player, "rpg_assigned_int", 0)
      set_char_value(player, "rpg_assigned_per", 0)
      set_char_value(player, "rpg_stat_points", expected_total_points)
    end

    set_char_value(player, "rpg_shatter_stat_refund_done", 1)
  end

  gapi.add_msg(
    MsgType.bad,
    color_bad(gettext("Your soul SHATTERS from repeated abandonment! Your body crumbles!"))
  )
end

local function enforce_soul_state(player)
  if not player then return end

  local damaged = player:has_effect(EffectTypeId.new("damaged_soul"))
  local shattered = player:has_effect(EffectTypeId.new("soul_shattered"))

  -- If soul is healing, clear the refund guard for future shatters
  if not shattered then
    set_char_value(player, "rpg_shatter_stat_refund_done", 0)
  end

  -- Clean old entries from history periodically
  clean_old_reset_history(player)

  -- ONLY remove classes/traits when shattered (not when just damaged)
  -- damaged_soul allows keeping one while the other is reset
  if shattered then strip_all_class_and_traits(player) end
end

----------------------------------------------------------------
-- Game lifecycle hooks
----------------------------------------------------------------

mod.on_game_started = function()
  local player = gapi.get_avatar()

  set_char_value(player, "rpg_level", 0)
  set_char_value(player, "rpg_num_traits", 0)
  set_char_value(player, "rpg_max_traits", 1)
  set_char_value(player, "rpg_exp", 0)
  set_char_value(player, "rpg_xp_to_next_level", rpg_xp_needed(1))
  set_char_value(player, "rpg_stat_points", 0)
  set_char_value(player, "rpg_assigned_str", 0)
  set_char_value(player, "rpg_assigned_dex", 0)
  set_char_value(player, "rpg_assigned_int", 0)
  set_char_value(player, "rpg_assigned_per", 0)
  set_char_value(player, "rpg_class_benefit_scalar", 1.0)
  set_char_value(player, "rpg_class_penalty_scalar", 1.0)
  set_char_value(player, "rpg_trait_benefit_scalar", 1.0)
  set_char_value(player, "rpg_trait_penalty_scalar", 1.0)
  set_char_value(player, "rpg_trait_level_scalar", 0.5)
  set_char_value(player, "rpg_xp_multiplier", 1.0)
  set_char_value(player, "rpg_effect_growth_cap", 0.30)
  set_char_value(player, "rpg_nonplayer_passive_xp_scalar", 1.0)
  set_char_value(player, "rpg_nonplayer_kill_xp_scalar", 1.0)
  set_char_value(player, "rpg_nonplayer_min_level", 0)
  set_char_value(player, "rpg_nonplayer_max_level", 40)
  set_char_value(player, "rpg_system_integrated", 0)
  set_char_value(player, "rpg_shatter_stat_refund_done", 0)

  -- initialize reset history
  player:set_value("rpg_reset_history", "")

  reevaluate_all_mutations(player)

  player:add_item_with_id(ItypeId.new("system_interface"), 1)
  player:add_item_with_id(ItypeId.new("analysis_lens"), 1)
  mod.register_system_keybind()

  gapi.add_msg(
    MsgType.mixed,
    string.format(
      gettext("%s initialized. Welcome %s of world IB-73758-R. Use your %s to integrate the %s."),
      color_info(gettext("[System]")),
      color_highlight(gettext("[User]")),
      color_info(gettext("[System Interface]")),
      color_info(gettext("[System]"))
    )
  )
end

mod.on_game_load = function()
  local player = gapi.get_avatar()

  local level = get_char_value(player, "rpg_level", -1)
  if level < 0 then
    set_char_value(player, "rpg_level", 0)
    set_char_value(player, "rpg_num_traits", 0)
    set_char_value(player, "rpg_max_traits", 1)
    set_char_value(player, "rpg_exp", 0)
    set_char_value(player, "rpg_xp_to_next_level", rpg_xp_needed(1))
    set_char_value(player, "rpg_stat_points", 0)
    set_char_value(player, "rpg_assigned_str", 0)
    set_char_value(player, "rpg_assigned_dex", 0)
    set_char_value(player, "rpg_assigned_int", 0)
    set_char_value(player, "rpg_assigned_per", 0)
    set_char_value(player, "rpg_class_benefit_scalar", 1.0)
    set_char_value(player, "rpg_class_penalty_scalar", 1.0)
    set_char_value(player, "rpg_trait_benefit_scalar", 1.0)
    set_char_value(player, "rpg_trait_penalty_scalar", 1.0)
    set_char_value(player, "rpg_trait_level_scalar", 0.5)
    set_char_value(player, "rpg_xp_multiplier", 1.0)
    set_char_value(player, "rpg_effect_growth_cap", 0.30)
    set_char_value(player, "rpg_nonplayer_passive_xp_scalar", 1.0)
    set_char_value(player, "rpg_nonplayer_kill_xp_scalar", 1.0)
    set_char_value(player, "rpg_nonplayer_min_level", 0)
    set_char_value(player, "rpg_nonplayer_max_level", 40)
    set_char_value(player, "rpg_system_integrated", 0)
    set_char_value(player, "rpg_shatter_stat_refund_done", 0)

    -- initialize reset history for old saves
    if player:get_value("rpg_reset_history") == "" then
      player:set_value("rpg_reset_history", "")
    end

    player:add_item_with_id(ItypeId.new("system_interface"), 1)
    player:add_item_with_id(ItypeId.new("analysis_lens"), 1)

    gapi.add_msg(
      MsgType.mixed,
      string.format(
        gettext("%s initialized. Welcome %s of world IB-73758-R. Use your %s once to integrate, then access via keybind (default: %s)."),
        color_info(gettext("[System]")),
        color_highlight(gettext("[User]")),
        color_info(gettext("[System Interface]")),
        color_highlight(DEFAULT_SYSTEM_MENU_KEY)
      )
    )
    gdebug.log_info("RPG System: Initialized on game load")
    mod.register_system_keybind()
    return
  end

  -- Ensure integration flag exists for old saves
  if player:get_value("rpg_system_integrated") == "" then
    local has_progress = level > 0
      or get_char_value(player, "rpg_num_traits", 0) > 0
      or get_char_value(player, "rpg_assigned_str", 0) > 0
      or get_char_value(player, "rpg_assigned_dex", 0) > 0
      or get_char_value(player, "rpg_assigned_int", 0) > 0
      or get_char_value(player, "rpg_assigned_per", 0) > 0
      or has_class(player)
    set_char_value(player, "rpg_system_integrated", has_progress and 1 or 0)
  end

  -- Ensure reset history exists
  if player:get_value("rpg_reset_history") == "" then
    player:set_value("rpg_reset_history", "")
  end

  -- Ensure shatter refund guard exists
  if player:get_value("rpg_shatter_stat_refund_done") == "" then
    set_char_value(player, "rpg_shatter_stat_refund_done", 0)
  end

  ensure_scalar_value(player, "rpg_class_benefit_scalar")
  ensure_scalar_value(player, "rpg_class_penalty_scalar")
  ensure_scalar_value(player, "rpg_trait_benefit_scalar")
  ensure_scalar_value(player, "rpg_trait_penalty_scalar")
  ensure_scalar_value(player, "rpg_trait_level_scalar")
  ensure_scalar_value(player, "rpg_xp_multiplier")
  ensure_scalar_value(player, "rpg_effect_growth_cap")
  ensure_scalar_value(player, "rpg_nonplayer_passive_xp_scalar")
  ensure_scalar_value(player, "rpg_nonplayer_kill_xp_scalar")
  ensure_scalar_value(player, "rpg_nonplayer_min_level")
  ensure_scalar_value(player, "rpg_nonplayer_max_level")

  reevaluate_all_mutations(player)

  mod.register_system_keybind()
  gdebug.log_info("RPG System: Loaded character at level " .. level)
end

mod.on_creature_loaded = function(params)
  local player = gapi.get_avatar()
  if not player then return end

  local creature = params.creature
  if not creature or creature:is_avatar() then return end

  ensure_nonplayer_progress(creature, player)
end

----------------------------------------------------------------
-- Combat / XP / periodic hooks
----------------------------------------------------------------

mod.on_monster_killed = function(params)
  local killer = params.killer
  local monster = params.monster or params.mon

  if not killer or not monster then return end
  local player = gapi.get_avatar()
  if not player then return end
  local scalars = get_scalars(player)

  local killer_level = get_creature_system_level(killer, player)
  local base_xp_gain = compute_kill_xp(monster, killer_level)

  if killer:is_avatar() then
    local character = killer:as_character()
    if not character then return end

    local exp = get_char_value(character, "rpg_exp", 0)
    local old_level = get_char_value(character, "rpg_level", 0)
    local xp_gain = math.max(1, math.floor(base_xp_gain * scalars.xp_multiplier))
    local monster_hp = monster:get_hp_max()

    exp = exp + xp_gain
    set_char_value(character, "rpg_exp", exp)

    local new_level = get_rpg_level(exp)
    local leveled_up = false
    if new_level > old_level then
      leveled_up = true
      set_char_value(character, "rpg_level", new_level)

      local level_msg = color_good("★ ")
        .. color_highlight(gettext("LEVEL UP!"))
        .. color_good(" ★")
        .. " "
        .. string.format(gettext("You are now %s!"), color_info(gettext("Level") .. " " .. new_level))
      gapi.add_msg(MsgType.good, level_msg)

      local old_max_traits = 1 + math.floor(old_level / LEVELS_PER_TRAIT_SLOT)
      local new_max_traits = 1 + math.floor(new_level / LEVELS_PER_TRAIT_SLOT)
      set_char_value(character, "rpg_max_traits", new_max_traits)

      if new_max_traits > old_max_traits then
        local traits_gained = new_max_traits - old_max_traits
        gapi.add_msg(
          MsgType.good,
          color_good(vgettext("New trait slot unlocked!", "New trait slots unlocked!", traits_gained))
            .. " "
            .. string.format(gettext("You now have %s trait slots."), color_highlight(new_max_traits))
        )
      end

      local stat_points_earned = 0
      for level = old_level + 1, new_level do
        if level % LEVELS_PER_STAT_POINT == 0 then stat_points_earned = stat_points_earned + 1 end
      end

      if stat_points_earned > 0 then
        local stat_points = get_char_value(character, "rpg_stat_points", 0)
        stat_points = stat_points + stat_points_earned
        set_char_value(character, "rpg_stat_points", stat_points)
        gapi.add_msg(
          MsgType.good,
          color_good(
            string.format(
              vgettext("✦ %d stat point earned!", "✦ %d stat points earned!", stat_points_earned),
              stat_points_earned
            )
          )
            .. " "
            .. string.format(
              vgettext("You have %s unassigned stat point.", "You have %s unassigned stat points.", stat_points),
              color_highlight(stat_points)
            )
        )
      end

      reapply_active_mutations(character)
    end

    local xp_needed = rpg_xp_needed(new_level + 1)
    local xp_to_next = xp_needed - exp
    set_char_value(character, "rpg_xp_to_next_level", xp_to_next)

    local level = get_char_value(character, "rpg_level", 0)
    for _, mutation_id in ipairs(KILL_MONSTER_BONUS_IDS) do
      if player_has_mod_mutation(character, mutation_id) then
        local mutation = MUTATIONS[mutation_id:str()]
        local bonuses = mutation.kill_monster_bonuses

        if bonuses.heal_percent then
          local heal_penalty = get_effect_scalar_kind("Heal On Kill", bonuses.heal_percent, bonuses.heal_percent < 0 and "penalty" or "benefit") == "penalty"
          local level_factor = level_factor_for_mutation(mutation, "Heal On Kill", level, scalars, heal_penalty)
          local scaled_heal = scale_for_type(bonuses.heal_percent, mutation.type, heal_penalty, scalars)
          local heal_amount = math.max(1, math.floor(monster_hp * (scaled_heal * level_factor / 100)))
          character:healall(heal_amount)
        end
      end
    end

    if leveled_up then
      cache_dynamic_mutation_descriptions(character)
    end
  else
    local nonplayer_gain = math.max(1, math.floor(base_xp_gain * scalars.nonplayer_kill_xp))
    add_nonplayer_xp(killer, nonplayer_gain, player)
  end
end

mod.on_character_reset_stats = function(params)
  local character = params.character

  enforce_soul_state(character)

  if not character then return end
  if not character:is_avatar() then return end

  local level = get_char_value(character, "rpg_level", 0)
  local scalars = get_scalars(character)

  -- Apply manually assigned stats
  local assigned_str = get_char_value(character, "rpg_assigned_str", 0)
  local assigned_dex = get_char_value(character, "rpg_assigned_dex", 0)
  local assigned_int = get_char_value(character, "rpg_assigned_int", 0)
  local assigned_per = get_char_value(character, "rpg_assigned_per", 0)

  character:mod_str_bonus(assigned_str)
  character:mod_dex_bonus(assigned_dex)
  character:mod_int_bonus(assigned_int)
  character:mod_per_bonus(assigned_per)

  -- Apply stat bonuses from mutations that have them
  for _, mutation_id in ipairs(STAT_BONUS_IDS) do
    if player_has_mod_mutation(character, mutation_id) then
      local mutation = MUTATIONS[mutation_id:str()]
      local bonuses = mutation.stat_bonuses

      if bonuses.str then
        if mutation.type == "class" then
          local sc = bonuses.str < 0 and scalars.class_penalty or scalars.class_benefit
          character:mod_str_bonus(math.floor(bonuses.str * sc * level))
        else
          local str_penalty = get_effect_scalar_kind("STR", bonuses.str, bonuses.str < 0 and "penalty" or "benefit") == "penalty"
          local scaled_str = scale_for_type(bonuses.str, mutation.type, str_penalty, scalars)
          local level_factor = level_factor_for_mutation(mutation, "STR", level, scalars, str_penalty)
          character:mod_str_bonus(math.floor(level_factor * scaled_str))
        end
      end
      if bonuses.dex then
        if mutation.type == "class" then
          local sc = bonuses.dex < 0 and scalars.class_penalty or scalars.class_benefit
          character:mod_dex_bonus(math.floor(bonuses.dex * sc * level))
        else
          local dex_penalty = get_effect_scalar_kind("DEX", bonuses.dex, bonuses.dex < 0 and "penalty" or "benefit") == "penalty"
          local scaled_dex = scale_for_type(bonuses.dex, mutation.type, dex_penalty, scalars)
          local level_factor = level_factor_for_mutation(mutation, "DEX", level, scalars, dex_penalty)
          character:mod_dex_bonus(math.floor(level_factor * scaled_dex))
        end
      end
      if bonuses.int then
        if mutation.type == "class" then
          local sc = bonuses.int < 0 and scalars.class_penalty or scalars.class_benefit
          character:mod_int_bonus(math.floor(bonuses.int * sc * level))
        else
          local int_penalty = get_effect_scalar_kind("INT", bonuses.int, bonuses.int < 0 and "penalty" or "benefit") == "penalty"
          local scaled_int = scale_for_type(bonuses.int, mutation.type, int_penalty, scalars)
          local level_factor = level_factor_for_mutation(mutation, "INT", level, scalars, int_penalty)
          character:mod_int_bonus(math.floor(level_factor * scaled_int))
        end
      end
      if bonuses.per then
        if mutation.type == "class" then
          local sc = bonuses.per < 0 and scalars.class_penalty or scalars.class_benefit
          character:mod_per_bonus(math.floor(bonuses.per * sc * level))
        else
          local per_penalty = get_effect_scalar_kind("PER", bonuses.per, bonuses.per < 0 and "penalty" or "benefit") == "penalty"
          local scaled_per = scale_for_type(bonuses.per, mutation.type, per_penalty, scalars)
          local level_factor = level_factor_for_mutation(mutation, "PER", level, scalars, per_penalty)
          character:mod_per_bonus(math.floor(level_factor * scaled_per))
        end
      end
      if bonuses.speed then
        local speed_penalty = get_effect_scalar_kind("Speed Bonus", bonuses.speed, bonuses.speed < 0 and "penalty" or "benefit") == "penalty"
        local scaled_speed = scale_for_type(bonuses.speed, mutation.type, speed_penalty, scalars)
        local level_factor = level_factor_for_mutation(mutation, "Speed Bonus", level, scalars, speed_penalty)
        character:mod_speed_bonus(math.floor(level_factor * scaled_speed))
      end
    end
  end

  cache_dynamic_mutation_descriptions(character)
end

local function grant_nonplayer_passive_xp(player)
  local scalars = get_scalars(player)
  local creatures = collect_nearby_creatures(player:get_pos_ms(), ANALYSIS_LENS_SCAN_RADIUS)
  local now_turn = get_elapsed_turns_now()

  for _, creature in ipairs(creatures) do
    if not creature:is_avatar() and not creature:is_dead() then
      local level = get_creature_system_level(creature, player)
      local baseline = 3 + math.floor(level * 0.2)
      local passive_gain = math.max(1, math.floor(baseline * scalars.nonplayer_passive_xp))
      add_nonplayer_xp(creature, passive_gain, player)
      creature:set_value(NONPLAYER_LAST_PASSIVE_TURN_KEY, tostring(now_turn))
    end
  end
end

mod.on_every_5_minutes = function()
  local player = gapi.get_avatar()
  if not player then return end

  -- Periodic enforcement so players cannot bypass UI checks
  enforce_soul_state(player)

  grant_nonplayer_passive_xp(player)

  local level = get_char_value(player, "rpg_level", 0)
  if level <= 0 then return end

  local scalars = get_scalars(player)

  -- Apply periodic bonuses from mutations that have them
  for _, mutation_id in ipairs(PERIODIC_BONUS_IDS) do
    if player_has_mod_mutation(player, mutation_id) then
      local mutation = MUTATIONS[mutation_id:str()]
      local bonuses = mutation.periodic_bonuses

      if bonuses.fatigue then
        local fatigue_penalty = bonuses.fatigue > 0
        local scaled_fatigue = scale_for_type(bonuses.fatigue, mutation.type, fatigue_penalty, scalars)
        local level_factor = level_factor_for_mutation(mutation, "Fatigue", level, scalars, fatigue_penalty)
        player:mod_fatigue(math.floor(level_factor * scaled_fatigue))
      end
      if bonuses.stamina then
        local stamina_penalty = get_effect_scalar_kind("Stamina", bonuses.stamina, bonuses.stamina < 0 and "penalty" or "benefit") == "penalty"
        local scaled_stamina = scale_for_type(bonuses.stamina, mutation.type, stamina_penalty, scalars)
        local level_factor = level_factor_for_mutation(mutation, "Stamina", level, scalars, stamina_penalty)
        player:mod_stamina(math.floor(level_factor * scaled_stamina))
      end
      if bonuses.thirst and player:get_thirst() >= 40 and math.random() > 0.75 then
        local thirst_penalty = bonuses.thirst > 0
        local scaled_thirst = scale_for_type(bonuses.thirst, mutation.type, thirst_penalty, scalars)
        local level_factor = level_factor_for_mutation(mutation, "Thirst", level, scalars, thirst_penalty)
        player:mod_thirst(math.floor(level_factor * scaled_thirst * 4))
      end
      if bonuses.rad then
        local rad_penalty = bonuses.rad > 0
        local scaled_rad = scale_for_type(bonuses.rad, mutation.type, rad_penalty, scalars)
        local level_factor = level_factor_for_mutation(mutation, "Radiation", level, scalars, rad_penalty)
        player:mod_rad(math.floor(level_factor * scaled_rad))
      end
      if bonuses.healthy_mod then
        local healthy_penalty = get_effect_scalar_kind("Health", bonuses.healthy_mod, bonuses.healthy_mod < 0 and "penalty" or "benefit") == "penalty"
        local scaled_healthy = scale_for_type(bonuses.healthy_mod, mutation.type, healthy_penalty, scalars)
        local level_factor = level_factor_for_mutation(mutation, "Health", level, scalars, healthy_penalty)
        player:mod_healthy_mod(scaled_healthy * level_factor, 100)
      end
      if bonuses.morale then
        local morale_penalty = bonuses.morale < 0
        local scaled_morale = scale_for_type(bonuses.morale, mutation.type, morale_penalty, scalars)
        local level_factor = level_factor_for_mutation(mutation, "Morale", level, scalars, morale_penalty)
        local morale_amount = math.floor(level_factor * scaled_morale)
        player:add_morale(
          MoraleTypeDataId.new("morale_rpg_system"),
          morale_amount,
          morale_amount,
          TimeDuration.from_minutes(6),
          TimeDuration.from_minutes(1),
          false,
          nil
        )
      end
      if bonuses.power_level then
        local power_penalty = get_effect_scalar_kind("Power", bonuses.power_level, bonuses.power_level < 0 and "penalty" or "benefit") == "penalty"
        local scaled_power = scale_for_type(bonuses.power_level, mutation.type, power_penalty, scalars)
        local level_factor = level_factor_for_mutation(mutation, "Power", level, scalars, power_penalty)
        local power_regen = Energy.from_joule(math.floor(level_factor * scaled_power * 1000))
        player:mod_power_level(power_regen)
      end
    end
  end

end

mod.on_every_turn = function()
  local player = gapi.get_avatar()
  apply_level_effects(player)
end

----------------------------------------------------------------
-- Menus
----------------------------------------------------------------

mod.open_analysis_lens = function(params)
  local who = params.user
  if not who or not who:is_avatar() then
    return 0
  end

  local target_pos = gapi.look_around()
  if not target_pos then
    return 0
  end

  local target = gapi.get_creature_at(target_pos, false)
  if not target or target:is_avatar() then
    gapi.add_msg(MsgType.info, color_info(gettext("No valid critter or NPC selected.")))
    return 0
  end

  show_analysis_lens_screen(who:as_character(), target)
  return 0
end

mod.open_rpg_menu = function(params)

  local who = params.user
  local item = params.item
  local pos = params.pos

  if not who or not who:is_avatar() then
    return 0
  end

  local player = who
  local integrated = get_char_value(player, "rpg_system_integrated", 0)

  -- If using item after integration, block and inform
  if item and integrated == 1 then
    gapi.add_msg(
      MsgType.info,
      color_info(string.format(gettext("The [System] is already integrated with your being. Use your keybind (default: %s)."), DEFAULT_SYSTEM_MENU_KEY))
    )
    return 0
  end

  -- If not integrated yet, perform integration
  if integrated == 0 then
    if not item then
      gapi.add_msg(MsgType.info, color_info(gettext("Use the [System Interface] item first to integrate the [System].")))
      return 0
    end
    set_char_value(player, "rpg_system_integrated", 1)
    mod.register_system_keybind()
    gapi.add_msg(
      MsgType.good,
      color_good(string.format(gettext("[System] integration complete! You can now access the [System] via keybind (default: %s)."), DEFAULT_SYSTEM_MENU_KEY))
    )
    -- Item use only performs integration on first use.
    return 0
  end

  enforce_soul_state(player)
  local keep_open = true

  while keep_open do
    -- Refresh player stats to reflect any changes from class/trait selections
    player:reset()

    local exp = get_char_value(player, "rpg_exp", 0)
    local level = get_char_value(player, "rpg_level", 0)
    local num_traits = get_char_value(player, "rpg_num_traits", 0)
    local max_traits = get_char_value(player, "rpg_max_traits", 1)
    local xp_to_next = get_char_value(player, "rpg_xp_to_next_level", 0)
    local class_name, class_desc = get_class_info(player)
    local current_traits = get_current_traits(player)

    local ui = UiList.new()
    ui:title(gettext("=== [SYSTEM] ==="))

    local current_level_xp = rpg_xp_needed(level)
    local next_level_xp = rpg_xp_needed(level + 1)
    local xp_in_level = exp - current_level_xp
    local xp_for_level = next_level_xp - current_level_xp

    local str_val = player:get_str()
    local dex_val = player:get_dex()
    local int_val = player:get_int()
    local per_val = player:get_per()
    local player_name = player:get_name()

    local info_text = ""

    info_text = info_text .. color_highlight(gettext("Name:") .. " ") .. color_good(player_name) .. "\n"
    info_text = info_text .. color_highlight(gettext("Level:") .. " ") .. color_good(string.format("%d", level))
    if level < 40 then
      info_text = info_text
        .. color_text(
          string.format(" (" .. gettext("Next:") .. " %.0f " .. gettext("XP") .. ")", xp_to_next),
          "light_gray"
        )
    else
      info_text = info_text .. color_warning(" [" .. gettext("MAX") .. "]")
    end
    info_text = info_text .. "\n"

    if level < 40 then
      local progress = create_progress_bar(xp_in_level, xp_for_level, 30)
      info_text = info_text .. "XP: " .. progress .. "\n"
    end

    info_text = info_text .. color_highlight(gettext("Total XP:") .. " ") .. string.format("%.0f", exp) .. "\n"
    info_text = info_text
      .. color_text(
        "─────────────────────────────────────────",
        "light_gray"
      )
      .. "\n"

    local stat_points = get_char_value(player, "rpg_stat_points", 0)
    info_text = info_text .. color_highlight(gettext("Stats:")) .. "\n"
    info_text = info_text
      .. string.format(
        "  %s %s  %s %s  %s %s  %s %s\n",
        color_text(gettext("STR:"), "light_gray"),
        color_good(str_val),
        color_text(gettext("DEX:"), "light_gray"),
        color_good(dex_val),
        color_text(gettext("INT:"), "light_gray"),
        color_good(int_val),
        color_text(gettext("PER:"), "light_gray"),
        color_good(per_val)
      )
    if stat_points > 0 then
      info_text = info_text
        .. color_good(
          string.format(
            vgettext(
              "  ✦ %d unassigned stat point available!",
              "  ✦ %d unassigned stat points available!",
              stat_points
            ),
            stat_points
          ) .. "\n"
        )
    end

    local all_skills = {
      { name = gettext("Dodge"), skill = "dodge" },
      { name = gettext("Melee"), skill = "melee" },
      { name = gettext("Unarmed"), skill = "unarmed" },
      { name = gettext("Bashing"), skill = "bashing" },
      { name = gettext("Cutting"), skill = "cutting" },
      { name = gettext("Piercing"), skill = "stabbing" },
      { name = gettext("Archery"), skill = "archery" },
      { name = gettext("Marksmanship"), skill = "gun" },
      { name = gettext("Handguns"), skill = "pistol" },
      { name = gettext("Rifles"), skill = "rifle" },
      { name = gettext("Shotguns"), skill = "shotgun" },
      { name = gettext("SMGs"), skill = "smg" },
      { name = gettext("Launchers"), skill = "launcher" },
      { name = gettext("Throwing"), skill = "throw" },
      { name = gettext("Cooking"), skill = "cooking" },
      { name = gettext("Tailoring"), skill = "tailor" },
      { name = gettext("Mechanics"), skill = "mechanics" },
      { name = gettext("Electronics"), skill = "electronics" },
      { name = gettext("Fabrication"), skill = "fabrication" },
      { name = gettext("First Aid"), skill = "firstaid" },
      { name = gettext("Computers"), skill = "computer" },
      { name = gettext("Survival"), skill = "survival" },
      { name = gettext("Trapping"), skill = "traps" },
      { name = gettext("Athletics"), skill = "swimming" },
      { name = gettext("Driving"), skill = "driving" },
      { name = gettext("Bartering"), skill = "barter" },
      { name = gettext("Speech"), skill = "speech" },
      { name = gettext("Spellcraft"), skill = "spellcraft" },
    }

    info_text = info_text .. color_highlight(gettext("Skills:")) .. "\n"

    local displayed_skills = {}
    for _, skill_info in ipairs(all_skills) do
      local skill_level = player:get_skill_level(SkillId.new(skill_info.skill))
      if skill_level > 0 then table.insert(displayed_skills, { name = skill_info.name, level = skill_level }) end
    end

    -- Display trained skills
    if #displayed_skills > 0 then
      local skill_count = 0
      for _, skill_data in ipairs(displayed_skills) do
        local skill_color = skill_data.level >= 5 and "light_green"
          or (skill_data.level >= 3 and "white" or "light_gray")
        info_text = info_text
          .. string.format(
            "  %s %s",
            color_text(skill_data.name .. ":", "light_gray"),
            color_text(skill_data.level, skill_color)
          )
        skill_count = skill_count + 1
        if skill_count % 3 == 0 then
          info_text = info_text .. "\n"
        else
          info_text = info_text .. "  "
        end
      end
      if skill_count % 3 ~= 0 then info_text = info_text .. "\n" end
    else
      info_text = info_text .. color_text(gettext("  No skills trained yet."), "dark_gray") .. "\n"
    end

    info_text = info_text
      .. color_text(
        "─────────────────────────────────────────",
        "light_gray"
      )
      .. "\n"

    -- Class info
    if class_name == "[None]" then
      info_text = info_text .. color_highlight(gettext("Class:") .. " ") .. color_warning(gettext("[None]")) .. "\n"
    else
      info_text = info_text .. color_highlight(gettext("Class:") .. " ") .. color_good(class_name) .. "\n"
      if class_desc then
        local wrapped = wrap_text(class_desc, 60, "  ")
        info_text = info_text .. color_text(wrapped, "light_gray") .. "\n"
      end
    end

    info_text = info_text
      .. color_text(
        "─────────────────────────────────────────",
        "light_gray"
      )
      .. "\n"

    -- Trait section
    info_text = info_text
      .. color_highlight(gettext("Trait Slots:") .. " ")
      .. color_good(string.format("%d", num_traits))
      .. color_text("/", "light_gray")
      .. color_highlight(string.format("%d", max_traits))
      .. "\n"

    if #current_traits > 0 then
      info_text = info_text .. color_highlight(gettext("Active Traits:")) .. "\n"
      for _, trait in ipairs(current_traits) do
        info_text = info_text .. color_good("  • " .. trait.name) .. "\n"
        local wrapped = wrap_text(trait.desc, 58, "    ")
        info_text = info_text .. color_text(wrapped, "light_gray") .. "\n"
      end
    else
      info_text = info_text .. color_text(gettext("  No traits selected yet."), "dark_gray") .. "\n"
    end

    info_text = info_text .. "\n"

    ui:text(info_text)

    local menu_items = {}
    table.insert(menu_items, { text = gettext("Manage Class"), action = "class" })

    if stat_points > 0 then
      table.insert(
        menu_items,
        { text = color_good(string.format(gettext("Assign Stats (%d available)"), stat_points)), action = "stats" }
      )
    end

    -- Always show the Assign Traits menu (allows resetting traits)
    local available_slots = max_traits - num_traits
    if available_slots > 0 then
      table.insert(menu_items, {
        text = color_good(string.format(gettext("Assign Traits (%d available)"), available_slots)),
        action = "traits",
      })
    else
      table.insert(menu_items, { text = gettext("Manage Traits"), action = "traits" })
    end

    table.insert(menu_items, { text = gettext("Help"), action = "help" })
    table.insert(menu_items, { text = gettext("Close"), action = "close" })

    for i, item_entry in ipairs(menu_items) do
      ui:add(i, item_entry.text)
    end

    local choice_index = ui:query()

    if choice_index > 0 and choice_index <= #menu_items then
      local chosen = menu_items[choice_index]

      if chosen.action == "class" then
        mod.manage_class_menu(player)
      elseif chosen.action == "stats" then
        mod.assign_stats_menu(player)
      elseif chosen.action == "traits" then
        mod.manage_traits_menu(player)
      elseif chosen.action == "help" then
        mod.show_help_menu(player)
      elseif chosen.action == "close" then
        keep_open = false
      end
    else
      keep_open = false
    end
  end

  return 0
end

mod.manage_class_menu = function(player)
  if not player then return end

  -- Ensure enforcement is up-to-date whenever this menu is accessed
  enforce_soul_state(player)

  local level = get_char_value(player, "rpg_level", 0)

  -- Soul state flags (used to restrict selection but still allow abandon)
  local soul_damaged = player:has_effect(EffectTypeId.new("damaged_soul"))
  local soul_shattered = player:has_effect(EffectTypeId.new("soul_shattered"))
  local soul_blocked = soul_damaged or soul_shattered

  local ui = UiList.new()
  ui:title(gettext("=== Select Class ==="))
  ui:desc_enabled(true)

  local options = {}
  local index = 1

  --------------------------------------------------
  -- Base Classes
  --------------------------------------------------

  if not has_class(player) and not soul_blocked then
    for id, mutation in pairs(MUTATIONS) do
      if mutation.type == "class" and not mutation.is_prestige then

        local mutation_id = mutation:get_mutation_id()
        local class_obj = mutation_id:obj()

        local can_select, unmet, all_reqs = check_requirements(player, mutation, level)

        local display_text
        if #all_reqs > 0 then
          if can_select then
            display_text = color_good(mutation.symbol .. " [" .. class_obj:name() .. "]")
              .. " - "
              .. format_requirements_list(all_reqs, true)
          else
            display_text = color_text(mutation.symbol .. " [" .. class_obj:name() .. "]", "dark_gray")
              .. " - "
              .. format_requirements_list(all_reqs, true)
          end
        else
          if can_select then
            display_text = color_good(mutation.symbol .. " [" .. class_obj:name() .. "]")
          else
            display_text = color_text(mutation.symbol .. " [" .. class_obj:name() .. "]", "dark_gray")
          end
        end

        local class_desc = get_mutation_description(mutation, player, true)

        table.insert(options,{
          text = display_text,
          desc = class_desc,
          id = mutation_id,
          mutation = mutation,
          can_select = can_select
        })

        ui:add_w_desc(index, display_text, class_desc)
        index = index + 1
      end
    end
  end

  --------------------------------------------------
  -- Prestige Classes
  --------------------------------------------------

  if not soul_blocked then
  for id, mutation in pairs(MUTATIONS) do
    if mutation.type == "class" and mutation.is_prestige then

      local base_key = mutation.base_class
      if base_key and MUTATIONS[base_key] then

        local base_id = MUTATIONS[base_key]:get_mutation_id()

        if player:has_trait(base_id) then

          local mutation_id = mutation:get_mutation_id()
          local class_obj = mutation_id:obj()

          if not player:has_trait(mutation_id) then

            local can_select, unmet, all_reqs = check_requirements(player, mutation, level)

            local display_text
            if #all_reqs > 0 then
              if can_select then
                display_text = color_good(mutation.symbol .. " [" .. class_obj:name() .. "]")
                  .. " - "
                  .. format_requirements_list(all_reqs, true)
              else
                display_text = color_text(mutation.symbol .. " [" .. class_obj:name() .. "]", "dark_gray")
                  .. " - "
                  .. format_requirements_list(all_reqs, true)
              end
            else
              if can_select then
                display_text = color_good(mutation.symbol .. " [" .. class_obj:name() .. "]")
              else
                display_text = color_text(mutation.symbol .. " [" .. class_obj:name() .. "]", "dark_gray")
              end
            end

            local class_desc = get_mutation_description(mutation, player, true)

            table.insert(options,{
              text = display_text,
              desc = class_desc,
              id = mutation_id,
              mutation = mutation,
              can_select = can_select
            })

            ui:add_w_desc(index, display_text, class_desc)
            index = index + 1
          end
        end
      end
    end
  end

  end -- close soul_blocked guard for prestige classes

  --------------------------------------------------
  -- Abandon Class (available even during damaged soul to allow escalation)
  --------------------------------------------------

  if has_class(player) and not soul_shattered then

    table.insert(options,{
      action = "abandon",
      can_select = true
    })

    ui:add_w_desc(index,
      color_bad(gettext("✖ Abandon class")),
      color_warning(gettext("WARNING:")) .. " "
      .. gettext("Damages your soul for 3 days, with severe penalties.")
    )

    index = index + 1
  end

  -- If soul is blocked and no abandon option available, show a status message
  if soul_blocked and #options == 0 then
    if soul_shattered then
      table.insert(options, { action = "info", can_select = false })
      ui:add(index, color_bad(gettext("Your soul is shattered. Class management is unavailable.")))
    else
      table.insert(options, { action = "info", can_select = false })
      ui:add(index, color_warning(gettext("Your soul is damaged. Class management is unavailable.")))
    end
    index = index + 1
  end

  --------------------------------------------------
  -- Back
  --------------------------------------------------

  table.insert(options,{ action="back", can_select=true })
  ui:add(index, color_text(gettext("← Back"), "light_gray"))

  --------------------------------------------------
  -- Query
  --------------------------------------------------

  local choice = ui:query()

  if choice <= 0 or choice > #options then
    return
  end

  local chosen = options[choice]

  --------------------------------------------------
  -- Abandon
  --------------------------------------------------

  if chosen.action == "abandon" then

    -- Remove classes immediately
    for _, class_id in ipairs(ALL_CLASS_IDS) do
      if player:has_trait(class_id) then
        player:remove_mutation(class_id, true)
      end
    end

    -- Add this reset to history
    add_reset_to_history(player, "class")

    -- Count recent resets (within 30 days)
    local recent_resets = count_recent_resets(player)

    -- If cumulative resets >= 2, escalate to shattered
    if recent_resets >= 2 then
      escalate_to_shatter(player)
      return
    end

    -- Otherwise apply damaged_soul
    player:remove_effect(EffectTypeId.new("soul_shattered"))
    player:remove_effect(EffectTypeId.new("damaged_soul"))
    player:add_effect(EffectTypeId.new("damaged_soul"), TimeDuration.from_hours(72))

    gapi.add_msg(
      MsgType.bad,
      color_bad(gettext("✖ You have abandoned your class! Your soul is damaged."))
    )

    return
  end

  if chosen.action == "back" then
    return
  end

  --------------------------------------------------
  -- FINAL VALIDATION (CRITICAL FIX)
  --------------------------------------------------

  if not chosen.can_select then
    gapi.add_msg(
      MsgType.warning,
      color_warning(gettext("You do not meet the requirements for this class."))
    )
    return
  end

  local mutation = chosen.mutation

  if mutation.is_prestige then

    local base_key = mutation.base_class
    if not base_key or not MUTATIONS[base_key] then
      gapi.add_msg(MsgType.warning, "Invalid prestige configuration.")
      return
    end

    local base_id = MUTATIONS[base_key]:get_mutation_id()

    if not player:has_trait(base_id) then
      gapi.add_msg(
        MsgType.warning,
        color_warning(gettext("You must have the base class first."))
      )
      return
    end
  end

  local can_select_now, unmet = check_requirements(player, mutation, level)

  if not can_select_now then
    gapi.add_msg(
      MsgType.warning,
      color_warning(gettext("You do not meet the requirements for this class."))
    )
    return
  end

  --------------------------------------------------
  -- Apply class
  --------------------------------------------------

  for _, class_id in ipairs(ALL_CLASS_IDS) do
    if player:has_trait(class_id) then
      player:remove_mutation(class_id, true)
    end
  end

  player:set_mutation(chosen.id)

  gapi.add_msg(
    MsgType.good,
    string.format(
      gettext("✓ You have chosen your path as %s!"),
      color_highlight(chosen.id:obj():name())
    )
  )

end

mod.manage_traits_menu = function(player)
  if not player then return end

  -- Ensure enforcement is up-to-date whenever this menu is accessed
  enforce_soul_state(player)

  --------------------------------------------------
  -- Soul damage / shattered protection
  --------------------------------------------------

  -- Soul state flags (used to restrict selection but still allow reset)
  local soul_damaged = player:has_effect(EffectTypeId.new("damaged_soul"))
  local soul_shattered = player:has_effect(EffectTypeId.new("soul_shattered"))
  local soul_blocked = soul_damaged or soul_shattered

  local level = get_char_value(player, "rpg_level", 0)
  local num_traits = get_char_value(player, "rpg_num_traits", 0)
  local max_traits = get_char_value(player, "rpg_max_traits", 1)
  local has_available_slots = num_traits < max_traits

  local ui = UiList.new()
  ui:title(string.format(gettext("=== Select Trait (%d/%d) ==="), num_traits, max_traits))
  ui:desc_enabled(true)

  local traits = {}
  local index = 1

  local trait_candidates = {}
  for id, mutation in pairs(MUTATIONS) do
    if mutation.type == "trait" then
      local trait_id = mutation:get_mutation_id()
      local trait_obj = trait_id:obj()
      local req_level = 0
      if mutation.requirements and mutation.requirements.level then
        req_level = mutation.requirements.level
      end

      table.insert(trait_candidates, {
        mutation = mutation,
        trait_id = trait_id,
        trait_obj = trait_obj,
        req_level = req_level,
        sort_name = string.lower(tostring(trait_obj:name() or "")),
      })
    end
  end

  table.sort(trait_candidates, function(a, b)
    if a.req_level ~= b.req_level then
      return a.req_level < b.req_level
    end
    return a.sort_name < b.sort_name
  end)

  for _, candidate in ipairs(trait_candidates) do
      local mutation = candidate.mutation
      local trait_id = candidate.trait_id
      local already_has = player:has_trait(trait_id)
      local trait_obj = candidate.trait_obj

      local can_select_reqs, unmet, all_reqs = check_requirements(player, mutation, level)
      local can_select = has_available_slots and not already_has and can_select_reqs and not soul_blocked

      local display_name

      if already_has then
        display_name = color_text("✓ " .. trait_obj:name(), "dark_gray")
      elseif #all_reqs > 0 then
        if can_select_reqs then
          display_name = color_good("◆ " .. trait_obj:name()) .. " - " .. format_requirements_list(all_reqs, true)
        else
          display_name = color_text("◆ " .. trait_obj:name(), "dark_gray") .. " - " .. format_requirements_list(all_reqs, true)
        end
      else
        display_name = color_good("◆ " .. trait_obj:name())
      end

      table.insert(traits, {
        id = trait_id,
        name = display_name,
        desc = get_mutation_description(mutation, player, true),
        can_select = can_select,
        index = index,
      })

      index = index + 1
  end

  --------------------------------------------------
  -- Reset Traits option
  --------------------------------------------------

  local current_traits = get_current_traits(player)

  -- Reset is available even with damaged soul (to allow escalation to shatter)
  -- but NOT available during shattered soul
  if not soul_shattered then
    table.insert(traits, {
      name = color_text(gettext("✖ Reset Traits"), "red"),
      desc = gettext("Remove all traits and damage your soul for 3 days."),
      action = "reset",
      can_select = #current_traits > 0,
      index = index,
    })
    index = index + 1
  end

  table.insert(traits, {
    name = color_text(gettext("← Back"), "light_gray"),
    desc = gettext("Return to main menu"),
    action = "back",
    can_select = true,
    index = index,
  })

  for i, trait in ipairs(traits) do
    ui:add_w_desc(trait.index, trait.name, trait.desc or "")
    -- Don't disable entries, allow viewing all trait descriptions
  end

  local choice_index = ui:query()

  if choice_index <= 0 or choice_index > #traits then
    return
  end

  local chosen = traits[choice_index]

  if chosen.action == "back" then
    return
  end

  --------------------------------------------------
  -- Reset Traits logic with shattered soul mechanic
  --------------------------------------------------

  if chosen.action == "reset" then

    for _, trait_id in ipairs(ALL_TRAIT_IDS) do
      if player:has_trait(trait_id) then
        player:remove_mutation(trait_id, true)
      end
    end

    set_char_value(player, "rpg_num_traits", 0)

    -- Add this reset to history
    add_reset_to_history(player, "trait")

    -- Count recent resets (within 30 days)
    local recent_resets = count_recent_resets(player)

    -- If cumulative resets >= 2, escalate to shattered
    if recent_resets >= 2 then
      escalate_to_shatter(player)
      return
    end

    -- Otherwise apply damaged_soul
    player:remove_effect(EffectTypeId.new("soul_shattered"))
    player:remove_effect(EffectTypeId.new("damaged_soul"))
    player:add_effect(EffectTypeId.new("damaged_soul"), TimeDuration.from_hours(72))

    gapi.add_msg(
      MsgType.bad,
      color_bad(gettext("✖ You have abandoned your traits! Your soul is damaged."))
    )

    return
  end

  --------------------------------------------------
  -- Add trait normally
  --------------------------------------------------

  if chosen.id then
    -- Block selection if not eligible
    if not chosen.can_select then
      if not has_available_slots and not player:has_trait(chosen.id) then
        gapi.add_msg(
          MsgType.warning,
          color_warning(gettext("You have no available trait slots."))
        )
      else
        gapi.add_msg(
          MsgType.warning,
          color_warning(gettext("You cannot select this trait. Check requirements."))
        )
      end
      return
    end

    player:set_mutation(chosen.id)
    set_char_value(player, "rpg_num_traits", num_traits + 1)

    gapi.add_msg(
      MsgType.good,
      string.format(gettext("✓ You have gained %s!"), color_highlight(chosen.id:obj():name()))
    )
  end
end

----------------------------------------------------------------
-- Stats menu / help / misc
----------------------------------------------------------------

mod.assign_stats_menu = function(player)
  local stat_points = get_char_value(player, "rpg_stat_points", 0)

  if stat_points <= 0 then
    gapi.add_msg(MsgType.warning, color_warning(gettext("You have no stat points to assign.")))
    return
  end

  local ui = UiList.new()
  ui:title(string.format(gettext("=== Assign Stat Points (%d available) ==="), stat_points))
  ui:desc_enabled(true)

  local str_val = player:get_str()
  local dex_val = player:get_dex()
  local int_val = player:get_int()
  local per_val = player:get_per()

  local options = {
    {
      name = string.format(gettext("Strength (Current: %d)"), str_val),
      desc = gettext(
        "Strength affects your melee damage, the amount of weight you can carry, your total HP, your resistance to many diseases, and the effectiveness of actions which require brute force."
      ),
      stat = "STR",
    },
    {
      name = string.format(gettext("Dexterity (Current: %d)"), dex_val),
      desc = gettext(
        "Dexterity affects your chance to hit in melee combat, helps you steady your gun for ranged combat, and enhances many actions that require finesse."
      ),
      stat = "DEX",
    },
    {
      name = string.format(gettext("Intelligence (Current: %d)"), int_val),
      desc = gettext(
        "Intelligence is less important in most situations, but it is vital for more complex tasks like electronics crafting.  It also affects how much skill you can pick up from reading a book."
      ),
      stat = "INT",
    },
    {
      name = string.format(gettext("Perception (Current: %d)"), per_val),
      desc = gettext(
        "Perception is the most important stat for ranged combat.  It's also used for detecting traps and other things of interest."
      ),
      stat = "PER",
    },
    {
      name = color_text(gettext("← Back"), "light_gray"),
      desc = gettext("Return to main menu"),
      stat = "BACK",
    },
  }

  for i, opt in ipairs(options) do
    ui:add_w_desc(i, opt.name, opt.desc)
  end

  local choice_index = ui:query()

  if choice_index > 0 and choice_index <= #options then
    local chosen = options[choice_index]

    if chosen.stat == "BACK" then
      return
    elseif chosen.stat then
      local key = "rpg_assigned_" .. chosen.stat:lower()
      local current = get_char_value(player, key, 0)
      set_char_value(player, key, current + 1)

      set_char_value(player, "rpg_stat_points", stat_points - 1)

      gapi.add_msg(MsgType.good, string.format(gettext("✓ +1 %s assigned!"), color_highlight(chosen.stat)))
    end
  end
end

mod.show_help_menu = function(player)
  local ui = UiList.new()
  ui:title(gettext("=== [System] Information ==="))
  ui:desc_enabled(true)

  local options = {
    {
      name = gettext("About the System"),
      desc = gettext("[System] Query: Basic information"),
      action = "about",
    },
    {
      name = gettext("Class Tree"),
      desc = gettext("View the auto-generated class hierarchy"),
      action = "tree",
    },
    {
      name = gettext("Player Scalars"),
      desc = gettext("Tune your own class/trait bonuses, penalties, and XP scaling"),
      action = "player_scalars",
    },
    {
      name = gettext("Non-Player Scalars"),
      desc = gettext("Tune class/trait bonuses, XP, leveling rates, and rewards for critters and NPCs"),
      action = "nonplayer_scalars",
    },
    {
      name = color_text(gettext("← Back"), "light_gray"),
      desc = gettext("Return to main menu"),
      action = "back",
    },
  }

  for i, opt in ipairs(options) do
    ui:add_w_desc(i, opt.name, opt.desc)
  end

  local choice_index = ui:query()

  if choice_index > 0 and choice_index <= #options then
    local chosen = options[choice_index]

    if chosen.action == "back" then
      return
    elseif chosen.action == "about" then
      mod.show_about_screen(player)
    elseif chosen.action == "tree" then
      mod.show_class_tree_screen(player)
    elseif chosen.action == "player_scalars" then
      mod.adjust_player_scalars(player)
    elseif chosen.action == "nonplayer_scalars" then
      mod.adjust_nonplayer_scalars(player)
    end
  end
end

mod.show_about_screen = function(player)
  local ui = UiList.new()
  ui:title(gettext("=== [System] Database Entry ==="))

  local help_text = ""
  help_text = help_text .. color_info(gettext("[System]")) .. " " .. gettext("Protocol IB-73758-R") .. "\n"
  help_text = help_text
    .. color_text(
      "─────────────────────────────────────────",
      "light_gray"
    )
    .. "\n\n"

  help_text = help_text .. color_highlight(gettext("OVERVIEW")) .. "\n"
  help_text = help_text
    .. gettext("Gain experience from killing monsters, level up, choose classes, unlock traits, and assign stat points to grow stronger.")
    .. "\n\n"

  help_text = help_text .. color_highlight(gettext("EXPERIENCE & LEVELING")) .. "\n"
  help_text = help_text .. gettext("• Kill monsters to gain XP (based on their HP)") .. "\n"
  help_text = help_text .. gettext("• Level cap: 40 (progression slows significantly after level 10)") .. "\n"
  help_text = help_text .. gettext("• XP formula: XP = 2.2387 × level^3.65") .. "\n\n"

  help_text = help_text .. color_highlight(gettext("PROGRESSION REWARDS")) .. "\n"
  help_text = help_text .. string.format(gettext("• +1 stat point every %d levels"), LEVELS_PER_STAT_POINT) .. "\n"
  help_text = help_text .. string.format(gettext("• +1 trait slot every %d levels"), LEVELS_PER_TRAIT_SLOT) .. "\n"
  help_text = help_text .. gettext("• Class progression is branch-based and can be extended by other mods") .. "\n\n"

  help_text = help_text .. color_highlight(gettext("TRAITS")) .. "\n"
  help_text = help_text .. gettext("Unlock powerful passive abilities as you level.") .. "\n"
  help_text = help_text .. gettext("Each trait has stat or skill requirements you must meet.") .. "\n\n"

  help_text = help_text .. color_highlight(gettext("STAT POINTS")) .. "\n"
  help_text = help_text .. gettext("Assign earned stat points to permanently increase STR, DEX, INT, or PER.") .. "\n"
  help_text = help_text .. gettext("These bonuses are independent of class scaling.") .. "\n\n"

  help_text = help_text .. color_highlight(gettext("SOUL DAMAGE SYSTEM")) .. "\n"
  help_text = help_text .. color_warning("⚠ ") .. gettext("Abandoning classes or resetting traits damages your soul.") .. "\n"
  help_text = help_text .. gettext("• First reset: ") .. color_bad(gettext("Damaged Soul"))
    .. gettext(" (-4 all stats, 3 days)") .. "\n"
  help_text = help_text .. gettext("• Cumulative resets (>=2 in 30 days): ") .. color_bad(gettext("Shattered Soul"))
    .. gettext(" (-10 all stats, 6 days)") .. "\n"
  help_text = help_text .. gettext("• Shattered Soul refunds all assigned stat points for reallocation") .. "\n\n"

  help_text = help_text .. color_highlight(gettext("SYSTEM ACCESS")) .. "\n"
  help_text = help_text .. gettext("Use [System Interface] once to integrate with your character.") .. "\n"
  help_text = help_text
    .. string.format(gettext("After integration, use your [System] keybind (default: %s)."), DEFAULT_SYSTEM_MENU_KEY)
    .. "\n\n"

  help_text = help_text .. color_highlight(gettext("BALANCE NOTE")) .. "\n"
  help_text = help_text .. gettext("~25 character creation point value (much less early game, more late game).") .. "\n"
  help_text = help_text .. color_warning("⚠ ") .. gettext("Not designed for use with 'Stats through Kills' mod.") .. "\n"

  ui:text(help_text)
  ui:add(1, color_text(gettext("← Back"), "light_gray"))

  ui:query()
end

mod.show_class_tree_screen = function(player)
  local ui = UiList.new()
  ui:title(gettext("=== Class Tree (Auto-Generated) ==="))

  local tree_text = build_class_tree_text() .. "\n\n"
  tree_text = tree_text .. color_text(gettext("Class progression is branch-based and can be extended by other mods."), "light_gray") .. "\n"

  ui:text(tree_text)
  ui:add(1, color_text(gettext("← Back"), "light_gray"))

  ui:query()
end

mod.adjust_player_scalars = function(player)
  local class_benefit = get_scalar_value(player, "rpg_class_benefit_scalar")
  local class_penalty = get_scalar_value(player, "rpg_class_penalty_scalar")
  local trait_benefit = get_scalar_value(player, "rpg_trait_benefit_scalar")
  local trait_penalty = get_scalar_value(player, "rpg_trait_penalty_scalar")
  local xp_multiplier = get_scalar_value(player, "rpg_xp_multiplier")
  local trait_level_scalar = get_scalar_value(player, "rpg_trait_level_scalar")
  local effect_growth_cap = get_scalar_value(player, "rpg_effect_growth_cap")

  while true do
    local ui = UiList.new()
    ui:title(gettext("=== Player Scalars ==="))
    ui:desc_enabled(true)

    local info_text = ""
    info_text = info_text .. color_highlight(gettext("Class Benefit Scalar:")) .. " " .. color_good(format_decimal(class_benefit)) .. "\n"
    info_text = info_text .. color_highlight(gettext("Class Penalty Scalar:")) .. " " .. color_bad(format_decimal(class_penalty)) .. "\n"
    info_text = info_text .. color_highlight(gettext("Trait Benefit Scalar:")) .. " " .. color_good(format_decimal(trait_benefit)) .. "\n"
    info_text = info_text .. color_highlight(gettext("Trait Penalty Scalar:")) .. " " .. color_bad(format_decimal(trait_penalty)) .. "\n"
    info_text = info_text .. color_highlight(gettext("XP Multiplier:")) .. " " .. color_good(format_decimal(xp_multiplier)) .. "\n"
    info_text = info_text .. color_highlight(gettext("Trait Level Scalar:")) .. " " .. color_good(format_decimal(trait_level_scalar)) .. "\n"
    info_text = info_text .. color_highlight(gettext("Level Growth Cap:")) .. " " .. color_good(format_decimal(effect_growth_cap)) .. "\n\n"
    info_text = info_text .. color_text(gettext("Select an entry and type any floating-point value."), "light_gray") .. "\n"
    info_text = info_text .. color_text(gettext("All changes are applied immediately."), "light_gray") .. "\n"
    ui:text(info_text)

    local options = {
      { name = gettext("Set Class Benefit Scalar"), action = "class_benefit" },
      { name = gettext("Set Class Penalty Scalar"), action = "class_penalty" },
      { name = gettext("Set Trait Benefit Scalar"), action = "trait_benefit" },
      { name = gettext("Set Trait Penalty Scalar"), action = "trait_penalty" },
      { name = gettext("Set XP Multiplier"), action = "xp_multiplier" },
      { name = gettext("Set Trait Level Scalar"), action = "trait_level_scalar" },
      { name = gettext("Set Level Growth Cap"), action = "effect_growth_cap" },
      { name = color_text(gettext("← Back"), "light_gray"), action = "back" },
    }

    for i, opt in ipairs(options) do
      ui:add(i, opt.name)
    end

    local choice_index = ui:query()
    if choice_index <= 0 or choice_index > #options then
      return
    end

    local chosen = options[choice_index]
    if chosen.action == "back" then return end

    if chosen.action == "class_benefit" then
      local value = prompt_scalar_value({ title = gettext("Class Benefit Scalar"), desc = gettext("Multiplies class stat/effect benefits for your character."), current = class_benefit, minimum = 0.0 })
      if value then class_benefit = value; set_char_value(player, "rpg_class_benefit_scalar", class_benefit) end
    elseif chosen.action == "class_penalty" then
      local value = prompt_scalar_value({ title = gettext("Class Penalty Scalar"), desc = gettext("Multiplies class stat/effect penalties for your character."), current = class_penalty, minimum = 0.0 })
      if value then class_penalty = value; set_char_value(player, "rpg_class_penalty_scalar", class_penalty) end
    elseif chosen.action == "trait_benefit" then
      local value = prompt_scalar_value({ title = gettext("Trait Benefit Scalar"), desc = gettext("Multiplies trait stat/effect benefits for your character."), current = trait_benefit, minimum = 0.0 })
      if value then trait_benefit = value; set_char_value(player, "rpg_trait_benefit_scalar", trait_benefit) end
    elseif chosen.action == "trait_penalty" then
      local value = prompt_scalar_value({ title = gettext("Trait Penalty Scalar"), desc = gettext("Multiplies trait stat/effect penalties for your character."), current = trait_penalty, minimum = 0.0 })
      if value then trait_penalty = value; set_char_value(player, "rpg_trait_penalty_scalar", trait_penalty) end
    elseif chosen.action == "xp_multiplier" then
      local value = prompt_scalar_value({ title = gettext("XP Multiplier"), desc = gettext("Global multiplier on all XP gained by your character."), current = xp_multiplier, minimum = 0.0 })
      if value then xp_multiplier = value; set_char_value(player, "rpg_xp_multiplier", xp_multiplier) end
    elseif chosen.action == "trait_level_scalar" then
      local value = prompt_scalar_value({ title = gettext("Trait Level Scalar"), desc = gettext("Scales how fast trait effects grow with level (capped by Level Growth Cap)."), current = trait_level_scalar, minimum = 0.0 })
      if value then trait_level_scalar = value; set_char_value(player, "rpg_trait_level_scalar", trait_level_scalar) end
    elseif chosen.action == "effect_growth_cap" then
      local value = prompt_scalar_value({ title = gettext("Level Growth Cap"), desc = gettext("Maximum level-based growth (0.30 = 30%%). Caps both benefits and penalties."), current = effect_growth_cap, minimum = 0.0 })
      if value then effect_growth_cap = value; set_char_value(player, "rpg_effect_growth_cap", effect_growth_cap) end
    end

    reapply_active_mutations(player)
    cache_dynamic_mutation_descriptions(player)
    player:reset()
  end
end

mod.adjust_nonplayer_scalars = function(player)
  local np_class_benefit     = get_scalar_value(player, "rpg_nonplayer_class_benefit_scalar")
  local np_class_penalty     = get_scalar_value(player, "rpg_nonplayer_class_penalty_scalar")
  local np_trait_benefit     = get_scalar_value(player, "rpg_nonplayer_trait_benefit_scalar")
  local np_trait_penalty     = get_scalar_value(player, "rpg_nonplayer_trait_penalty_scalar")
  local np_xp_multiplier     = get_scalar_value(player, "rpg_nonplayer_xp_multiplier")
  local np_trait_level       = get_scalar_value(player, "rpg_nonplayer_trait_level_scalar")
  local np_growth_cap        = get_scalar_value(player, "rpg_nonplayer_effect_growth_cap")
  local np_passive_xp        = get_scalar_value(player, "rpg_nonplayer_passive_xp_scalar")
  local np_kill_xp           = get_scalar_value(player, "rpg_nonplayer_kill_xp_scalar")
  local np_background_rate   = get_scalar_value(player, "rpg_nonplayer_background_rate")
  local np_spawn_level_chance = get_scalar_value(player, "rpg_nonplayer_spawn_level_chance_scalar")
  local np_speed_per_level_bonus = get_scalar_value(player, "rpg_nonplayer_speed_per_level_bonus")
  local np_min_level         = get_scalar_value(player, "rpg_nonplayer_min_level")
  local np_max_level         = get_scalar_value(player, "rpg_nonplayer_max_level")
  local np_stat_pt_interval  = get_scalar_value(player, "rpg_nonplayer_levels_per_stat_point")
  local np_trait_pt_interval = get_scalar_value(player, "rpg_nonplayer_levels_per_trait_slot")

  while true do
    local ui = UiList.new()
    ui:title(gettext("=== Non-Player Scalars ==="))
    ui:desc_enabled(true)

    local t = ""
    t = t .. color_highlight(gettext("--- Class & Trait Bonuses ---")) .. "\n"
    t = t .. color_highlight(gettext("Class Benefit:")) .. " " .. color_good(format_decimal(np_class_benefit))
        .. "   " .. color_highlight(gettext("Class Penalty:")) .. " " .. color_bad(format_decimal(np_class_penalty)) .. "\n"
    t = t .. color_highlight(gettext("Trait Benefit:")) .. " " .. color_good(format_decimal(np_trait_benefit))
        .. "   " .. color_highlight(gettext("Trait Penalty:")) .. " " .. color_bad(format_decimal(np_trait_penalty)) .. "\n"
    t = t .. color_highlight(gettext("Trait Level Scalar:")) .. " " .. color_good(format_decimal(np_trait_level))
        .. "   " .. color_highlight(gettext("Level Growth Cap:")) .. " " .. color_good(format_decimal(np_growth_cap)) .. "\n\n"
    t = t .. color_highlight(gettext("--- XP ---")) .. "\n"
    t = t .. color_highlight(gettext("XP Multiplier:")) .. " " .. color_good(format_decimal(np_xp_multiplier))
        .. "   " .. color_highlight(gettext("Passive XP Scalar:")) .. " " .. color_good(format_decimal(np_passive_xp)) .. "\n"
    t = t .. color_highlight(gettext("Kill XP Scalar:")) .. " " .. color_good(format_decimal(np_kill_xp))
        .. "   " .. color_highlight(gettext("Background Rate:")) .. " " .. color_good(format_decimal(np_background_rate)) .. "\n\n"
    t = t .. color_highlight(gettext("Spawn Level Chance:")) .. " " .. color_good(format_decimal(np_spawn_level_chance))
      .. color_text(gettext(" (lower = fewer high-level spawns)"), "light_gray") .. "\n\n"
    t = t .. color_highlight(gettext("--- Level Limits ---")) .. "\n"
    t = t .. color_highlight(gettext("Min Level:")) .. " " .. color_good(string.format("%.0f", np_min_level))
        .. "   " .. color_highlight(gettext("Max Level:")) .. " " .. color_good(string.format("%.0f", np_max_level)) .. "\n\n"
    t = t .. color_highlight(gettext("--- Level Rewards ---")) .. "\n"
    t = t .. color_highlight(gettext("Speed Bonus Per Level:")) .. " " .. color_good(format_decimal(np_speed_per_level_bonus)) .. "\n"
    t = t .. color_highlight(gettext("Levels Per Stat Point:")) .. " " .. color_good(string.format("%.0f", np_stat_pt_interval)) .. "\n"
    t = t .. color_highlight(gettext("Levels Per Trait Slot:")) .. " " .. color_good(string.format("%.0f", np_trait_pt_interval)) .. "\n\n"
    t = t .. color_text(gettext("Select an entry to edit. All changes apply immediately."), "light_gray") .. "\n"
    ui:text(t)

    local options = {
      { name = gettext("Set Class Benefit Scalar"),     action = "np_class_benefit" },
      { name = gettext("Set Class Penalty Scalar"),     action = "np_class_penalty" },
      { name = gettext("Set Trait Benefit Scalar"),     action = "np_trait_benefit" },
      { name = gettext("Set Trait Penalty Scalar"),     action = "np_trait_penalty" },
      { name = gettext("Set Trait Level Scalar"),       action = "np_trait_level" },
      { name = gettext("Set Level Growth Cap"),          action = "np_growth_cap" },
      { name = gettext("Set XP Multiplier"),             action = "np_xp_multiplier" },
      { name = gettext("Set Passive XP Scalar"),        action = "np_passive_xp" },
      { name = gettext("Set Kill XP Scalar"),           action = "np_kill_xp" },
      { name = gettext("Set Background Leveling Rate"), action = "np_background_rate" },
      { name = gettext("Set Spawn Level Chance Scalar"), action = "np_spawn_level_chance" },
      { name = gettext("Set Min Level"),                action = "np_min_level" },
      { name = gettext("Set Max Level"),                action = "np_max_level" },
      { name = gettext("Set Speed Bonus Per Level"),    action = "np_speed_per_level_bonus" },
      { name = gettext("Set Levels Per Stat Point"),    action = "np_stat_pt_interval" },
      { name = gettext("Set Levels Per Trait Slot"),    action = "np_trait_pt_interval" },
      { name = color_text(gettext("← Back"), "light_gray"), action = "back" },
    }

    for i, opt in ipairs(options) do
      ui:add(i, opt.name)
    end

    local choice_index = ui:query()
    if choice_index <= 0 or choice_index > #options then return end
    local chosen = options[choice_index]
    if chosen.action == "back" then return end

    if chosen.action == "np_class_benefit" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Class Benefit Scalar"), desc = gettext("Multiplies class stat bonuses for non-player entities."), current = np_class_benefit, minimum = 0.0 })
      if v then np_class_benefit = v; set_char_value(player, "rpg_nonplayer_class_benefit_scalar", v) end
    elseif chosen.action == "np_class_penalty" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Class Penalty Scalar"), desc = gettext("Multiplies class stat penalties for non-player entities."), current = np_class_penalty, minimum = 0.0 })
      if v then np_class_penalty = v; set_char_value(player, "rpg_nonplayer_class_penalty_scalar", v) end
    elseif chosen.action == "np_trait_benefit" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Trait Benefit Scalar"), desc = gettext("Multiplies trait stat bonuses for non-player entities."), current = np_trait_benefit, minimum = 0.0 })
      if v then np_trait_benefit = v; set_char_value(player, "rpg_nonplayer_trait_benefit_scalar", v) end
    elseif chosen.action == "np_trait_penalty" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Trait Penalty Scalar"), desc = gettext("Multiplies trait stat penalties for non-player entities."), current = np_trait_penalty, minimum = 0.0 })
      if v then np_trait_penalty = v; set_char_value(player, "rpg_nonplayer_trait_penalty_scalar", v) end
    elseif chosen.action == "np_trait_level" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Trait Level Scalar"), desc = gettext("How fast trait effects scale with level (capped by Level Growth Cap)."), current = np_trait_level, minimum = 0.0 })
      if v then np_trait_level = v; set_char_value(player, "rpg_nonplayer_trait_level_scalar", v) end
    elseif chosen.action == "np_growth_cap" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Level Growth Cap"), desc = gettext("Maximum level-based growth (0.30 = 30%%) for non-player class/trait effects."), current = np_growth_cap, minimum = 0.0 })
      if v then np_growth_cap = v; set_char_value(player, "rpg_nonplayer_effect_growth_cap", v) end
    elseif chosen.action == "np_xp_multiplier" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter XP Multiplier"), desc = gettext("Global multiplier on all XP gained by non-player entities."), current = np_xp_multiplier, minimum = 0.0 })
      if v then np_xp_multiplier = v; set_char_value(player, "rpg_nonplayer_xp_multiplier", v) end
    elseif chosen.action == "np_passive_xp" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Passive XP Scalar"), desc = gettext("Scales passive XP ticked to nearby non-players every 5 minutes."), current = np_passive_xp, minimum = 0.0 })
      if v then np_passive_xp = v; set_char_value(player, "rpg_nonplayer_passive_xp_scalar", v) end
    elseif chosen.action == "np_kill_xp" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Kill XP Scalar"), desc = gettext("Scales XP non-players earn when they make kills."), current = np_kill_xp, minimum = 0.0 })
      if v then np_kill_xp = v; set_char_value(player, "rpg_nonplayer_kill_xp_scalar", v) end
    elseif chosen.action == "np_background_rate" then
      local v = prompt_scalar_value({ title = gettext("Background Leveling Rate"), desc = gettext("Fraction of nearby-tick XP that off-screen entities accumulate per interval. Default: 0.05."), current = np_background_rate, minimum = 0.0 })
      if v then np_background_rate = v; set_char_value(player, "rpg_nonplayer_background_rate", v) end
    elseif chosen.action == "np_spawn_level_chance" then
      local v = prompt_scalar_value({ title = gettext("Spawn Level Chance Scalar"), desc = gettext("Scales the per-step chance for non-players to roll above baseline level at spawn. Lower values reduce high-level spawns. Default: 0.90."), current = np_spawn_level_chance, minimum = 0.10 })
      if v then np_spawn_level_chance = math.max(0.10, v); set_char_value(player, "rpg_nonplayer_spawn_level_chance_scalar", np_spawn_level_chance) end
    elseif chosen.action == "np_min_level" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Min Level"), desc = gettext("Floor level for all non-player entities."), current = np_min_level, minimum = 0.0 })
      if v then
        np_min_level = math.floor(v)
        if np_min_level > np_max_level then np_max_level = np_min_level; set_char_value(player, "rpg_nonplayer_max_level", np_max_level) end
        set_char_value(player, "rpg_nonplayer_min_level", np_min_level)
      end
    elseif chosen.action == "np_max_level" then
      local v = prompt_scalar_value({ title = gettext("NPC/Critter Max Level"), desc = gettext("Level cap for all non-player entities (hard max: 40)."), current = np_max_level, minimum = 0.0 })
      if v then
        np_max_level = math.min(40, math.floor(v))
        if np_max_level < np_min_level then np_min_level = np_max_level; set_char_value(player, "rpg_nonplayer_min_level", np_min_level) end
        set_char_value(player, "rpg_nonplayer_max_level", np_max_level)
      end
    elseif chosen.action == "np_speed_per_level_bonus" then
      local v = prompt_scalar_value({ title = gettext("Speed Bonus Per Level"), desc = gettext("Flat speed granted to non-players for each level. Default: 5."), current = np_speed_per_level_bonus, minimum = 0.0 })
      if v then np_speed_per_level_bonus = v; set_char_value(player, "rpg_nonplayer_speed_per_level_bonus", v) end
    elseif chosen.action == "np_stat_pt_interval" then
      local v = prompt_scalar_value({ title = gettext("Levels Per Stat Point"), desc = gettext("Every X levels a non-player earns one stat point (auto-assigned to focus stat). Default: 2."), current = np_stat_pt_interval, minimum = 1.0 })
      if v then np_stat_pt_interval = math.max(1, math.floor(v)); set_char_value(player, "rpg_nonplayer_levels_per_stat_point", np_stat_pt_interval) end
    elseif chosen.action == "np_trait_pt_interval" then
      local v = prompt_scalar_value({ title = gettext("Levels Per Trait Slot"), desc = gettext("Every X levels a non-player unlocks one additional trait slot. Default: 5."), current = np_trait_pt_interval, minimum = 1.0 })
      if v then np_trait_pt_interval = math.max(1, math.floor(v)); set_char_value(player, "rpg_nonplayer_levels_per_trait_slot", np_trait_pt_interval) end
    end
  end
end
