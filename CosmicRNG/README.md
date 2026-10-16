# Cosmic RNG (Roblox)

Roll for cosmic auras, show them off, and (in a later part) fight 1v1 duels
where every aura gives you its own special power.

## Part 1: what's included
- Rolling with a spinning animation, a reveal pop, a screen flash, star bursts, camera shake and a zoom punch
- Cutscene for rolls of 1 in 10,000 or rarer (darkened screen, spinning light rays, heartbeat)
- 20 auras across 7 tiers (Common to Secret), each with layered 3D effects and a duel power
- Lucky roll every 10th roll (x2 luck)
- Auto Roll, Quick Roll and 2x Luck game passes
- Inventory showing every aura with its power and duel stats; undiscovered auras show as "???"
- Server-wide banner and chat message for rolls of 1 in 1,000 or rarer; Secret rolls change the sky for everyone
- Saving (DataStore), leaderboard (Rolls + Aura)
- Floating space island, night sky, purple atmosphere and bloom glow

## Setup (about 5 minutes)

1. Open Roblox Studio and create a new place from the **Baseplate** template.
2. Create these objects (right-click the service, **Insert Object**), rename them **exactly**, and paste in the matching file:

| Where in Studio | Object type | Name | File |
|---|---|---|---|
| ReplicatedStorage | ModuleScript | `CosmicConfig` | `ReplicatedStorage/CosmicConfig.lua` |
| ReplicatedStorage | ModuleScript | `AuraData` | `ReplicatedStorage/AuraData.lua` |
| ReplicatedStorage | ModuleScript | `AuraEffects` | `ReplicatedStorage/AuraEffects.lua` |
| ServerScriptService | Script | `RollService` | `ServerScriptService/RollService.server.lua` |
| ServerScriptService | Script | `WorldSetup` | `ServerScriptService/WorldSetup.server.lua` |
| StarterPlayer > StarterPlayerScripts | LocalScript | `AuraRenderer` | `StarterPlayerScripts/AuraRenderer.client.lua` |
| StarterPlayer > StarterPlayerScripts | LocalScript | `RollUI` | `StarterPlayerScripts/RollUI.client.lua` |

   Delete the default `print("Hello world!")` line before pasting.
3. Press **Play**. The island, sky and UI are all built by code.

### Saving progress
Saving only works after the place is published:
**File > Publish to Roblox**, then **Home > Game Settings > Security >
Enable Studio Access to API Services**. Without this, the game still runs; it just doesn't save.

### Game passes
1. Go to the Creator Dashboard, open your experience, then **Monetization > Passes**, and create "Auto Roll" (plus "Quick Roll" and "2x Luck" if you want them).
2. Copy each pass ID into `Config.GamePasses` in **CosmicConfig**.

While an ID is `0`, that pass is free in Studio so you can test it.
In the live game, nobody owns a pass whose ID is still `0`.

## Testing tips
- Want to see a Mythic or Secret cutscene right away? In CosmicConfig, temporarily set `Config.BaseLuck = 200000`, then set it back to `1`.
- Press **R** to roll on PC.
- In Studio all passes are free, so Studio luck shows **x2** (2x Luck pass).

## Coming in later parts
- 1v1 duels against players or bots, where each aura's power is usable
- Luck potions and stardust collecting
- Cosmic events (Meteor Shower, Eclipse, Solar Flare)
- Index rewards, more auras, sounds
