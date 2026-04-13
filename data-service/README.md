# DataService

A lightweight, reusable Roblox DataStore controller with session caching, auto-reconciliation, and safe save-on-close.

---

## Installation

Drop `DataService.luau` into `ServerScriptService` or wherever your server modules live.

---

## Setup

```lua
local DataService = require(path.to.DataService)

local Data = DataService.new("PlayerData", {
    Cash = 50,
    Level = 1,
    Stats = {
        Kills = 0,
        Deaths = 0,
    },
})
```

`DataService.new(name, template)`

| Parameter  | Type      | Description                                      |
|------------|-----------|--------------------------------------------------|
| `name`     | `string`  | DataStore name                                   |
| `template` | `Profile?` | Default data for new players. Defaults to `{Cash=50}` |

---

## Loading Data

Call on `Players.PlayerAdded`. Uses the player's `UserId` as the key.

```lua
Players.PlayerAdded:Connect(function(player)
    local profile = Data:LoadProfile(player, tostring(player.UserId))
    if not profile then
        player:Kick("Failed to load data.")
    end
end)
```

---

## Saving Data

Call on `Players.PlayerRemoving`. `BindToClose` is handled automatically.

```lua
Players.PlayerRemoving:Connect(function(player)
    Data:SaveProfile(player, tostring(player.UserId))
end)
```

---

## Reading & Writing

```lua
-- Read
local profile = Data:GetProfile(player)
print(profile.Cash)

-- Write (mutate directly — cache is live)
profile.Cash += 100
profile.Stats.Kills += 1
```

Changes are written to the DataStore on the next `SaveProfile` call.

---

## All Profiles

```lua
for player, profile in Data:GetAllProfiles() do
    print(player.Name, profile.Cash)
end
```

---

## Reconciliation

New keys added to your template are automatically filled in for existing players on load — old values are never overwritten.

```lua
-- Before: player has { Cash=200 }
-- Template now has { Cash=50, Level=1 }
-- After load: player has { Cash=200, Level=1 }
```

---

## API

| Method | Returns | Description |
|---|---|---|
| `DataService.new(name, template?)` | `DataService` | Creates a new service instance |
| `:LoadProfile(player, key)` | `Profile?` | Loads from DataStore into cache |
| `:SaveProfile(player, key)` | `()` | Saves cache to DataStore |
| `:GetProfile(player)` | `Profile?` | Returns cached profile |
| `:GetAllProfiles()` | `{[Player]: Profile}` | Returns entire cache |

---

## Types

```lua
export type Profile = {[string]: any}

export type DataService = {
    ProfileCache: {[Player]: Profile},
    Data: DataStore,
    Template: Profile,
    LoadProfile: (self: DataService, player: Player, key: string) -> Profile?,
    SaveProfile: (self: DataService, player: Player, key: string) -> (),
    GetProfile: (self: DataService, player: Player) -> Profile?,
    GetAllProfiles: (self: DataService) -> {[Player]: Profile},
}
```

---

## License

MIT © 2026 @kts
