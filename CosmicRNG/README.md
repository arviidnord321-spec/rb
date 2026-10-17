# Cosmic RNG (Roblox)

Roll for cosmic auras, show them off, and (in a later part) fight 1v1 duels
where every aura gives you its own special power.

## Easiest setup: open the ready-made place file

1. Download `CosmicRNG.rbxlx`.
2. In Roblox Studio: **File > Open from File...** and pick `CosmicRNG.rbxlx`.
3. Press **Play**.

All scripts are already in the right places. If you made changes in an older
copy, open the new file anyway and copy your changes over (for example your
game pass IDs in `CosmicConfig`).

## What's in the game

### Rolling
- Roll animation:
  - Names flick past on a glowing card that changes color with each one, with tick sounds rising in pitch.
  - The reveal has a pop, a shine sweep, a wiggle, a flash, star bursts, camera shake and a zoom punch.
- Cutscene for rolls of 1 in 10,000 or rarer: darkened screen, spinning light rays, heartbeat sounds and a rumble.
- Camera showcase: the camera circles your character to show off rolls of 1 in 10,000 or rarer.
- Confetti and a chime on a new best. A "NEW!" badge on first-time auras.
- Lucky roll every 10th roll (every 5th with Lucky Charm).

### Auras
- 20 auras in 7 tiers, each with layered 3D effects and a duel power.
- Aura pictures (see "Adding the aura pictures" below) show:
  - above the reveal card, flicking through pictures while you roll and spinning in on the reveal
  - on every inventory card (undiscovered auras show a "?")
  - in the rare-roll banners

### Players see each other
- Name tags with aura, tier and VIP crown.
- 3D roll effects: a charge-up ring, then a burst, light pillars, sky beams and shockwaves, with 3D sound and the aura's name floating up.
- Chat tags: `[VIP]` and your equipped aura in its tier color.
- Server-wide banners and chat messages for rolls of 1 in 1,000 or rarer. Secret rolls change the sky for everyone.

### Store
Side menu with **STORE** and **SOUND** (mute) buttons.

| Game pass | What it does |
|---|---|
| Auto Roll | Rolls automatically |
| Quick Roll | Rolls twice as fast |
| 2x Luck | Permanent x2 luck |
| Triple Roll | 3 auras every roll |
| Lucky Charm | Lucky roll every 5 rolls instead of every 10 |
| VIP | x1.25 luck and a gold VIP tag |

| Boost (buy many times) | What it does |
|---|---|
| Luck Potion | x2 luck for you for 10 min (stacks) |
| Server Luck | x2 luck for everyone for 15 min (stacks) |

### Map
- **Cosmic Island** (start):
  - Paved glowing paths from the spawn to every area, with a signpost pointing the way.
  - The **Cosmic Core** altar with spinning rings.
  - The **Top Rollers** board.
  - Benches, glow mushrooms, old marble ruins, a cosmic pool with lily lights, floating crystals and lantern gems.
  - A giant ringed planet, a moon and shooting stars in the sky.
- **Lucky Isle portal**: walk into the portal (or press **E**) to travel to **Lucky Isle**. It's white marble, gold, rose and teal, and gives **x2 luck** while you stand on it. The sky turns pink and gold while you're there, and a return portal takes you back.
  - Open to everyone. Set `Config.LuckyIsland.RequireVIP = true` to make it VIP-only.
- **Parkour** (step on the start pad to begin; the timer shows at the top):
  - **Starstep Trail** (easy): a curving staircase of floating platforms with 2 checkpoints, vanishing platforms and a jump pad. Finishing gives **x1.5 luck for 5 min**.
  - **Void Tower** (hard): a spiral around a dark tower with thin beams, blinking platforms, half-deadly platforms (red = back to checkpoint) and a jump pad. Finishing gives **x2 luck for 5 min**.
  - Each reward has a 10-minute cooldown. Falling puts you back at your last checkpoint.
- **Duel Island** (over the bridge south of the spawn): 2 arenas with force-field walls, spectator stands, braziers and live scoreboards.

### 1v1 Duels
- Open the **⚔ DUEL** menu (left side) and **challenge** any player (they get Accept/Decline), or fight a **bot**:

  | Bot | Aura it uses |
  |---|---|
  | Easy | Moonbeam |
  | Normal | Pulsar |
  | Hard | Supernova |
  | Nightmare | Black Hole |

- **Your equipped aura is your fighter.** Its tier sets your HP and attack damage, and each aura's power has its own effect:

  | Tier | HP | Attack damage |
  |---|---|---|
  | Common | 100 | 6 |
  | Uncommon | 115 | 7 |
  | Rare | 130 | 8 |
  | Epic | 150 | 10 |
  | Legendary | 175 | 12 |
  | Mythic | 210 | 14 |
  | Secret | 260 | 17 |

  Rarer auras also have much stronger powers. Stardust's Star Toss does 8 damage; Void Sovereign's Void Collapse does 100 and freezes the opponent.
- **Controls:** click or **F** to attack, **Q** for your aura power, or use the on-screen ATTACK and POWER buttons on mobile.
- 3-2-1 countdown, a 90-second limit (the higher HP % wins), and a forfeit button.
- Player-vs-player wins go on the leaderboard (**Wins**) and are announced to the server.
- You can't roll or switch auras during a fight.

### Sounds
All sounds are made from Roblox's built-in sound files, so they always work:

| Sound | Where you hear it |
|---|---|
| Ticks | Rolling and button clicks |
| Booms | Reveals, deeper for rarer auras |
| Heartbeat and rumble | Cutscenes |
| Whooshes | Panels opening |
| Chimes | New best and purchases |
| Space hum | Background |

## Scripts

| Where in Studio | Type | Name |
|---|---|---|
| ReplicatedStorage | ModuleScript | `CosmicConfig`, `AuraData`, `AuraImages`, `AuraEffects`, `Luck`, `SoundFX`, `UIKit` |
| ServerScriptService | Script | `RollService`, `WorldSetup`, `LuckyIsland`, `Parkour`, `DuelService`, `Leaderboard` |
| StarterPlayer > StarterPlayerScripts | LocalScript | `AuraRenderer`, `RollUI`, `StoreUI`, `WorldFX`, `ParkourClient`, `DuelClient`, `DuelFX` |

## Adding the aura pictures
Roblox can only show pictures that are uploaded to Roblox, so this is a one-time step:
1. In Studio, open **View > Asset Manager**, click **Bulk Import**, and select all 20 files from `AuraImages/Final` at once.
2. In Asset Manager > **Images**, right-click each picture, then **Copy Asset ID**.
3. Paste each number into the **AuraImages** ModuleScript, for example `["Stardust"] = 1234567890,`.

Any aura still set to `0` just shows without a picture.

## Setting up money (game passes + boosts)
1. Publish the game: **File > Publish to Roblox**.
2. Go to the Creator Dashboard, open your experience, then **Monetization**:
   - **Passes**: create the 6 passes.
   - **Developer Products**: create "Luck Potion" and "Server Luck".
3. Paste each ID into `CosmicConfig` (`Config.GamePasses` and `Config.Products`).

While an ID is `0`, that item is free in Studio so you can test it. In the
live game nobody can buy an item whose ID is still `0`.

## Saving progress
Saving and the global leaderboard need the place to be published:
**File > Publish to Roblox**, then **Home > Game Settings > Security >
Enable Studio Access to API Services**.

## Better sounds (optional)
1. In Studio, open **Toolbox > Audio** and search for a sound (for example "whoosh", "magic chime" or "heartbeat").
2. Right-click it, then **Copy Asset ID**.
3. Paste it into `Config.SoundOverrides` in CosmicConfig, for example:
   `RevealLegendary = "rbxassetid://1234567890",`

`Config.AmbientMusic` works the same way for background music.

## Testing tips
- Want to see a Mythic or Secret cutscene right away? In CosmicConfig, temporarily set `Config.BaseLuck = 200000`, then set it back to `1`.
- Press **R** to roll on PC.
- In Studio all passes are free, so Studio luck shows **x2.5** (2x Luck + VIP), or **x5** on Lucky Isle. Boost buttons in the Store activate for free in Studio too.
- To test player-vs-player duels in Studio: **Test > Clients and Servers**, pick 2 players, then **Start**.
- To test as a non-VIP, set `Config.FreePassesInStudio = false`.

## Coming in later parts
- Cosmic events (Meteor Shower, Eclipse, Solar Flare)
- Index rewards, more auras (when you say so)
