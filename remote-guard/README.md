# RemoteGuard

Middleware-style remote security for Roblox. Validates incoming remote calls on the server before they reach your game logic.

---

## Installation

Drop `RemoteGuard.luau` into your packages folder and require it server-side.

---

## Setup

```lua
local RemoteGuard=require(path.to.RemoteGuard)

RemoteGuard.new(remote)
	:SetCooldown(1)
	:SetAliveRequirement(true)
	:SetCharacterRequirement(true)
	:TerminateCallback(function(player)
		player:Kick('Exploiting detected.')
	end)
	:Connect(function(player, ...)
		-- safe, validated data
	end)
```

> RemoteGuard is **server-only**. Clients fire remotes as normal.

---

## Methods

All methods return `self` and can be chained. `:Connect()` must always be last.

| Method | Args | Description |
|---|---|---|
| `RemoteGuard.new(remote)` | `RemoteEvent\|RemoteFunction` | Creates a new guard instance |
| `:SetCooldown(seconds)` | `number` | Rate limits per player |
| `:SetAliveRequirement(r)` | `boolean` | Player's humanoid must be alive |
| `:SetCharacterRequirement(r)` | `boolean` | Player must have a character |
| `:SetDistanceRequirement(r)` | `{Position: Vector3, Range: number}` | Player must be within range of a position |
| `:TerminateCallback(fn)` | `(player: Player) -> ()` | Called on any validation failure |
| `:Connect(fn)` | `(player: Player, ...any) -> ()` | Hooks the remote. Chain terminator |

---

## Usage

### Server

```lua
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local RemoteGuard=require(ReplicatedStorage.Packages.RemoteGuard)

-- Rate limit + alive check
RemoteGuard.new(ReplicatedStorage.Remotes.PurchaseItem)
	:SetCooldown(1)
	:SetAliveRequirement(true)
	:SetCharacterRequirement(true)
	:TerminateCallback(function(player)
		player:Kick('Exploiting detected.')
	end)
	:Connect(function(player, itemId)
		print(`{player.Name} purchasing {itemId}`)
	end)

-- Distance check to prevent firing from across the map
RemoteGuard.new(ReplicatedStorage.Remotes.Attack)
	:SetCooldown(0.5)
	:SetAliveRequirement(true)
	:SetDistanceRequirement({
		Position=workspace.Boss.PrimaryPart.Position,
		Range=20,
	})
	:Connect(function(player)
		print(`{player.Name} attacked the boss`)
	end)
```

### Client

```lua
local ReplicatedStorage=game:GetService('ReplicatedStorage')

-- RemoteGuard is server-only, client fires as normal
ReplicatedStorage.Remotes.PurchaseItem:FireServer('sword_of_doom')
ReplicatedStorage.Remotes.Attack:FireServer()
```

---

## Validation Order

First failure exits early and fires `TerminateCallback`:

1. Character
2. Alive
3. Distance

---

## Notes

- Works with `RemoteEvent` and `RemoteFunction`
- Player cache is automatically cleaned up on leave
- `:Connect()` must be called from the server — errors otherwise
- `TerminateCallback` defaults to a no-op if not set

---

## License

MIT © 2026 @kts
