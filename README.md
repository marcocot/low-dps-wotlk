# LowDPS - Shame Alert (WotLK 3.3.5)

A World of Warcraft addon for WotLK that shames you when you die last in DPS inside an instance.

## What it does

When you are inside a dungeon or raid:
1. You die
2. The addon checks Details! Damage Meter for your DPS ranking
3. If you are **last in DPS**, it triggers:
   - A big red on-screen warning: **"HAI UN DPS TROPPO BASSO!"**
   - A full-screen red flash effect
   - A chat message with your exact DPS and ranking
   - A warning sound (custom or built-in)

## Requirements

- WoW WotLK 3.3.5 client
- [Details! Damage Meter](https://www.curseforge.com/wow/addons/details) installed and active

## Installation

1. Copy the `LowDPS` folder into your WoW addons directory:
   ```
   World of Warcraft/Interface/AddOns/LowDPS/
   ```
2. Make sure the folder contains:
   ```
   LowDPS/
   ├── LowDPS.toc
   ├── LowDPS.lua
   └── Sounds/
       └── low_dps.ogg  (optional - custom voice file)
   ```
3. Restart WoW or type `/reload` in-game

## Custom Sound

To add a custom voice saying "HAI UN DPS TROPPO BASSO":

1. Record or generate an `.ogg` audio file with the phrase
2. Place it at `LowDPS/Sounds/low_dps.ogg`
3. The addon will automatically use it instead of the default raid warning sound

If no custom sound file is found, the built-in raid warning sound plays instead.

## Slash Commands

| Command | Description |
|---|---|
| `/lowdps` | Show help |
| `/lowdps on` | Enable the addon |
| `/lowdps off` | Disable the addon |
| `/lowdps sound on` | Enable sound |
| `/lowdps sound off` | Disable sound |
| `/lowdps test` | Test the warning (works anywhere) |
| `/lowdps status` | Show current status and DPS info |

You can also use `/ldps` as a shortcut.

## How the DPS Check Works

1. On `PLAYER_DEAD` event, the addon waits 0.5s for Details! to update
2. It reads the current (or last) combat segment from Details!
3. It collects all player actors and their DPS from the damage container
4. It ranks them from highest to lowest
5. If you are in the last position (configurable via `threshold`), it triggers the warning
