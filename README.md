# LunaCoreNBT
An NBT Writer/Reader for LunaCoreAPI. Allowing for modding of `*.vdb` and `*level.dat` files/data and more in realtime.

## Installing:
- Install it as the same meathod as `LunaCoreAPI`.
  - You should have the `PATH` of `.\Minecraft 3DS\mods\LunaCoreNBT`.
  - Verify you installed it properly by double checking the `.\LunaCoreNBT` directory, and making sure `mod.json` and `init.lua` are there.
- To get started with `LunaCoreNBT`, you will need to add it as a dependancy to your Mod/Script.
  - If you're writing a Mod, open `mod.json` and append the list of dependacies with `LunaCoreNBT`.
    - It should be similar to: `"dependencies": ["LunaCoreAPI", "LunaCoreNBT"]`
  - If you're using a script, you can call it directly. Or use ```local NBT = require("LunaCoreNBT")```for safer operation.

 ## Example Usage:
 ```lua
local NBT = require("LunaCoreNBT")
local root = NBT.loadFile("sdmc:/level.dat", { -- Should be easily able to modify these inside of ExtData with LunaCoreAPI calling it.
    long_as = "string",
})

Core.Debug.message(NBT.getChild(root, "LevelName").value) -- Prints the World Name to the Screen using LunaCoreAPI

NBT.getChild(root, "LevelName").value = "Example World Edit" - Edits the World Name to 'Example World Edit'
NBT.setChild(root, NBT.newInt("SpawnX", 100))
NBT.setChild(root, NBT.newInt("SpawnY", 64))
NBT.setChild(root, NBT.newInt("SpawnZ", 100))

NBT.saveFile("sdmc:/level_out.dat", root) -- Saves using the same detected format/header version.
```
