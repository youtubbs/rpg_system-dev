-- main.lua
gdebug.log_info("RPG System: Main")

local mod = game.mod_runtime[game.current_mod]
local storage = game.mod_storage[game.current_mod]
local mutations = require("rpg_mutations")
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
local DEFAULT_SYSTEM_MENU_KEY = "{"

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

local function get_char_value(char, key, default)
  local val = char:get_value(key)
  if val == "" then return default end
  return tonumber(val) or default
end

local function set_char_value(char, key, value) char:set_value(key, tostring(value)) end

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
      local class_obj = class_id:obj()
      return class_obj:name(), class_obj:desc()
    end
  end
  return "[None]", nil
end

local function get_current_traits(char)
  local current = {}
  for _, trait_id in ipairs(ALL_TRAIT_IDS) do
    if char:has_trait(trait_id) then
      local trait_obj = trait_id:obj()
      table.insert(current, { name = trait_obj:name(), desc = trait_obj:desc() })
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

  -- BN PR #7848 schema (https://github.com/cataclysmbn/Cataclysm-BN/pull/7848): register a Lua action-menu entry with bindable hotkey.
  if gapi.register_action_menu_entry then
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
  set_char_value(player, "rpg_level_scaling", 100)
  set_char_value(player, "rpg_system_integrated", 0)
  set_char_value(player, "rpg_shatter_stat_refund_done", 0)

  -- initialize reset history
  player:set_value("rpg_reset_history", "")

  player:add_item_with_id(ItypeId.new("system_interface"), 1)
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
    set_char_value(player, "rpg_level_scaling", 100)
    set_char_value(player, "rpg_system_integrated", 0)
    set_char_value(player, "rpg_shatter_stat_refund_done", 0)

    -- initialize reset history for old saves
    if player:get_value("rpg_reset_history") == "" then
      player:set_value("rpg_reset_history", "")
    end

    player:add_item_with_id(ItypeId.new("system_interface"), 1)

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

  mod.register_system_keybind()
  gdebug.log_info("RPG System: Loaded character at level " .. level)
end

----------------------------------------------------------------
-- Combat / XP / periodic hooks
----------------------------------------------------------------

mod.on_monster_killed = function(params)
  local killer = params.killer
  local monster = params.monster or params.mon

  if not killer or not monster then return end
  if not killer:is_avatar() then return end

  local player = killer:as_character()
  if not player then return end

  local exp = get_char_value(player, "rpg_exp", 0)
  local old_level = get_char_value(player, "rpg_level", 0)

  local monster_hp = monster:get_hp_max()
  local xp_gain = math.max(1, math.floor(monster_hp / 10))
  exp = exp + xp_gain
  set_char_value(player, "rpg_exp", exp)

  local new_level = get_rpg_level(exp)
  if new_level > old_level then
    set_char_value(player, "rpg_level", new_level)

    local level_msg = color_good("★ ")
      .. color_highlight(gettext("LEVEL UP!"))
      .. color_good(" ★")
      .. " "
      .. string.format(gettext("You are now %s!"), color_info(gettext("Level") .. " " .. new_level))
    gapi.add_msg(MsgType.good, level_msg)

    -- Calculate trait slots
    local old_max_traits = 1 + math.floor(old_level / LEVELS_PER_TRAIT_SLOT)
    local new_max_traits = 1 + math.floor(new_level / LEVELS_PER_TRAIT_SLOT)
    set_char_value(player, "rpg_max_traits", new_max_traits)

    if new_max_traits > old_max_traits then
      local traits_gained = new_max_traits - old_max_traits
      gapi.add_msg(
        MsgType.good,
        color_good(vgettext("New trait slot unlocked!", "New trait slots unlocked!", traits_gained))
          .. " "
          .. string.format(gettext("You now have %s trait slots."), color_highlight(new_max_traits))
      )
    end

    -- Calculate stat points earned by iterating through levels crossed
    local stat_points_earned = 0
    for level = old_level + 1, new_level do
      if level % LEVELS_PER_STAT_POINT == 0 then stat_points_earned = stat_points_earned + 1 end
    end

    if stat_points_earned > 0 then
      local stat_points = get_char_value(player, "rpg_stat_points", 0)
      stat_points = stat_points + stat_points_earned
      set_char_value(player, "rpg_stat_points", stat_points)
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
  end

  local xp_needed = rpg_xp_needed(new_level + 1)
  local xp_to_next = xp_needed - exp
  set_char_value(player, "rpg_xp_to_next_level", xp_to_next)

  -- Apply kill monster bonuses (e.g., healing on kill)
  local level = get_char_value(player, "rpg_level", 0)
  local level_scaling = get_char_value(player, "rpg_level_scaling", 100) / 100.0

  for _, mutation_id in ipairs(KILL_MONSTER_BONUS_IDS) do
    if player:has_trait(mutation_id) then
      local mutation = MUTATIONS[mutation_id:str()]
      local bonuses = mutation.kill_monster_bonuses

      if bonuses.heal_percent then
        local heal_amount = math.max(1, math.floor(monster_hp * (bonuses.heal_percent * level * level_scaling / 100)))
        player:healall(heal_amount)
      end
    end
  end
end

mod.on_character_reset_stats = function(params)
  local character = params.character

  enforce_soul_state(character)

  if not character then return end
  if not character:is_avatar() then return end

  local level = get_char_value(character, "rpg_level", 0)
  local level_scaling = get_char_value(character, "rpg_level_scaling", 100) / 100.0

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
    if character:has_trait(mutation_id) then
      local mutation = MUTATIONS[mutation_id:str()]
      local bonuses = mutation.stat_bonuses

      if bonuses.str then character:mod_str_bonus(math.floor(level * bonuses.str * level_scaling)) end
      if bonuses.dex then character:mod_dex_bonus(math.floor(level * bonuses.dex * level_scaling)) end
      if bonuses.int then character:mod_int_bonus(math.floor(level * bonuses.int * level_scaling)) end
      if bonuses.per then character:mod_per_bonus(math.floor(level * bonuses.per * level_scaling)) end
      if bonuses.speed then character:mod_speed_bonus(math.floor(level * bonuses.speed * level_scaling)) end
    end
  end
end

mod.on_every_5_minutes = function()
  local player = gapi.get_avatar()
  if not player then return end

  -- Periodic enforcement so players cannot bypass UI checks
  enforce_soul_state(player)

  local level = get_char_value(player, "rpg_level", 0)
  if level <= 0 then return end

  local level_scaling = get_char_value(player, "rpg_level_scaling", 100) / 100.0

  -- Apply periodic bonuses from mutations that have them
  for _, mutation_id in ipairs(PERIODIC_BONUS_IDS) do
    if player:has_trait(mutation_id) then
      local mutation = MUTATIONS[mutation_id:str()]
      local bonuses = mutation.periodic_bonuses

      if bonuses.fatigue then player:mod_fatigue(math.floor(level * bonuses.fatigue * level_scaling)) end
      if bonuses.stamina then player:mod_stamina(math.floor(level * bonuses.stamina * level_scaling)) end
      if bonuses.thirst and player:get_thirst() >= 40 and math.random() > 0.75 then
        player:mod_thirst(math.floor(level * bonuses.thirst * level_scaling * 4))
      end
      if bonuses.rad then player:mod_rad(math.floor(level * bonuses.rad * level_scaling)) end
      if bonuses.healthy_mod then player:mod_healthy_mod(bonuses.healthy_mod * level * level_scaling, 100) end
      if bonuses.power_level then
        local power_regen = Energy.from_joule(math.floor(level * bonuses.power_level * 1000 * level_scaling))
        player:mod_power_level(power_regen)
      end
    end
  end
end

----------------------------------------------------------------
-- Menus
----------------------------------------------------------------

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

        table.insert(options,{
          text = display_text,
          desc = class_obj:desc(),
          id = mutation_id,
          mutation = mutation,
          can_select = can_select
        })

        ui:add_w_desc(index, display_text, class_obj:desc())
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

            table.insert(options,{
              text = display_text,
              desc = class_obj:desc(),
              id = mutation_id,
              mutation = mutation,
              can_select = can_select
            })

            ui:add_w_desc(index, display_text, class_obj:desc())
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
        desc = trait_obj:desc(),
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
      name = gettext("Adjust Level Scaling"),
      desc = gettext("Fine-tune power scaling for balance"),
      action = "scaling",
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
    elseif chosen.action == "scaling" then
      mod.adjust_level_scaling(player)
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

mod.adjust_level_scaling = function(player)
  local current_scaling = get_char_value(player, "rpg_level_scaling", 100)

  local ui = UiList.new()
  ui:title(gettext("=== Adjust Level Scaling ==="))
  ui:desc_enabled(true)

  local info_text = ""
  info_text = info_text .. gettext("Current setting:") .. " " .. color_highlight(current_scaling .. "%") .. "\n"
  info_text = info_text
    .. color_text(
      gettext("Affects class bonuses and periodic effects. Things that don't scale with level are unaffected."),
      "light_gray"
    )
    .. "\n"
  info_text = info_text .. color_text(gettext("Does not affect assigned stats."), "light_gray") .. "\n\n"

  ui:text(info_text)

  local options = {
    {
      name = gettext("0% (Disable scaling)"),
      desc = gettext("Disables all level-based class bonuses and periodic effects."),
      value = 0,
    },
    {
      name = gettext("50% (Half power)"),
      desc = gettext("Half effectiveness for balanced gameplay."),
      value = 50,
    },
    {
      name = gettext("100% (Full power)"),
      desc = gettext("Default intended [System] experience."),
      value = 100,
    },
    {
      name = color_text(gettext("← Back"), "light_gray"),
      desc = gettext("Return to help menu"),
      value = nil,
    },
  }

  for i, opt in ipairs(options) do
    local display_name = opt.name
    if opt.value == current_scaling then display_name = color_good("✓ " .. opt.name) end
    ui:add_w_desc(i, display_name, opt.desc)
  end

  local choice_index = ui:query()

  if choice_index > 0 and choice_index <= #options then
    local chosen = options[choice_index]

    if chosen.value ~= nil then
      set_char_value(player, "rpg_level_scaling", chosen.value)
      gapi.add_msg(
        MsgType.good,
        string.format(gettext("Level scaling set to %s"), color_highlight(chosen.value .. "%"))
      )
    end
  end
end