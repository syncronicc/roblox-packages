# TimerService

A lightweight, signal-driven countdown timer for Roblox with pause/resume, time-scaling, and safe cleanup.

---

## Installation

Copy `TimerService.luau` into your project (e.g. `ServerScriptService` or a shared `Modules` folder) and require it.

```lua
local TimerService = require(path.to.TimerService)
```

---

## Quick Start

```lua
local timer = TimerService.new()

timer.Signals.Tick:Connect(function(elapsed)
    print("Elapsed:", elapsed)
end)

timer.Signals.Finished:Connect(function()
    print("Timer finished!")
end)

timer:Start(10) -- counts for 10 seconds
```

---

## API

### `TimerService.new()` → `TimerService`

Creates a new timer instance.

```lua
local timer = TimerService.new()
```

---

### `:Start(seconds: number)` → `self`

Starts the timer for the given duration. If the timer is already running, the previous run is cancelled and a new one begins immediately.

```lua
timer:Start(30)
```

---

### `:Stop()` → `self`

Stops the timer manually. Fires `Signals.Stopped`. The instance can be reused with a new `Start` call afterwards.

```lua
timer:Stop()
```

---

### `:Pause()` → `self`

Pauses the timer. Fires `Signals.Paused`. The internal coroutine stays alive but yields until resumed.

```lua
timer:Pause()
```

---

### `:Resume()` → `self`

Resumes a paused timer. Fires `Signals.Resumed`.

```lua
timer:Resume()
```

---

### `:SetTimeScale(n: number)` → `self`

Sets how many real seconds equal one tick. Defaults to `1`. Must be greater than `0`.

| Value | Effect |
|-------|--------|
| `1` | Normal speed (default) |
| `0.5` | Twice as fast |
| `2` | Half speed |

```lua
timer:SetTimeScale(0.5) -- ticks twice as fast
```

---

### `:Cleanup()`

Stops the timer, fires `Signals.Cleanup`, then disconnects all signal listeners. Call this when you're done with the timer entirely.

```lua
timer:Cleanup()
```

> **Note:** After `Cleanup`, the instance should be discarded. Calling any method on it afterwards is undefined behaviour.

---

## Signals

All signals live under `timer.Signals` and share the same interface:

```lua
local conn = timer.Signals.SomeSignal:Connect(function(...) end)
conn:Disconnect()
```

| Signal | Arguments | Fires when |
|--------|-----------|------------|
| `Tick` | `elapsed: number` | Every `scale` seconds while running |
| `Paused` | — | `Pause()` is called |
| `Resumed` | — | `Resume()` is called |
| `Stopped` | — | `Stop()` is called manually |
| `Finished` | — | The timer reaches its duration naturally |
| `Cleanup` | — | `Cleanup()` is called, before signals are disconnected |

---

## Chaining

Every method except `Cleanup` returns `self`, so calls can be chained.

```lua
TimerService.new()
    :SetTimeScale(0.5)
    :Start(60)
```

---

## Examples

### Restart on demand

Calling `Start` while already running cancels the previous run and restarts cleanly.

```lua
timer:Start(10)
task.wait(4)
timer:Start(10) -- resets; no orphaned coroutines
```

### Pause and resume mid-run

```lua
timer:Start(30)

task.wait(5)
timer:Pause()  -- freeze at ~5s

task.wait(3)   -- paused time is not counted
timer:Resume() -- continues from ~5s
```

### Stop early and reuse

```lua
timer.Signals.Stopped:Connect(function()
    print("Stopped early")
end)

timer:Start(60)
task.wait(10)
timer:Stop()

-- reuse the same instance
timer:Start(30)
```

### Full cleanup when done

```lua
timer.Signals.Finished:Connect(function()
    timer:Cleanup() -- release everything once the run ends
end)

timer:Start(15)
```

---

## License

MIT License © 2026 @kts
