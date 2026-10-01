# Better Sentry Reloader

A quality-of-life mod for **PAYDAY 2** (SuperBLT) that allows you to instantly reload your deployed sentry guns with a single key press, without having to pick them up, redeploy them, and re-toggle AP ammo mode.

---

## Features

- **One-Button Reloading**: Aim at or stand near your sentry gun and tap your custom reload key.
- **Skill & Perk Integration**: Automatically uses your Technician perks (**Eco Sentry** & **Third Law**):
  - **No Perks**: Costs 30% of weapon ammo for a 0% to 100% refill.
  - **Eco Sentry Basic**: Placement cost reduction applied (costs 25% of weapon ammo).
  - **Eco Sentry Aced**: Maximum placement cost reduction applied (costs only 20% of weapon ammo).
  - **Proportional Refills**: If your sentry gun only used 25% of its ammo, reloading it only consumes 25% of the placement cost (e.g., only 5% of your weapon ammo with Eco Sentry Aced)!
- **Maintains AP Ammo Mode**: Unlike vanilla pickup-and-place (which resets the sentry to normal fire mode), your sentry gun **remains in Armor-Piercing (AP) mode** after reloading.
- **Mod Options Menu**:
  - **Targeting Mode**:
    - *Aimed (Crosshair)*: Reloads the sentry gun you are looking at.
    - *Closest*: Reloads the nearest sentry to you.
    - *All in Range*: Reloads all your sentries within range simultaneously.
  - **Max Range**: Slider from 2 meters to 50 meters.
  - **Teammate Sentry Option**: Allow reloading teammates' sentry guns with your ammo.
  - **Repair Option**: Optionally repair sentry health to full when reloading.
  - **Sound & HUD Notifications**: Clear on-screen hints and audio feedback displaying bullets used.
- **Full Multiplayer Safety**: Works whether you are the **Host** or a **Client/Guest** joining another player's lobby.

---

## Installation

1. Ensure you have **SuperBLT** installed for PAYDAY 2.
2. Copy this entire folder (`Better-Sentry-Reloader`) into your PAYDAY 2 mods folder:
   ```
   C:\Program Files (x86)\Steam\steamapps\common\PAYDAY 2\mods\Better-Sentry-Reloader
   ```

---

## How to Set Up the Keybind

1. Launch PAYDAY 2.
2. In the main menu, go to:
   **Options** ➔ **Mod Keybinds**
3. Locate **Better Sentry Reloader** and find **Reload Sentry Gun**.
4. Bind it to your preferred key (e.g. `R`, `T`, `G`, or Mouse 4/5).

---

## Mod Options

You can adjust all settings at any time in-game:
**Options** ➔ **Mod Options** ➔ **Better Sentry Reloader**
