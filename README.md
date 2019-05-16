# NPC Respawn

**Caution:** This mod is in early development stage. Scripts can break, mod logic can change greatly with new versions.
I really need your feedback on mod: what features do you want to see and what I need to implement to make integration with your mods easy.

**Features:**
* NPC ships such as military, defenders, carriers and miners (in that order) will respawn over time if sector is being controlled by NPC faction.
* Destroyed stations will respawn one after another after delay.
* Fixes NPC miners not being able to mine because they lack captains (new miners only).

**Commands:**

If you're server admin, you can use following commands to override sector settings.
Replace `miningfield` with desired sector type. If you don't provide sector type, it will be reset to default:
```
/npcrespawn type miningfield
/npcrespawn type
```

Set ship type respawn amount. You can use defender, military, carrier or miner as a ship type. Second value is desired amount. If amount is not specified, setting will be reset to default:
```
/npcrespawn defender 4
/npcrespawn miner
```

Enable(true) or disable(false) station respawn. If you don't provide second argument, setting will be reset to default.

```
/npcrespawn station false
/npcrespawn station
```

**Config files locations:**

Client - `AppData/Roaming/Avorion/moddata/NPCRespawn.lua`

Server - `AppData/Roaming/Avorion/galaxies/(GalaxyName)/moddata/NPCRespawn.lua`
