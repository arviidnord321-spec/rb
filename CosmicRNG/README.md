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
- 27 auras in 9 tiers, each with layered 3D effects and a duel power.
- The rarest tiers are **Divine** (Stellar Phoenix 1 in 10M, Chronos 1 in 25M, Nebula Leviathan 1 in 50M) and **Transcendent** (Astral Dragon 1 in 100M, Singularity 1 in 250M, Omniverse 1 in 500M, Genesis 1 in 1 billion).
- Aura pictures (see "Adding the aura pictures" below) show:
  - above the reveal card, flicking through pictures while you roll and spinning in on the reveal
  - on every inventory card (undiscovered auras show a "?")
  - in the rare-roll banners

### Players see each other
- Name tags with aura, tier and VIP crown.
- 3D roll effects: a charge-up ring, then a burst, light pillars, sky beams and shockwaves, with 3D sound and the aura's name floating up.
- Chat tags: `[VIP]` and your equipped aura in its tier color.
- Server-wide banners and chat messages for rolls of 1 in 1,000 or rarer. Secret rolls change the sky for everyone.

### Quests & daily rewards
Open **📜 QUESTS** in the side menu. A red number shows how many rewards are waiting.
- **Daily reward:** log in every day for a 7-day streak (the window opens by itself when it's ready). Missing a day starts the streak over, and after day 7 it loops:

  | Day | Reward |
  |---|---|
  | 1 | 5 min x2 luck |
  | 2 | 3x Comet aura |
  | 3 | 1 Cosmic Roll (x50) |
  | 4 | 15 min x2 luck |
  | 5 | 2x Nebula aura |
  | 6 | 2 Cosmic Rolls |
  | 7 | 30 min x2 luck + 3 Cosmic Rolls + 1 Solar Flare aura |
- **3 daily quests:** a rolling quest plus 2 others, the same for everyone that day. Examples: roll 150 times, roll on a luck island, roll a 1 in 500 aura, finish a parkour course, win duels (bots count), hatch eggs, merge pets. Each has a progress bar and a reward (potions, Cosmic Rolls or auras for eggs).
- **Bonus chest:** finish all 3 quests for 2 Cosmic Rolls + 15 min x2 luck.
- Everything resets at midnight UTC, with a countdown in the panel. Edit the rewards and quests in the `QuestData` module.

### Cosmic Drop
- A small timer under your stats (top-left) counts down **15 minutes**.
- At 0:00 a glowing **Cosmic Roll** die lands somewhere on the main island or Lucky Isle, under a tall beam of light. Everyone gets a banner, and the timer turns into an arrow pointing at it, with the distance.
- The **first player to touch it** gets **x50 luck on their next roll** (one use, saved even if you leave). It shows in your luck line as 🎲 Cosmic Roll.
- Then the timer starts again. Settings: `Config.Drop`.

### Pets
- Every island has a **🥚 Hatchery** with 3 eggs. There are **no coins**: you pay for eggs with **auras** from your inventory.
- The first egg on an island costs a few weak auras, the second a better aura, the third an even better one. Rebirth islands have pricier eggs with much better pets:

  | Island | Egg 1 | Egg 2 | Egg 3 | Best pet |
  |---|---|---|---|---|
  | Cosmic Island | 4x Stardust | 2x Comet | 1x Nebula | Void Wisp (+100% luck) |
  | ❄️ Frostfall | 3x Aurora | 2x Pulsar | 1x Solar Flare | Polar Spirit (+150%) |
  | 🔥 Ember Isle | 2x Frostmoon | 1x Starfall | 1x Supernova | Inferno Spirit (+250%) |
  | 💠 Neon Nexus | 1x Quasar | 1x Celestial | 1x Black Hole | Nexus Overmind (+400%) |

- Press **E** at an egg to see the price, the pets, their chances and a 3D preview. Hatching plays an animation: the egg wobbles, cracks and the pet pops out.
- Equip up to **3 pets** in the **🐾 PETS** menu (or press EQUIP BEST). Every equipped pet adds luck.
- **Merging:** got 3 of the same pet? Press **MERGE 3** on its card:
  - 3 normal pets → 1 **✨ Golden** pet (shiny gold, x1.25 luck: a +24% pet becomes +30%).
  - 3 Golden pets → 1 **🌈 Rainbow** pet (cycles through every color, x1.6 luck: +24% becomes +38%).
  - A merge animation shows the 3 pets flying together. Equipped copies are swapped for the merged pet automatically.
- Pets float behind you, and everyone can see them. Each kind moves its own way: wings flap, fish wiggle, stars spin, wisps have orbiting lights, and blobs and bunnies bounce.
- Rare hatches (Legendary and up) are announced to the server. Everything is in the `PetData` module.

### Limited Offer
- A flashing **🔥 LIMITED** button with a countdown. It's on sale for **7 days after the game goes live**, and opens itself once when you join.
- Pick **ONE** of 3 very strong packs:
  - **Legend Aura Pack**: Cosmic Rift and Black Hole auras, plus a 2-hour x2 luck potion.
  - **Infinite Luck Pack**: x2 luck forever, 5 Cosmic Rolls (x50 each) and a 1-hour potion.
  - **Overlord Pet Pack**: the exclusive Cosmic Overlord pet (+300% luck), a Void Wisp and 3 Cosmic Rolls.
- The 7 days start automatically the first time a live server starts. You can also set `Config.LimitedOffer.StartTime` yourself.

### Store
Side menu (2 columns) with **LIMITED**, **DUEL**, **STORE**, **REBIRTH**, **PETS**, **QUESTS**, **TRADE** and **SOUND** buttons.

| Game pass | What it does |
|---|---|
| Auto Roll | Rolls automatically |
| Quick Roll | Rolls twice as fast |
| 2x Luck | Permanent x2 luck |
| Triple Roll | 3 auras every roll |
| Lucky Charm | Lucky roll every 5 rolls instead of every 10 |
| VIP | x1.25 luck, a gold VIP tag, the VIP Sanctum (extra x1.5 luck + daily chest), Lucky Wheel every 15 min, and trading with anyone |

| Boost (buy many times) | What it does |
|---|---|
| Luck Potion | x2 luck for you for 10 min (stacks) |
| Server Luck | x2 luck for everyone for 15 min (stacks) |

### Map
- **Cosmic Island** (start, now much bigger: radius 115):
  - Paved glowing paths from the spawn to every area (including the **Pet Hatchery**), with a signpost pointing the way.
  - Two rings of lantern gems, more crystals, rocks, mushrooms, ruins and floating crystals to fill the bigger island.
  - The **Cosmic Core** altar with spinning rings.
  - The **Top Rollers** board.
  - Benches, glow mushrooms, old marble ruins, a cosmic pool with lily lights, floating crystals and lantern gems.
  - A giant ringed planet, a moon and shooting stars in the sky.
- **The sky changes mood** on the main island every ~70 seconds, blending slowly between violet dusk, teal nebula, rose galaxy and deep indigo. Lucky Isle, Duel Island and each rebirth island have their own sky colors, and the sky blends smoothly when you travel.
- **Sky scenery around every island**, each in its own colors: glowing nebula clouds, a slowly turning spiral galaxy, and floating islets with crystals, little trees, shrines and waterfalls of light.
  - **Big sky isles** further out, each with a tiny temple, trees, crystals and a long waterfall of light.
  - **Sky creatures** everywhere, in each island's colors, each moving its own way:

    | Creature | How it moves |
    |---|---|
    | Whales with glowing spots | Slow circles, leaving a sparkle trail |
    | Manta rays | Swooping up and down, swaying their wings |
    | Jellyfish | Floating and slowly spinning |
    | Fish schools | Figure-eights |
    | Space turtles | Slow circles |
    | Koi | Figure-eights |
    | Star sprites | Spinning fast |
    | Long sky serpents | Their bodies follow the head in waves |
- The **rebirth islands are bigger** too (radius 100), with more trees, spikes, geysers, towers and palms.
- **Island details** (`WorldDetails`), each island in its own theme:
  - Glowing grass, crystal flowers, soft color patches on the ground and constellations drawn into the main island's floor.
  - Glowing vines hang under every island edge (icicles on Frostfall, lava strands on Ember Isle).
  - Waterfalls of light pour off the edges from little springs, with mist.
  - Firefly motes drift in the air (snowy motes, embers, or neon pixels on Neon Nexus).
- **Better lighting:** more stars, softer shadows, shinier glass and ice, light rays, a subtle blur on far scenery and richer bloom and contrast.
- **Sky creatures move like real animals:**
  - Whale fins flap, their tails beat up and down, and a soft shimmer surrounds them.
  - Manta wings flap with glowing ribbons from the wingtips.
  - Jellyfish bells breathe in and out, and their tentacles sway in waves.
  - Every fish in a school beats its own tail. Koi bodies wave, turtles row their flippers.
  - New: **butterfly swarms** and **lantern-fish anglers** with a glowing lure.
  - Many creatures leave glowing ribbons behind them.
  - Lucky Isle has twin golden moons, Frostfall a frozen ringed planet, Ember Isle a burning red sun and Neon Nexus a neon-ringed planet.
- **Island luck multiplies ALL your luck.** If you have x30 luck and walk onto Lucky Isle (x2), you roll with x60. A popup counts it up when you arrive (x30 → x60), and your luck line shows it as "x60 (x30 × 2 island)". Rebirth islands work the same way.
- **Lucky Isle extras:**
  - **🎡 Lucky Wheel** on the south side. Press E for a free spin every 30 minutes (every **15 with VIP**). The wheel spins and lands on your prize: luck potions, Cosmic Rolls, Comet / Nebula / Solar Flare auras, or the rare **JACKPOT: Black Hole aura**. A personal timer floats above it, and big wins are announced. Prizes and chances are in `Config.LuckyWheel`.
  - **👑 VIP Sanctum**: a floating golden terrace across a bridge off the south edge. **VIP pass only**: non-VIPs are turned back at the force-field gate and offered the pass. Inside:
    - An **extra x1.5 luck** on top of Lucky Isle's x2.
    - A golden fountain spraying sparkles.
    - A VIP throne you can sit on.
    - A **daily VIP Chest** (2 Cosmic Rolls + 15 min x2 luck + 2 Pulsar auras).
    - A trading desk and crowned obelisks.
- **Lucky Isle portal**: walk into the portal (or press **E**) to travel to **Lucky Isle**. It's white marble, gold, rose and teal, and gives **x2 luck** while you stand on it. The sky turns pink and gold while you're there, and a return portal takes you back.
  - Open to everyone. Set `Config.LuckyIsland.RequireVIP = true` to make it VIP-only.
- **Parkour** (step on the start pad to begin; the timer shows at the top):
  - **Starstep Trail** (medium): 26 small platforms with moving platforms (they carry you), spinning laser bars to jump over, vanishing platforms and a jump pad. Finishing gives **x1.75 luck for 5 min**.
  - **Void Tower** (hard): a 42-step spiral with thin beams, fast-blinking platforms, spinning lasers, moving platforms, half-deadly platforms and a jump pad. Finishing gives **x2.5 luck for 6 min**.
  - Each reward has a 10-minute cooldown.
  - **No checkpoints on any course** (the rebirth island courses too): falling, a laser or a red pad sends you back to the **start**. The old checkpoint spots are now plain rest platforms.
- **Rebirth Gate** (west of the spawn): 3 portals to the rebirth islands, and the **Rebirth Altar** (press **E** to open the rebirth menu). A locked portal shows a force field until you have enough rebirths.
- **Duel Island** (over the bridge south of the spawn): 2 arenas with force-field walls, spectator stands, braziers and live scoreboards.

### Rebirths
Open **⭐ REBIRTH** on the left (a green **!** shows when you're ready).
- To rebirth you need enough **rolls since your last rebirth** AND **one rare aura rolled since your last rebirth**. Both get harder every time:

  | Rebirth | Rolls | Rarest aura needed |
  |---|---|---|
  | 1 | 150 | 1 in 100 |
  | 2 | 330 | 1 in 400 |
  | 3 | 730 | 1 in 1,600 |
  | 4 | 1,600 | 1 in 6,400 |
  | 5 | 3,510 | 1 in 25,600 |

- **You keep all your auras.** Only the rebirth counters start over.
- Every rebirth gives **+25% luck forever**, **6% faster rolling** (up to 42%) and a star on your name tag and in chat.
- **Unlocks:**

  | Rebirth | Unlock |
  |---|---|
  | 1 | ❄️ **Frostfall Isle**: x2.5 luck, the Glacier Climb |
  | 2 | 🔥 **Ember Isle**: x3 luck, the Magma Run; 🦘 **Double Jump** |
  | 3 | 💠 **Neon Nexus**: x4 luck, the Pulse Grid; 🌠 **Rebirth Trail** |
  | 4 | 🎯 **Lucky Streak**: lucky roll every 8 rolls |
  | 5 | 🔁 **Free Auto Roll** |

- Rebirthing plays a big celebration on your screen, and everyone in the server sees a pillar of light on you plus a banner.
- **The islands**, each with its own sky color:
  - **❄️ Frostfall Isle**: snow, pine trees, a slippery frozen lake, an igloo, snowmen, ice spikes, icicles under the island, an aurora in the sky and falling snow.
  - **🔥 Ember Isle**: a smoking volcano that erupts now and then (the ground shakes), lava pools, fire geysers, obsidian spikes, burnt trees and floating embers.
  - **💠 Neon Nexus**: a neon grid floor, glowing towers with blinking antennas and spinning holo rings, neon palm trees, floating cubes, a giant striped synthwave sun and falling neon sparkles.
- **New parkour** (rewards have a 12-minute cooldown):
  - **Glacier Climb** (Frostfall): slippery ice floes you keep sliding on, then a spiral up an ice spire. Gives **x3 luck for 6 min**.
  - **Magma Run** (Ember): over a lava sea (touching it sends you back), with rocks that bob up and down, fire bars, half-lava platforms and a geyser jump pad. Gives **x4 luck for 7 min**.
  - **Pulse Grid** (Neon Nexus): a square spiral of platforms that blink in a wave, fast lasers, sliding platforms and thin beams. Gives **x5 luck for 8 min**.
- Every number is in `Config.Rebirth` and `Config.RebirthIslands`.

### Trading
- Press **🤝 TRADE** in the side menu, pick a player and send a request. They get an Accept / Decline popup.
- **At least ONE of the two players needs the 👑 VIP pass.** Players with VIP show a 👑 in the list.
- The trade window has 3 columns: **what you give**, **your stuff** (auras and pets, tap to add, −/+ to change amounts) and **what you get**.
- Both press **READY**, there's a 3-second countdown, and then everything swaps at once. Any change un-readies both players, so nobody can sneak in a switch.
- The server checks that both players still own everything before swapping, then saves both players right away. A traded-away aura or pet is taken off if you were wearing it.
- Settings: `Config.Trading` (turn the VIP rule off with `RequireVIP = false`).

### Sound settings
- The **🔊 SOUND** button opens a small panel with two sliders: **🎵 Music** (background music and the duel drum beat) and **💥 Sound effects** (everything else), from 0% to 100% in 5% steps, plus a **MUTE ALL** button.
- Your settings are saved, so they're the same next time you play.

### Signs and name tags
- Every floating sign in the world is a bit smaller, see-through, and drawn on top of objects, so a wall or platform never cuts the text off. Signs fade out more the further away you are (`NameplateStyler`).
- Player name tags are smaller and slightly see-through too.

### Sprinting
Hold **Shift** to sprint, or tap the **RUN** button on phones.
- Sprinting uses stamina; the bar is in the bottom-left. If you run it empty, you have to wait a moment before sprinting again.
- While sprinting, your view widens and speed lines and dust appear.
- Roblox's Shift Lock option is turned off, because Shift is the sprint key.
- In duels, sprinting is a little slower (x1.4).

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
- **Every aura has its own power with its own twist:**

  | Effect | Auras |
  |---|---|
  | Burns over time | Comet, Meteor, Solar Flare, Big Bang |
  | Heals over time | Aurora, Celestial |
  | Pierces shields | Quasar |
  | Reflects 40% of hits | Moonbeam |
  | Brief untouchable dodge after a dash | Twilight |
  | Stuns after a teleport | Cosmic Rift |

  The remaining auras have powers like pulls, freezes, life drain and multi-meteors.
- **Controls** (on mobile, use the on-screen buttons instead):

  | Key | Action |
  |---|---|
  | Click or **F** | Attack |
  | **Q** | Aura power |
  | Hold **G** | Block |
  | **E** | Dodge roll |
  | **Shift** | Sprint |

- **Combos:** attack quickly to chain a left jab → right cross → **roundhouse kick** (x1.8 damage plus knockback). A combo counter shows on screen.
- **Block:** basic hits do only 20% damage and powers 50%, but blocking drains a guard meter (the blue line under your HP). A kick or an empty guard causes a **GUARD BREAK**, which stuns you.
- **Dodge roll:** dash in the direction you're moving (backwards if you're standing still), untouchable for 0.35s, with a 2.2s cooldown.
- **Powers** have a short casting wind-up with a glowing charge in your hands.
- **Bots** now block and dodge too; harder bots do it more often.
- **Animations** are made in code, with no uploaded assets: a boxing guard with fists by the chin, a left jab and right cross that extend the arm all the way, a roundhouse kick, a high guard with both forearms in front of the face when blocking, a casting pose for each power type, hit recoils, block stance, dodge, stun wobble and a victory pose. Fists and feet leave trails in your aura colors, and bots get a proper walk cycle.
- **Sounds** come from a layered sound designer, so hits never sound copy-pasted: punches, heavy smashes, whooshes, metal block clangs, guard-break shatters, dodges, hurt grunts, beams, explosions, ice shatters, heal shimmers, teleports, burn crackles, a countdown beep, a fight gong and victory/defeat tunes. A **battle drum beat** plays during fights and gets faster when someone is low or time is running out.
- **Feel:** screen shake and a red flash when you get hit, a zoom punch when you land a heavy hit, and sparks and flashes at the point of impact.
- **"💀 FINISH THEM!"** appears when your opponent is low, and the screen edges glow red when you are.
- **Finisher cutscene:** the knockout hit triggers a cinematic both fighters see, with cinema bars and a moving camera:
  1. The world darkens and a spinning magic circle forms in the sky.
  2. A huge three-layer beam in the winner's aura colors strikes down, with shockwaves, flying debris, sparks, smoke and a deep boom.
  3. The loser dissolves into sparkles under an "ELIMINATED" sign, and the camera ends on the winner.

  Fire, rainbow, black-hole and dark auras each add their own touch to the cutscene. Spectators see the 3D effects too.
- 3-2-1 countdown, a 90-second limit (the higher HP % wins), and a forfeit button.
- Player-vs-player wins go on the leaderboard (**Wins**) and are announced to the server.
- You can't roll or switch auras during a fight.

### Sounds
All sounds are made from Roblox's built-in sound files, so they always work:

| Sound | Where you hear it |
|---|---|
| Soft ticks | Rolling (gentle, not hectic) |
| Soft bells and sparkles | Reveals, deeper and longer for rarer auras, with a little bell melody for Epic and up |
| Heartbeat and rumble | Cutscenes |
| Whooshes | Panels opening |
| Soft swell and bells | Joining the game |
| Chimes | New best and purchases |
| Space hum | Background |

## Scripts

| Where in Studio | Type | Name |
|---|---|---|
| ReplicatedStorage | ModuleScript | `CosmicConfig`, `AuraData`, `AuraImages`, `AuraEffects`, `CombatAnim`, `Luck`, `Rebirth`, `PetData`, `QuestData`, `SoundFX`, `UIKit` |
| ServerScriptService | Script | `RollService`, `WorldSetup`, `LuckyIsland`, `RebirthIslands`, `SkyDecor`, `WorldDetails`, `PetWorld`, `DropService`, `Parkour`, `DuelService`, `Movement`, `Leaderboard` |
| StarterPlayer > StarterPlayerScripts | LocalScript | `AuraRenderer`, `RollUI`, `StoreUI`, `WorldFX`, `ParkourClient`, `DuelClient`, `DuelFX`, `Sprint`, `RebirthClient`, `IslandFX`, `SkyFX`, `PetClient`, `DropClient`, `LimitedOffer`, `NameplateStyler`, `QuestClient`, `VipIslandClient`, `TradeClient` |
| ServerScriptService | ModuleScript | `TradeService` (started by RollService) |

## Adding the aura pictures
Starter pictures for the 7 newest auras are in `AuraPictures_New.zip` (and in `AuraImages/`). They're not in the game yet: edit them, upload them, then paste the IDs into `AuraImages` like the others. To redraw them, run `python3 tools/make_aura_images.py --new`.

Roblox can only show pictures that are uploaded to Roblox, so this is a one-time step:
1. In Studio, open **View > Asset Manager**, click **Bulk Import**, and select all 20 files from `AuraImages/Final` at once.
2. In Asset Manager > **Images**, right-click each picture, then **Copy Asset ID**.
3. Paste each number into the **AuraImages** ModuleScript, for example `["Stardust"] = 1234567890,`.

Any aura still set to `0` just shows without a picture.

## Setting up money (game passes + boosts)
1. Publish the game: **File > Publish to Roblox**.
2. Go to the Creator Dashboard, open your experience, then **Monetization**:
   - **Passes**: create the 6 passes.
   - **Developer Products**: create "Luck Potion" and "Server Luck", plus the 3 Limited Offer packs ("Legend Aura Pack", "Infinite Luck Pack", "Overlord Pet Pack") at **399 Robux** or more each.
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
- To test the Cosmic Drop fast, set `Config.Drop.IntervalMinutes = 0.5`.
- To test pets, temporarily set `Config.BaseLuck = 50` to collect auras quickly.
- To test rebirths fast, temporarily set `Config.Rebirth.BaseRolls = 5` and `Config.Rebirth.BaseRarity = 2`.
- To test as a non-VIP, set `Config.FreePassesInStudio = false`.

## Coming in later parts
- Cosmic events (Meteor Shower, Eclipse, Solar Flare)
- Index rewards
