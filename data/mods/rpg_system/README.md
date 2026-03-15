# RPG System

A LitRPG-style progression mod for Cataclysm: Bright Nights that adds experience, leveling, classes, traits, and stat points. Compatible with existing saves.

## Features

- **Experience & Leveling**: Gain XP by killing monsters, level up to 40
- **Classes**: Start with 4 base classes, then branch into higher tiers at level 10 and level 25
- **Traits**: Unlock powerful passive abilities with stat/skill requirements
- **Stat Points**: Assign free stat points to permanently increase your stats
- **Analysis Lens**: Craft a scanner that lets you inspect nearby critters and NPCs through the System
- **Non-Player Progression**: Critters and NPCs can roll levels, gain XP, pick classes and traits, and scale with their own settings
- **Soul System**: Meaningful consequences for abandoning your chosen path

## How It Works

### Getting Started

When you start a new game or load an existing save, you'll receive a **[System Interface]** item. Use it once to integrate the System with your character. After integration, the item is no longer needed, and you can access the System via keybind.

You do **not** start with an **Analysis Lens**. If you want to inspect nearby critters and NPCs, you can craft one later once your character reaches **Fabrication 7**.

### Analysis Lens

The **Analysis Lens** is a midgame utility item that lets you inspect a nearby critter or NPC and see its current System state. That includes:

- Level and XP progress
- Effective stats
- Class and trait choices
- Class bonus scaling per level and total class contribution
- Trait slot usage
- Predicted XP on kill

Pretty much just tells the same info your system tells you about yourself. 

### Experience & Levels

- Kill monsters to gain XP based on overall threat, not just HP (unlike previous versions of the mod). Health, speed, melee, dodge, power rating, stats, and level all matter.
- XP requirement increases exponentially: **XP = 2.2387 × level^3.65**
- Maximum level: 40 (progression slows significantly after level 10)
- Normal zombies give ~7 XP

### Progression Rewards

- **Every 2 levels**: +1 stat point (assign to STR, DEX, INT, or PER)
- **Every 5 levels**: +1 trait slot
- **Level 10**: Prestige class upgrades become available

### Classes

Class progression is branch-based and now supports 3 tiers.

- **Tier 1 (base classes)**: available from the start
- **Tier 2 (prestige classes)**: unlocked at level 10
- **Tier 3 (elite classes)**: unlocked at level 25

The in-game Help screen auto-generates the class tree directly from `rpg_mutations.lua`, so third-party class additions are included automatically.

Current tree format:

```text
- BaseClass (Tier 1)
  - ChildClass (Tier 2)
    - GrandChildClass (Tier 3)
```

Use the in-game **[System] > Help** screen for the up-to-date generated tree in your current mod setup. Or just look in the lua file.

### Traits

Unlock powerful passive abilities as you level. Each trait has requirements you must meet (level, stats, or skills). Examples include:

- Iron Hide - Natural armor bonus
- Mana Font - Increased mana capacity
- Tireless - Reduced fatigue
- Glass Cannon - High damage, low defense
- And many more!

### Soul Damage System

Abandoning your class or resetting traits has consequences:

- **First reset**: Damaged Soul effect (-4 all stats, -25% speed, 3 days duration)
- **Cumulative resets**: If you reset 2 or more times within a 30-day period, your soul will **shatter**
- **Shattered Soul**: Severe penalty (-10 all stats, -40% speed, all body parts damaged to 1 HP, 6 days duration)
  - **Special**: Shattering refunds all stat points assigned via the system, allowing complete reallocation
  - This is now the only way to reset assigned stat points

Plan your builds carefully!

### Scalar Settings

You can tune progression in the System menu under **Help**. The settings are split into two pages:

- **Player Scalars**: affects your own class/trait scaling and XP gain
- **Non-Player Scalars**: affects critter/NPC XP, spawn levels, class scaling, level rewards, and background progression

Examples of available non-player settings include:

- Class benefit and penalty scalars
- Trait benefit and penalty scalars
- XP multiplier
- Passive XP and kill XP scalars
- Background leveling rate
- Spawn level chance scalar
- Speed bonus per level
- Min/max non-player level
- Levels per stat point
- Levels per trait slot

All scalar changes apply immediately and reapply active class/trait mutations.

## Balance

Worth approximately 25 character creation points. Worth much less in early game, significantly more in late game. If you want a "vanilla balanced" experience, create a character with 25 points left at the end of character creation.

**Not designed to be used with "Stats through Kills" mod** - the two systems will stack and create imbalance.

## Save Compatibility

This mod can be added to existing saves. When loaded, it will automatically initialize the System for your character with a [System Interface] item.

On game start/load, active RPG mutations are re-evaluated and reapplied. This helps existing saves pick up class/trait balance and value changes after mod updates.

Non-player progression data is initialized lazily as critters and NPCs are loaded or encountered, so existing worlds can pick up the newer non-player systems without needing a fresh start.

The mod is designed to handle missing values and should not break existing saves, if you're playing with an older version. Ofc make sure to backup, though.

## Screenshots

![System menu](https://cdn.imgchest.com/files/70905114f237.png) ![Class menu](https://cdn.imgchest.com/files/de1caa6782c7.png) ![Trait menu](https://cdn.imgchest.com/files/ae723f297ad8.png)

## XP Curve

Note: 40 is the max level, but you should not expect to get that far beyond level 10. A normal zombie gives around 7 XP.


Formula: **XP = 2.2387 × level^3.65**

| Level | Cumulative XP | XP Needed for This Level |
|------:|--------------:|-------------------------:|
| 1 | 2 | 2 |
| 2 | 28 | 26 |
| 3 | 123 | 95 |
| 4 | 353 | 230 |
| 5 | 797 | 444 |
| 6 | 1,550 | 753 |
| 7 | 2,720 | 1,170 |
| 8 | 4,429 | 1,709 |
| 9 | 6,807 | 2,378 |
| 10 | 10,000 | 3,193 |
| 11 | 14,161 | 4,161 |
| 12 | 19,454 | 5,293 |
| 13 | 26,055 | 6,601 |
| 14 | 34,148 | 8,093 |
| 15 | 43,927 | 9,779 |
| 16 | 55,595 | 11,668 |
| 17 | 69,364 | 13,769 |
| 18 | 85,456 | 16,092 |
| 19 | 104,099 | 18,643 |
| 20 | 125,532 | 21,433 |
| 21 | 150,002 | 24,470 |
| 22 | 177,762 | 27,760 |
| 23 | 209,075 | 31,313 |
| 24 | 244,212 | 35,137 |
| 25 | 283,450 | 39,238 |
| 26 | 327,076 | 43,626 |
| 27 | 375,382 | 48,306 |
| 28 | 428,670 | 53,288 |
| 29 | 487,246 | 58,576 |
| 30 | 551,428 | 64,182 |
| 31 | 621,536 | 70,108 |
| 32 | 697,900 | 76,364 |
| 33 | 780,857 | 82,957 |
| 34 | 870,751 | 89,894 |
| 35 | 967,931 | 97,180 |
| 36 | 1,072,754 | 104,823 |
| 37 | 1,185,584 | 112,830 |
| 38 | 1,306,791 | 121,207 |
| 39 | 1,436,752 | 129,961 |
| 40 | 1,575,850 | 139,098 |

## Dev notes

When you add a class or trait, keep these files in sync:

- `traits.json` (actual mutation JSON data)
- `rpg_mutations.lua` (requirements, branch structure, gameplay metadata)
- `rpg_extra_effects.lua` (display/formula values shown in the System UI)

`rpg_extra_effects.lua` runs startup validation and logs a warning if an effect label is unknown/unmapped.

Each base class should give a total of 1 stat point per level, and each prestige class should give a total of 1.5 stat points per level. In addition to stat points, classes will give unique bonuses.

A guideline for trait level requirements is 5 if the highest required stat is 12, 10 if the highest required stat is 16, and no level requirement otherwise.

### Cross-mod compatibility

If you want to add a new mod, you can call `add_mutation` from your own mod to register a new class or trait. See [here](https://github.com/mamick2006/Cataclysm-BN/releases/tag/release) for an example.

### TODOs

I am not putting these in any particular order, nor are these ideas set-in-place. I'm just literally putting my stream of consciousness in this document.

1. [PARTLY DONE] balance the exact numbers of traits and classes to make them overall more balanced 
2. [PARTLY DONE] critters and NPCs now have their own leveling system, can gain XP over time and on kills, can roll spawn levels, and can pick classes and traits. The remaining work is mostly balance work.
3. following up from previous todo, need to deal with situations in which critters choose a 'non-combat' class/trait like scholar/sage/etc. i was throwing the idea around of converting critters into npcs after enough accumulated levels + intelligence + skills? it seems actually feasible to do this because there isn't any data loss to convert them to npcs i dont think? It would also add a bunch of facinating options for other mods, too.  [MAYBE DOABLE]
4. add more onto the 'soul' mechanic. maybe there can be mobs that can damage your soul or something? maybe damaged souls should have penalties like xp loss? maybe under a lot of unhappiness or pain you have the chance of damaging your soul as a way to prevent character abuse? [MODIFIED CURRENT LEVELING IMPLEMENTATION SO DECREASING LEVELS DOESNT BREAK YOUR GAME. I THINK THAT THIS IS DOABLE THOUGH; I ALREADY ADDED 'level upper' AND 'level downer' DEBUG EFFECTS; JUST NEED TO FIND SITUATIONS TO USE THEM.]
