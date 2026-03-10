gdebug.log_info("RPG System: Loading Mutations")

local Mutation = {}
Mutation.__index = Mutation

function Mutation.new(config)
  local self = setmetatable({}, Mutation)
  self.id = config.id
  self.type = config.type -- "class" or "trait"
  self.symbol = config.symbol or ""
  self.is_prestige = config.is_prestige or false
  self.requirements = config.requirements or {} -- { stats = { STR = 8 }, skills = { melee = 6 }, level = 10 }
  self.stat_bonuses = config.stat_bonuses or {} -- { str = 0.55, dex = 0.2, int = 0.1, per = 0.15, speed = 1 }
  self.periodic_bonuses = config.periodic_bonuses or {} -- { fatigue = -0.5, stamina = 20, thirst = -1.5, rad = -0.5, healthy_mod = 0.1, power_level = 1 }
  self.kill_monster_bonuses = config.kill_monster_bonuses or {} -- { heal_percent = 0.5 }
  self.base_class = config.base_class -- for prestige classes (the class to remove when selecting this)
  return self
end

function Mutation:get_mutation_id() return MutationBranchId.new(self.id) end

MUTATIONS = {

-- Base Classes

  RPG_WARRIOR = Mutation.new({
    id = "RPG_WARRIOR",
    type = "class",
    symbol = "○",
    stat_bonuses = { str = 0.55, dex = 0.20, int = 0.10, per = 0.15 },
    periodic_bonuses = { stamina = 50 }
  }),

  RPG_MAGE = Mutation.new({
    id = "RPG_MAGE",
    type = "class",
    symbol = "○",
    stat_bonuses = { str = 0.10, dex = 0.05, int = 0.55, per = 0.30 }
  }),

  RPG_ROGUE = Mutation.new({
    id = "RPG_ROGUE",
    type = "class",
    symbol = "○",
    stat_bonuses = { str = 0.10, dex = 0.55, int = 0.15, per = 0.20 }
  }),

  RPG_SCOUT = Mutation.new({
    id = "RPG_SCOUT",
    type = "class",
    symbol = "○",
    stat_bonuses = { str = 0.15, dex = 0.30, int = 0.05, per = 0.50 },
    stat_bonuses_extra = { speed = 1 }
  }),

  -- Warrior Prestige

  RPG_BERSERKER = Mutation.new({
    id = "RPG_BERSERKER",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_WARRIOR",
    requirements = { level = 10, stats = { STR = 16 }, skills = { melee = 5 } },
    stat_bonuses = { str = 0.75, dex = 0.45, int = 0.10, per = 0.20 },
    periodic_bonuses = { stamina = 50 }
  }),

  RPG_GUARDIAN = Mutation.new({
    id = "RPG_GUARDIAN",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_WARRIOR",
    requirements = { level = 10, stats = { STR = 16, PER = 14 }, skills = { melee = 4 } },
    stat_bonuses = { str = 0.60, dex = 0.15, int = 0.15, per = 0.60 },
    periodic_bonuses = { stamina = 50 }
  }),

  RPG_SPELLSWORD = Mutation.new({
    id = "RPG_SPELLSWORD",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_WARRIOR",
    requirements = { level = 10, stats = { STR = 14, INT = 14 }, skills = { melee = 4, spellcraft = 3 } },
    stat_bonuses = { str = 0.55, dex = 0.35, int = 0.45, per = 0.25 }
  }),

  -- Mage Prestige

  RPG_MYSTIC = Mutation.new({
    id = "RPG_MYSTIC",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_MAGE",
    requirements = { level = 10, stats = { INT = 16 }, skills = { spellcraft = 5 } },
    stat_bonuses = { str = 0.10, dex = 0.20, int = 0.75, per = 0.45 }
  }),

  RPG_SCHOLAR = Mutation.new({
    id = "RPG_SCHOLAR",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_MAGE",
    requirements = { level = 10, stats = { INT = 16 }, skills = { computer = 4, fabrication = 4 } },
    stat_bonuses = { str = 0.05, dex = 0.15, int = 0.80, per = 0.50 }
  }),

  RPG_BATTLEMAGE = Mutation.new({
    id = "RPG_BATTLEMAGE",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_MAGE",
    requirements = { level = 10, stats = { INT = 16, STR = 12 }, skills = { spellcraft = 4, melee = 3 } },
    stat_bonuses = { str = 0.35, dex = 0.25, int = 0.75, per = 0.25 }
  }),

  -- Rogue Prestige

  RPG_ACROBAT = Mutation.new({
    id = "RPG_ACROBAT",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_ROGUE",
    requirements = { level = 10, stats = { DEX = 16 }, skills = { dodge = 5 } },
    stat_bonuses = { str = 0.10, dex = 0.80, int = 0.20, per = 0.40 }
  }),

  RPG_ASSASSIN = Mutation.new({
    id = "RPG_ASSASSIN",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_ROGUE",
    requirements = { level = 10, stats = { DEX = 16, PER = 14 }, skills = { dodge = 4, stabbing = 4 } },
    stat_bonuses = { str = 0.10, dex = 0.75, int = 0.35, per = 0.30 }
  }),

  RPG_ARCANE_TRICKSTER = Mutation.new({
    id = "RPG_ARCANE_TRICKSTER",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_ROGUE",
    requirements = { level = 10, stats = { DEX = 14, INT = 14 }, skills = { dodge = 4, spellcraft = 4 } },
    stat_bonuses = { str = 0.10, dex = 0.70, int = 0.55, per = 0.25 }
  }),

  RPG_DUELIST = Mutation.new({
    id = "RPG_DUELIST",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_ROGUE",
    requirements = { level = 10, stats = { DEX = 16 }, skills = { melee = 5 } },
    stat_bonuses = { str = 0.25, dex = 0.80, int = 0.20, per = 0.40 }
  }),

  -- Scout Prestige

  RPG_RANGER = Mutation.new({
    id = "RPG_RANGER",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_SCOUT",
    requirements = { level = 10, stats = { PER = 16 }, skills = { archery = 5, survival = 4 } },
    stat_bonuses = { str = 0.15, dex = 0.45, int = 0.10, per = 0.80 }
  }),

  RPG_CRAFTSMAN = Mutation.new({
    id = "RPG_CRAFTSMAN",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_SCOUT",
    requirements = { level = 10, stats = { INT = 14 }, skills = { fabrication = 5, mechanics = 4 } },
    stat_bonuses = { str = 0.20, dex = 0.30, int = 0.40, per = 0.60 }
  }),

  RPG_PATHFINDER = Mutation.new({
    id = "RPG_PATHFINDER",
    type = "class",
    symbol = "★",
    is_prestige = true,
    base_class = "RPG_SCOUT",
    requirements = { level = 10, stats = { PER = 16, DEX = 14 }, skills = { survival = 5 } },
    stat_bonuses = { str = 0.20, dex = 0.45, int = 0.15, per = 0.80 }
  }),

-- Traits
  RPG_TRAIT_BIONIC_SYMBIOTE = Mutation.new({
    id = "RPG_TRAIT_BIONIC_SYMBIOTE",
    type = "trait",
    requirements = { stats = { INT = 10 } },
    periodic_bonuses = { power_level = 2 },
  }),

  RPG_TRAIT_VITAL_ESSENCE = Mutation.new({
    id = "RPG_TRAIT_VITAL_ESSENCE",
    type = "trait",
    requirements = { level = 5, stats = { PER = 12 } },
    periodic_bonuses = { healthy_mod = 0.02 },
  }),

  RPG_TRAIT_RADIOACTIVE_BLOOD = Mutation.new({
    id = "RPG_TRAIT_RADIOACTIVE_BLOOD",
    type = "trait",
    requirements = {},
    periodic_bonuses = { rad = -0.5 },
  }),

  RPG_TRAIT_IRON_HIDE = Mutation.new({
    id = "RPG_TRAIT_IRON_HIDE",
    type = "trait",
    requirements = { level = 5, stats = { STR = 12 } },
  }),

  RPG_TRAIT_LIGHTWEIGHT = Mutation.new({
    id = "RPG_TRAIT_LIGHTWEIGHT",
    type = "trait",
    requirements = { level = 5, stats = { DEX = 12 } },
  }),

  RPG_TRAIT_PACK_MULE = Mutation.new({
    id = "RPG_TRAIT_PACK_MULE",
    type = "trait",
    requirements = { level = 5, stats = { STR = 14 } },
  }),

  RPG_TRAIT_TIRELESS = Mutation.new({
    id = "RPG_TRAIT_TIRELESS",
    type = "trait",
    requirements = { stats = { STR = 10 } },
  }),

  RPG_TRAIT_MANA_FONT = Mutation.new({
    id = "RPG_TRAIT_MANA_FONT",
    type = "trait",
    requirements = { level = 5, stats = { INT = 14 } },
  }),

  RPG_TRAIT_BLINK_STEP = Mutation.new({
    id = "RPG_TRAIT_BLINK_STEP",
    type = "trait",
    requirements = { level = 5, stats = { DEX = 14 } },
  }),

  RPG_TRAIT_NATURAL_HEALER = Mutation.new({
    id = "RPG_TRAIT_NATURAL_HEALER",
    type = "trait",
    requirements = { level = 5, stats = { PER = 12 } },
  }),

  RPG_TRAIT_ADAPTIVE_BIOLOGY = Mutation.new({
    id = "RPG_TRAIT_ADAPTIVE_BIOLOGY",
    type = "trait",
    requirements = {},
  }),

  -- Level 10 traits

  RPG_TRAIT_GLASS_CANNON = Mutation.new({
    id = "RPG_TRAIT_GLASS_CANNON",
    type = "trait",
    requirements = { level = 10, stats = { DEX = 16 } },
  }),

  RPG_TRAIT_JUGGERNAUT = Mutation.new({
    id = "RPG_TRAIT_JUGGERNAUT",
    type = "trait",
    requirements = { level = 10, stats = { STR = 18 } },
  }),

  RPG_TRAIT_ARCANE_BATTERY = Mutation.new({
    id = "RPG_TRAIT_ARCANE_BATTERY",
    type = "trait",
    requirements = { level = 10, stats = { INT = 16 } },
  }),

  RPG_TRAIT_IRON_FISTS = Mutation.new({
    id = "RPG_TRAIT_IRON_FISTS",
    type = "trait",
    requirements = { level = 5, stats = { STR = 12 } },
  }),

  RPG_TRAIT_EFFICIENT_METABOLISM = Mutation.new({
    id = "RPG_TRAIT_EFFICIENT_METABOLISM",
    type = "trait",
    requirements = {},
  }),

  RPG_TRAIT_COMBAT_REFLEXES = Mutation.new({
    id = "RPG_TRAIT_COMBAT_REFLEXES",
    type = "trait",
    requirements = { level = 5, stats = { DEX = 12 } },
  }),

  RPG_TRAIT_ACROBAT = Mutation.new({
    id = "RPG_TRAIT_ACROBAT",
    type = "trait",
    requirements = { level = 5, stats = { DEX = 14 } },
  }),

  RPG_TRAIT_TIRELESS_WORKER = Mutation.new({
    id = "RPG_TRAIT_TIRELESS_WORKER",
    type = "trait",
    requirements = { stats = { STR = 10 } },
  }),

  RPG_TRAIT_RAPID_METABOLISM = Mutation.new({
    id = "RPG_TRAIT_RAPID_METABOLISM",
    type = "trait",
    requirements = { level = 5, stats = { STR = 12 } },
  }),

  RPG_TRAIT_SCENTLESS = Mutation.new({
    id = "RPG_TRAIT_SCENTLESS",
    type = "trait",
    requirements = { stats = { PER = 10 } },
  }),

  RPG_TRAIT_CLOTTING_FACTOR = Mutation.new({
    id = "RPG_TRAIT_CLOTTING_FACTOR",
    type = "trait",
    requirements = { stats = { STR = 10 } },
  }),

  RPG_TRAIT_REGENERATOR = Mutation.new({
    id = "RPG_TRAIT_REGENERATOR",
    type = "trait",
    requirements = { level = 5, stats = { STR = 14, PER = 10 } },
  }),

  RPG_TRAIT_MASTER_CRAFTSMAN = Mutation.new({
    id = "RPG_TRAIT_MASTER_CRAFTSMAN",
    type = "trait",
    requirements = { level = 5, stats = { INT = 12, DEX = 12 } },
  }),

  RPG_TRAIT_PACK_RAT = Mutation.new({
    id = "RPG_TRAIT_PACK_RAT",
    type = "trait",
    requirements = { stats = { STR = 10 } },
  }),

  RPG_TRAIT_NATURAL_BUTCHER = Mutation.new({
    id = "RPG_TRAIT_NATURAL_BUTCHER",
    type = "trait",
    requirements = { stats = { DEX = 10, PER = 10 }, skills = { survival = 2 } },
  }),

  RPG_TRAIT_VAMPIRIC = Mutation.new({
    id = "RPG_TRAIT_VAMPIRIC",
    type = "trait",
    requirements = { level = 10, stats = { PER = 16 } },
    kill_monster_bonuses = { heal_percent = 0.5 },
  }),

  -- Level 15 traits 
  RPG_TRAIT_SHARPSHOOTER = Mutation.new({
    id = "RPG_TRAIT_SHARPSHOOTER",
    type = "trait",
    requirements = { level = 15, stats = { PER = 16, DEX = 14 }, skills = { rifle = 4, pistol = 4 } },
  }),

  RPG_TRAIT_REINFORCED_SKELETON = Mutation.new({
    id = "RPG_TRAIT_REINFORCED_SKELETON",
    type = "trait",
    requirements = { level = 15, stats = { STR = 18 } },
  }),

  RPG_TRAIT_FOCUSED_MIND = Mutation.new({
    id = "RPG_TRAIT_FOCUSED_MIND",
    type = "trait",
    requirements = { level = 15, stats = { INT = 16, PER = 14 } },
    periodic_bonuses = { morale = 50 },
  }),

  RPG_TRAIT_SILENT_STEP = Mutation.new({
    id = "RPG_TRAIT_SILENT_STEP",
    type = "trait",
    requirements = { level = 15, stats = { DEX = 16 }, skills = { dodge = 4, melee = 3 } },
  }),

  RPG_TRAIT_LIGHTNING_REFLEXES = Mutation.new({
    id = "RPG_TRAIT_LIGHTNING_REFLEXES",
    type = "trait",
    requirements = { level = 15, stats = { DEX = 18 } },
  }),

  RPG_TRAIT_GHOST_STEP = Mutation.new({
    id = "RPG_TRAIT_GHOST_STEP",
    type = "trait",
    requirements = { level = 15, stats = { DEX = 16, INT = 14 }, skills = { melee = 3, dodge = 3 } },
  }),

  -- Level 20 traits 
  RPG_TRAIT_IRON_METABOLISM = Mutation.new({
    id = "RPG_TRAIT_IRON_METABOLISM",
    type = "trait",
    requirements = { level = 20, stats = { STR = 20, PER = 16 } },
    periodic_bonuses = { rad = -0.3, healthy_mod = 0.02 },
  }),

  RPG_TRAIT_SPELL_RESONANCE = Mutation.new({
    id = "RPG_TRAIT_SPELL_RESONANCE",
    type = "trait",
    requirements = { level = 20, stats = { INT = 20 }, skills = { spellcraft = 6 } },
    periodic_bonuses = { morale = 10 },
  }),

  RPG_TRAIT_UNSTOPPABLE_FORCE = Mutation.new({
    id = "RPG_TRAIT_UNSTOPPABLE_FORCE",
    type = "trait",
    requirements = { level = 20, stats = { STR = 20, DEX = 16 }, skills = { melee = 7 } },
  }),

  RPG_TRAIT_SHADOW_CLONE = Mutation.new({
    id = "RPG_TRAIT_SHADOW_CLONE",
    type = "trait",
    requirements = { level = 20, stats = { DEX = 20, INT = 16 }, skills = { melee = 6, dodge = 5 } },
  }),

  RPG_TRAIT_RAPID_HEALER = Mutation.new({
    id = "RPG_TRAIT_RAPID_HEALER",
    type = "trait",
    requirements = { level = 20, stats = { STR = 18, PER = 16 }, skills = { firstaid = 5 } },
    periodic_bonuses = { healthy_mod = 0.05 },
  }),

    RPG_TRAIT_ENGINEER = Mutation.new({
    id = "RPG_TRAIT_ENGINEER",
    type = "trait",
    requirements = { level = 20, stats = { INT = 18, DEX = 16 }, skills = { fabrication = 6, electronics = 6, mechanics = 5 } },
  }),

  RPG_TRAIT_TACTICAL_MIND = Mutation.new({
    id = "RPG_TRAIT_TACTICAL_MIND",
    type = "trait",
    requirements = { level = 20, stats = { INT = 18, PER = 18 }, skills = { melee = 5, dodge = 5 } },
    periodic_bonuses = { morale = -20 },
  }),

  RPG_TRAIT_PRIMAL_FURY = Mutation.new({
    id = "RPG_TRAIT_PRIMAL_FURY",
    type = "trait",
    requirements = { level = 20, stats = { STR = 20, DEX = 18 }, skills = { melee = 7, unarmed = 6 } },
  }),

  -- Level 25 traits 
  RPG_TRAIT_PERFECT_BALANCE = Mutation.new({
    id = "RPG_TRAIT_PERFECT_BALANCE",
    type = "trait",
    requirements = { level = 25, stats = { DEX = 22 }, skills = { dodge = 7 } },
  }),

  RPG_TRAIT_PREDATOR = Mutation.new({
    id = "RPG_TRAIT_PREDATOR",
    type = "trait",
    requirements = { level = 25, stats = { PER = 22, DEX = 20 }, skills = { survival = 7, melee = 6 } },
  }),

  RPG_TRAIT_OVERLOAD = Mutation.new({
    id = "RPG_TRAIT_OVERLOAD",
    type = "trait",
    requirements = { level = 25, stats = { STR = 22, INT = 18 } },
  }),

  RPG_TRAIT_APEX_PREDATOR = Mutation.new({
    id = "RPG_TRAIT_APEX_PREDATOR",
    type = "trait",
    requirements = { level = 25, stats = { STR = 24, DEX = 22, PER = 18 }, skills = { melee = 9, dodge = 7 } },
    periodic_bonuses = { morale = 15 },
  }),

  -- Level 30 traits 
  RPG_TRAIT_BLOOD_ECHO = Mutation.new({
    id = "RPG_TRAIT_BLOOD_ECHO",
    type = "trait",
    requirements = { level = 30, stats = { STR = 24, PER = 22 }, skills = { melee = 9, survival = 7 } },
    periodic_bonuses = { healthy_mod = 0.08, morale = 20 },
    kill_monster_bonuses = { heal_percent = 0.3 },
  }),

  RPG_TRAIT_UNBREAKABLE = Mutation.new({
    id = "RPG_TRAIT_UNBREAKABLE",
    type = "trait",
    requirements = { level = 30, stats = { STR = 24, PER = 22 } },
  }),

  RPG_TRAIT_SHADOW_ASSASSIN = Mutation.new({
    id = "RPG_TRAIT_SHADOW_ASSASSIN",
    type = "trait",
    requirements = { level = 30, stats = { DEX = 24, PER = 22 }, skills = { melee = 9, dodge = 8, unarmed = 7 } },
  }),

  RPG_TRAIT_ESSENCE_DRAIN = Mutation.new({
    id = "RPG_TRAIT_ESSENCE_DRAIN",
    type = "trait",
    requirements = { level = 30, stats = { INT = 24, STR = 20 }, skills = { spellcraft = 9 } },
    kill_monster_bonuses = { heal_percent = 0.5 },
  }),

  RPG_TRAIT_PERFECT_CRAFTER = Mutation.new({
    id = "RPG_TRAIT_PERFECT_CRAFTER",
    type = "trait",
    requirements = { level = 30, stats = { INT = 22, DEX = 20 }, skills = { fabrication = 9, electronics = 8, mechanics = 8 } },
  }),

  -- Level 35 traits 
  RPG_TRAIT_GODSLAYER = Mutation.new({
    id = "RPG_TRAIT_GODSLAYER",
    type = "trait",
    requirements = { level = 35, stats = { STR = 26, DEX = 24, PER = 22 }, skills = { melee = 10 } },
    periodic_bonuses = { morale = 30, healthy_mod = 0.12 },
    kill_monster_bonuses = { heal_percent = 1.0 },
  }),

  RPG_TRAIT_WORLD_WALKER = Mutation.new({
    id = "RPG_TRAIT_WORLD_WALKER",
    type = "trait",
    requirements = { level = 35, stats = { PER = 26, DEX = 24 }, skills = { survival = 9, dodge = 9 } },
  }),

  RPG_TRAIT_IMMORTAL = Mutation.new({
    id = "RPG_TRAIT_IMMORTAL",
    type = "trait",
    requirements = { level = 35, stats = { STR = 24, INT = 24 } },
    periodic_bonuses = { healthy_mod = 0.15, morale = 40 },
  }),

  -- ---------- Third-tier (elite) classes ----------
  -- Note: these are is_prestige = true and set base_class to the second-tier class they evolve from.

RPG_WARLORD = Mutation.new({
    id = "RPG_WARLORD",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_BERSERKER",
    requirements = { level = 25, stats = { STR = 24, DEX = 18 }, skills = { melee = 9 } },
    stat_bonuses = { str = 1.00, dex = 0.60, int = 0.10, per = 0.30 }
  }),

  RPG_BLOOD_REAVER = Mutation.new({
    id = "RPG_BLOOD_REAVER",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_BERSERKER",
    requirements = { level = 25, stats = { STR = 24, DEX = 20 }, skills = { unarmed = 8 } },
    stat_bonuses = { str = 1.00, dex = 0.70, int = 0.10, per = 0.20 },
    attackcost_modifier = 0.80
  }),

  RPG_COLOSSUS = Mutation.new({
    id = "RPG_COLOSSUS",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_GUARDIAN",
    requirements = { level = 25, stats = { STR = 24, PER = 22 }, skills = { bashing = 8 } },
    stat_bonuses = { str = 0.90, dex = 0.15, int = 0.15, per = 0.75 },
    periodic_bonuses = { stamina = 100 }
  }),

  RPG_SENTINEL = Mutation.new({
    id = "RPG_SENTINEL",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_GUARDIAN",
    requirements = { level = 25, stats = { STR = 20, PER = 24 }, skills = { melee = 9 } },
    stat_bonuses = { str = 0.60, dex = 0.30, int = 0.20, per = 0.90 },
    armor = { { parts = "ALL", physical = 6 } }
  }),

  RPG_SPELLBLADE = Mutation.new({
    id = "RPG_SPELLBLADE",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_SPELLSWORD",
    requirements = { level = 25, stats = { STR = 22, INT = 22 }, skills = { melee = 9, spellcraft = 8 } },
    stat_bonuses = { str = 0.80, dex = 0.45, int = 0.60, per = 0.25 },
    mana_modifier = 1200,
    mana_regen_multiplier = 1.2
  }),

  RPG_ARCHMAGE = Mutation.new({
    id = "RPG_ARCHMAGE",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_MYSTIC",
    requirements = { level = 25, stats = { INT = 24, PER = 20 }, skills = { spellcraft = 10 } },
    stat_bonuses = { str = 0.10, dex = 0.20, int = 1.40, per = 0.30 },
    mana_modifier = 5000,
    mana_regen_multiplier = 1.6
  }),

  RPG_SAGE = Mutation.new({
    id = "RPG_SAGE",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_SCHOLAR",
    requirements = {
      level = 25,
      stats = { INT = 24, PER = 20 },
      skills = { fabrication = 8, electronics = 8, mechanics = 7, computer = 7 }
    },
    stat_bonuses = { str = 0.10, dex = 0.30, int = 1.10, per = 0.50 },
    mana_modifier = 2000,
    mana_regen_multiplier = 1.4
  }),

  RPG_WAR_MAGUS = Mutation.new({
    id = "RPG_WAR_MAGUS",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_BATTLEMAGE",
    requirements = { level = 25, stats = { STR = 20, INT = 22 }, skills = { spellcraft = 9, melee = 8 } },
    stat_bonuses = { str = 0.60, dex = 0.40, int = 0.80, per = 0.20 },
    mana_modifier = 2200,
    mana_regen_multiplier = 1.35,
    armor = { { parts = "ALL", physical = 4 } }
  }),

  RPG_SPELL_KNIGHT = Mutation.new({
    id = "RPG_SPELL_KNIGHT",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_BATTLEMAGE",
    requirements = { level = 25, stats = { STR = 22, INT = 20 }, skills = { fabrication = 7, spellcraft = 8 } },
    stat_bonuses = { str = 0.70, dex = 0.35, int = 0.75, per = 0.20 },
    mana_modifier = 1800,
    mana_regen_multiplier = 1.25,
    armor = { { parts = "ALL", physical = 5 } }
  }),

  RPG_WIND_DANCER = Mutation.new({
    id = "RPG_WIND_DANCER",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_ACROBAT",
    requirements = { level = 25, stats = { DEX = 24 }, skills = { dodge = 9 } },
    stat_bonuses = { str = 0.15, dex = 1.20, int = 0.20, per = 0.45 },
    movecost_modifier = 0.80,
    dodge_modifier = 8
  }),

  RPG_PHANTOM = Mutation.new({
    id = "RPG_PHANTOM",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_ACROBAT",
    requirements = { level = 25, stats = { DEX = 24 }, skills = { dodge = 9, stealth = 8 } },
    stat_bonuses = { str = 0.10, dex = 1.10, int = 0.40, per = 0.40 },
    movecost_modifier = 0.85,
    stealth_modifier = 1.8
  }),

  RPG_DEATH_STALKER = Mutation.new({
    id = "RPG_DEATH_STALKER",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_ASSASSIN",
    requirements = { level = 25, stats = { DEX = 24 }, skills = { dodge = 9, unarmed = 8 } },
    stat_bonuses = { str = 0.20, dex = 1.00, int = 0.40, per = 0.40 },
    attackcost_modifier = 0.82,
    movecost_modifier = 0.88
  }),

  RPG_VOID_DANCER = Mutation.new({
    id = "RPG_VOID_DANCER",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_ARCANE_TRICKSTER",
    requirements = { level = 25, stats = { DEX = 24, INT = 20 }, skills = { spellcraft = 9, dodge = 9 } },
    stat_bonuses = { str = 0.10, dex = 1.00, int = 0.70, per = 0.20 },
    movecost_modifier = 0.7,
    mana_modifier = 1600,
    attackcost_modifier = 0.85
  }),

  RPG_AETHER_STRIDER = Mutation.new({
    id = "RPG_AETHER_STRIDER",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_ARCANE_TRICKSTER",
    requirements = { level = 25, stats = { DEX = 22, INT = 22 }, skills = { spellcraft = 9, dodge = 8 } },
    stat_bonuses = { str = 0.10, dex = 0.90, int = 0.80, per = 0.20 },
    movecost_modifier = 0.85,
    mana_modifier = 2200,
    mana_regen_multiplier = 1.45
  }),

  RPG_BLADE_SAINT = Mutation.new({
    id = "RPG_BLADE_SAINT",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_DUELIST",
    requirements = { level = 25, stats = { DEX = 24, PER = 20 }, skills = { melee = 10, dodge = 9 } },
    stat_bonuses = { str = 0.40, dex = 1.10, int = 0.20, per = 0.30 },
    attackcost_modifier = 0.70,
    movecost_modifier = 0.9,
    dodge_modifier = 6
  }),

  RPG_HUNTER = Mutation.new({
    id = "RPG_HUNTER",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_RANGER",
    requirements = { level = 25, stats = { PER = 25, DEX = 20 }, skills = { archery = 10, survival = 9 } },
    stat_bonuses = { str = 0.30, dex = 0.70, int = 0.20, per = 0.80 },
    movecost_modifier = 0.9,
    night_vision_range = 30
  }),

  RPG_ARTIFICER = Mutation.new({
    id = "RPG_ARTIFICER",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_CRAFTSMAN",
    requirements = { level = 25, stats = { INT = 23, PER = 20 }, skills = { fabrication = 9, electronics = 9, mechanics = 9 } },
    stat_bonuses = { str = 0.30, dex = 0.40, int = 0.90, per = 0.40 },
    crafting_speed_modifier = 1.7,
    construction_speed_modifier = 1.5
  }),

  RPG_TRAILBLAZER = Mutation.new({
    id = "RPG_TRAILBLAZER",
    type = "class",
    symbol = "✦",
    is_prestige = true,
    base_class = "RPG_PATHFINDER",
    requirements = { level = 25, stats = { DEX = 24, PER = 22 }, skills = { survival = 10, dodge = 9 } },
    stat_bonuses = { str = 0.20, dex = 1.00, int = 0.20, per = 0.60 },
    movecost_modifier = 0.55
  }),

} -- MUTATIONS table end

-- Derived lists
local ALL_CLASS_IDS = {}
local ALL_TRAIT_IDS = {}
local BASE_CLASS_IDS = {}
local PRESTIGE_CLASS_IDS = {}
local STAT_BONUS_IDS = {}
local PERIODIC_BONUS_IDS = {}
local KILL_MONSTER_BONUS_IDS = {}

-- Function to register a mutation into the appropriate tracking lists
local function register_mutation(mutation)
  local mutation_id = mutation:get_mutation_id()

  if mutation.type == "class" then
    table.insert(ALL_CLASS_IDS, mutation_id)
    if mutation.is_prestige then
      table.insert(PRESTIGE_CLASS_IDS, mutation_id)
    else
      table.insert(BASE_CLASS_IDS, mutation_id)
    end
  elseif mutation.type == "trait" then
    table.insert(ALL_TRAIT_IDS, mutation_id)
  end

  if next(mutation.stat_bonuses) ~= nil then table.insert(STAT_BONUS_IDS, mutation_id) end

  if next(mutation.periodic_bonuses) ~= nil then table.insert(PERIODIC_BONUS_IDS, mutation_id) end

  if next(mutation.kill_monster_bonuses) ~= nil then table.insert(KILL_MONSTER_BONUS_IDS, mutation_id) end
end

-- Register all built-in mutations
for id, mutation in pairs(MUTATIONS) do
  register_mutation(mutation)
end

return {
  Mutation = Mutation,
  MUTATIONS = MUTATIONS,
  ALL_CLASS_IDS = ALL_CLASS_IDS,
  ALL_TRAIT_IDS = ALL_TRAIT_IDS,
  BASE_CLASS_IDS = BASE_CLASS_IDS,
  PRESTIGE_CLASS_IDS = PRESTIGE_CLASS_IDS,
  STAT_BONUS_IDS = STAT_BONUS_IDS,
  PERIODIC_BONUS_IDS = PERIODIC_BONUS_IDS,
  KILL_MONSTER_BONUS_IDS = KILL_MONSTER_BONUS_IDS,
  register_mutation = register_mutation,
}