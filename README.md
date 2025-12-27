# 🎮 Dreamfield

A Roblox game with combat, shards, corruption mechanics, and dual worlds.

## Features

- **Combat:** LMB combo (1-2-3), F parry, Q dash, Shift sprint
- **Shards:** Equip 5 shard skills (1-5 keys) with corruption mechanics
- **Inventory:** TAB open, E equip, weight & slot limits
- **Corruption:** Shard overload prevention, tolerance system
- **Worlds:** Ruined Earth & Dreamfield dual world system

## Project Structure

```
DREAMFIELD/
├── src/
│   ├── client/
│   ├── server/
│   └── shared/
│       ├── TestFramework.luau
│       ├── PlayerData.luau
│       ├── Inventory.luau
│       └── ShardEquip.luau
├── .luaurc.json
├── sourcemap.json
├── default.project.json
├── aftman.toml
└── README.md
```

## Setup

1. Clone: `git clone https://github.com/EinorDane/GameDev.git`
2. Install: `aftman install`
3. Serve: `rojo serve`
4. In Studio: Click Rojo plugin → Connect → Play

## TIER 1 Status

✅ **Complete** - 35/35 tests passing

- TestFramework (450 lines)
- PlayerData (500 lines)
- Inventory (550 lines)
- ShardEquip (550 lines)
- QuickTest (650 lines)

**Total:** 2,700+ lines of production code

## Tech Stack

- Language: Luau (!strict mode)
- Editor: VS Code + Roblox LSP
- Sync: Rojo
- Testing: Custom TestFramework
