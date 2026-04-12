# PlayerService

A lightweight, typed player lifecycle tracker for Roblox. Tracks joins and leaves, exposes reactive observation, and manages its own cleanup.

---

## Installation

Drop `AnimationService.luau` into your project and require it.

```luau
local PlayerService = require(path.to.AnimationService)
```

---

## Quick Start

```luau
local service = PlayerService.new()

service:ObserveAdded(function(player)
    print(player.Name, "is in the server")
end)

service.removing:Connect(function(player)
    print(player.Name, "is leaving")
end)
```

---

## Constructor

### `PlayerService.new()` → `ServiceObject`

Creates a new service instance. On construction it:

- Connects to `Players.PlayerAdded` and `Players.PlayerRemoving`
- Synchronously binds all players already in the server
- Fires `added` for each existing player so observers never miss early joins

```luau
local service = PlayerService.new()
```

---

## Methods

### `:GetPlayer(player)` → `boolean?`

Returns `true` if the player is currently tracked, `nil` otherwise.

```luau
if service:GetPlayer(player) then
    -- player is in the server
end
```

---

### `:GetAllPlayers()` → `{ Player }`

Returns an array of all currently tracked players.

```luau
for _, player in service:GetAllPlayers() do
    print(player.Name)
end
```

---

### `:ObserveAdded(fn)` → `Connection`

The most important method. Fires `fn` immediately for every player already in the server, then fires it again for every future join. This means you never need to call `:GetAllPlayers()` and `:Connect` separately.

```luau
service:ObserveAdded(function(player)
    setupPlayerData(player)
end)
```

Without `ObserveAdded` you would need two steps with a race condition between them:

```luau
-- fragile — player can join between these two lines
for _, player in service:GetAllPlayers() do
    setupPlayerData(player)
end
service.added:Connect(setupPlayerData)
```

`ObserveAdded` collapses this into one safe call.

The returned `Connection` can be disconnected to stop observing future joins. Players already processed are not un-processed.

```luau
local conn = service:ObserveAdded(fn)
conn:Disconnect()
```

---

### `:Cleanup()`

Tears down the service fully. Disconnects all `Players` event connections, clears all signal listeners, and empties the player map. Call this when the service is no longer needed.

```luau
service:Cleanup()
```

---

## Signals

Signals are exposed as public fields and can be connected to directly.

### `service.added` — `Signal<Player>`

Fires when a player joins and is added to the map.

```luau
service.added:Connect(function(player)
    print(player.Name, "joined")
end)
```

### `service.removing` — `Signal<Player>`

Fires when a player is about to leave, before they are removed from the map.

```luau
service.removing:Connect(function(player)
    saveData(player)
end)
```

Both signals support `:Connect(fn)` → `Connection` and `:DisconnectAll()`.

---

## Types

```luau
export type Connection = {
    Connected: boolean,
    Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
    Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    Fire: (self: Signal<T...>, T...) -> (),
    DisconnectAll: (self: Signal<T...>) -> (),
}

export type ServiceObject = {
    added:        Signal<Player>,
    removing:     Signal<Player>,
    _map:         { [Player]: boolean },
    _connections: { RBXScriptConnection },
    GetPlayer:    (self: ServiceObject, player: Player) -> boolean?,
    GetAllPlayers:(self: ServiceObject) -> { Player },
    ObserveAdded: (self: ServiceObject, fn: (player: Player) -> ()) -> Connection,
    Cleanup:      (self: ServiceObject) -> (),
}
```

---

## Notes

- `added` fires before `PlayerAdded` listeners connected after construction, because existing players are bound synchronously in `new()` before any external code runs.
- `removing` fires before the player is removed from `_map`, so `GetPlayer` still returns `true` inside a `removing` callback — useful for final data saves.
- The internal `Signal` implementation clones the listener array before firing, so connecting or disconnecting inside a callback is safe.
- `_map` and `_connections` are prefixed with `_` to signal they are internal — avoid mutating them directly.

---

## License

MIT — @kts
