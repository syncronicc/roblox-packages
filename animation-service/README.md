# AnimationService

A simple, flexible animation controller for Roblox games.

```lua
local AnimationService = require(AnimationService)
local anim = AnimationService.new(animator)
```

---

## Setup

### `service.new(animator)`
Creates a new AnimationService instance bound to an `Animator`.

```lua
local anim = AnimationService.new(character.Humanoid.Animator)
```

---

## Playback

### `:play(id, speed?, events?)`
Loads and plays an animation by asset id. If the animation is already playing it is stopped and restarted. Speed defaults to `1`.

```lua
anim:play(1234567890)
anim:play(1234567890, 1.5)
```

---

### `:pause(id)`
Pauses an animation by setting its speed to `0`. Preserves playback position.

```lua
anim:pause(1234567890)
```

---

### `:resume(id)`
Resumes a paused animation at its original speed.

```lua
anim:resume(1234567890)
```

---

### `:stop(id)`
Stops an animation and removes it from internal tracking.

```lua
anim:stop(1234567890)
```

---

### `:adjust_speed(id, speed, mock?)`
Changes the playback speed of a running animation. Pass `mock = true` to change the current speed without updating the default — useful for temporary slowdowns or pauses.

```lua
anim:adjust_speed(1234567890, 0.5)
anim:adjust_speed(1234567890, 0, true) -- temporary, default speed preserved
```

---

## Groups

Groups let you control multiple animations together under a single name.

### `:create_group(name)`
Creates a named group. Returns the `Group` object.

```lua
local group = anim:create_group("combat")
group:add(1234567890)
group:add(9876543210)
```

---

### `:play_group(name)`
Plays all animations in the group at the group's default speed.

```lua
anim:play_group("combat")
```

---

### `:pause_group(name)`
Pauses all playing animations in the group.

```lua
anim:pause_group("combat")
```

---

### `:resume_group(name)`
Resumes all paused animations in the group at the group's default speed.

```lua
anim:resume_group("combat")
```

---

### `:set_group_speed(name, speed, mock?)`
Sets the speed of all animations in the group. Pass `mock = true` to change the current speed without updating the group's default speed.

```lua
anim:set_group_speed("combat", 2)
anim:set_group_speed("combat", 0, true) -- temporary pause, default preserved
```

---

### `:destroy_group(name)`
Stops all animations in the group and removes the group.

```lua
anim:destroy_group("combat")
```

---

## Group API

The `Group` object returned by `:create_group()` has its own methods.

### `group:add(id)`
Adds an animation id to the group.

```lua
group:add(1234567890)
```

---

### `group:remove(id)`
Removes an animation id from the group.

```lua
group:remove(1234567890)
```

---

### `group:get_state()`
Returns `playing, paused` as two booleans.

```lua
local playing, paused = group:get_state()
```

---

## Queries

### `:is_playing(id, exclude_pause?)`
Returns `true` if the animation is loaded. Pass `exclude_pause = true` to return `false` for animations that are paused (speed = 0).

```lua
anim:is_playing(1234567890)
anim:is_playing(1234567890, true) -- false if paused
```

---

### `:get_time(id)`
Returns the current `TimePosition` of the animation. Returns `0` if not loaded.

```lua
local t = anim:get_time(1234567890)
```

---

### `:get_lenght(id)`
Returns the total length of the animation in seconds. Returns `0` if not loaded.

```lua
local len = anim:get_lenght(1234567890)
```

---

### `:get_speed(id)`
Returns the current playback speed. Returns `0` if not loaded.

```lua
local speed = anim:get_speed(1234567890)
```

---

### `:get_weight(id)`
Returns the current blend weight of the animation. Returns `0` if not loaded.

```lua
local weight = anim:get_weight(1234567890)
```

---

## Cleanup

### `:destroy()`
Stops all animations and destroys all groups. Call when the service is no longer needed.

```lua
anim:destroy()
```

---

## License

MIT © 2026 @kts
