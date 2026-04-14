# NetService

A lightweight static remote event wrapper for Roblox. Auto-detects server/client context, supports RemoteGuard integration, and provides clean connection management.

---

## Installation

Drop `NetService.luau` into your packages folder and require it on both server and client.

---

## Setup

```lua
local Net=require(path.to.NetService)
```

No instantiation needed — `Net` is a static module.

---

## Methods

### Static

| Method | Side | Description |
|---|---|---|
| `Net.on(remote)` | Both | Listen for incoming calls, returns chain |
| `Net.fire(remote, player, ...)` | Both | Server fires to player, client fires to server |
| `Net.fire_all(remote, ...)` | Server | Fire to all players |
| `Net.fire_except(remote, exceptions, ...)` | Server | Fire to all except listed UserIds |

### Chain (on `.on()`)

| Method | Description |
|---|---|
| `:Guard(remoteGuard)` | Attach a RemoteGuard instance, server only |
| `:Connect(fn)` | Hook callback, chain terminator |
| `:Once(fn)` | Fires once then auto-disconnects |
| `:Cleanup()` | Disconnect all active connections |

---

## Usage

### Server

```lua
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Net=require(ReplicatedStorage.Packages.NetService)
local RemoteGuard=require(ReplicatedStorage.Packages.RemoteGuard)

local purchaseRemote=ReplicatedStorage.Remotes.PurchaseItem

-- listen with guard
Net.on(purchaseRemote)
	:Guard(
		RemoteGuard.new(purchaseRemote)
			:SetCooldown(1)
			:SetAliveRequirement(true)
			:TerminateCallback(function(player)
				player:Kick('Exploiting detected.')
			end)
	)
	:Connect(function(player, itemId)
		print(`{player.Name} purchasing {itemId}`)
	end)

-- fire to specific player
Net.fire(purchaseRemote, player, 'purchase_success')

-- fire to all
Net.fire_all(purchaseRemote, 'server_message')

-- fire to all except one player
Net.fire_except(purchaseRemote, {player.UserId}, 'other_player_purchased')

-- listen once
Net.on(purchaseRemote):Once(function(player, itemId)
	print(`first purchase: {itemId}`)
end)
```

### Client

```lua
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Net=require(ReplicatedStorage.Packages.NetService)

local purchaseRemote=ReplicatedStorage.Remotes.PurchaseItem

-- fire to server
Net.fire(purchaseRemote, nil, 'sword_of_doom')

-- listen for server response
Net.on(purchaseRemote):Connect(function(result)
	print(`Server responded: {result}`)
end)
```

### Cleanup

```lua
local listener=Net.on(purchaseRemote):Connect(function(player, itemId)
	print(`{player.Name} purchasing {itemId}`)
end)

-- disconnect all listeners on this chain
listener:Cleanup()
```

---

## RemoteGuard Integration

`:Guard()` accepts a `RemoteGuard` instance. All validation runs inside RemoteGuard, your callback only fires if every check passes.

```lua
Net.on(remote)
	:Guard(
		RemoteGuard.new(remote)
			:SetCooldown(0.5)
			:SetCharacterRequirement(true)
			:SetDistanceRequirement({
				Position=workspace.Boss.PrimaryPart.Position,
				Range=20,
			})
	)
	:Connect(function(player)
		print(`{player.Name} is in range`)
	end)
```

---

## Notes

- `Net.on()` auto-detects server vs client, same API on both sides
- `:Guard()` is server-only — attaching a guard on the client has no effect
- `fire_except` takes a table of `UserId` numbers, not Player instances
- Guards attached via `:Guard()` manage their own connections and are not tracked by `:Cleanup()`

---

## License

MIT © 2026 @kts
