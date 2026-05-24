# StateMachine Addon

A Godot 4 state machine addon that organises character behaviour into discrete states driven by string inputs.

> Given the current state and a set of inputs, what state should the character be in, and how should it behave in that state?

## Overview

The addon provides three classes:

| Class             | Extends | Purpose                                                                              |
| ----------------- | ------- | ------------------------------------------------------------------------------------ |
| `StateMachine`    | `Node`  | Manages the active state and routes calls to it                                      |
| `State`           | `Node`  | Base class for individual states                                                     |
| `StateTransition` | `Node`  | Defines an input-triggered transition that can persist briefly after leaving a state |

---

## How It Works

### State lifecycle

Your state machine subclass is responsible for collecting inputs and calling `current_state.process_inputs(inputs, delta)`.

```
_physics_process(delta)
  └─ collect inputs  (your code)
  └─ current_state.process_inputs(inputs, delta)
        └─ if is_finished:
              1. check possible_state_transitions (carry-over from previous state) and transition states if possible
              2. check this state's own StateTransition children and transition states if possible
              3. call get_default_state(input) on the state machine and transition states if possible
```

A state signals that it is done with its action by setting `is_finished = true`. Until that flag is set, no automatic transitions are evaluated.

### Transitioning

`StateMachine.transition_to_state(new_state, force)` is the backbone for all transitions. It:

1. Guards against transitioning to `null`, to a state whose `can_transition_to_state()` returns `false`, or back to the same state while it is still unfinished (unless `force = true`).
2. Calls `exit()` on the outgoing state and stores any `StateTransition` children it had so they remain triggerable for a short time after leaving.
3. Sets `current_state` and calls `enter()` on the new state.
4. Emits `transitioning_away_from_state` and `transitioned_to_state` signals.

#### Manual Transitions

Emit `transition_to_state` signal directly when you need an immediate transition that doesn't fit the automatic transition patterns:

```gdscript
transition_to_state.emit(state_machine.get_default_state("idle"), true)
```

#### Default Automatic Transitions

For states that can be transitioned to from any other state, add an input mapping in `get_default_state(input)`. For example, if you want the player to be able to dash from any state by pressing the dash button, add this to `get_default_state`:

```gdscript
func get_default_state(input: String) -> State:
    match input:
        "dash": return $DashState
        _ :     return null
```

#### Defined Automatic Transitions (StateTransition class)

`StateTransition` is a child node of a `State`. It declares which inputs trigger it and which sibling state it leads to (resolved by name). To use this, add it as a child of a `State` with the name `To<TargetStateName>` (e.g. `ToSlashFollowUpState` if you have a `SlashFollowUpState` state) — the target is resolved by stripping the `To` prefix and looking up the node in the state machine.

```
StateTransition
  triggered_by_inputs: ["jump"]
  trigger_time_extension: 0.5   # seconds the transition stays valid after leaving the parent state
```

The `trigger_time_extension` property can be used to allow transitioning to a target state for a short time after leaving the parent state. For example, this allows you to follow up basic attack with a combo attack for a brief period even after idling for a moment and already being transitioned away to an IdleState.

## Installation

1. Copy the `addons/state_machine` folder into your project's `addons/` directory.
2. Open **Project → Project Settings → Plugins** and enable **StateMachine**.

## How to Use

### 1. Create a state machine script

Extend `StateMachine` and implement `get_default_state`. This method receives a single input string and returns the `State` node that input maps to, or `null` if it is not handled.

```gdscript
# my_entity_state_machine.gd
extends StateMachine

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if current_state == null:
        return

    var inputs: Array[String] = get_parent().get_inputs()
    current_state.process_inputs(inputs, delta)

func get_default_state(input: String) -> State:
    match input:
        "idle":  return $IdleState
        "run":   return $RunState
        "jump":  return $JumpState
        "fall":  return $FallState
        "attack": return $SlashState
        _:       return null
```

### 2. Set up the scene tree

```
MyEntity  (Character)
└─ MyEntityStateMachine  (your StateMachine script)
   ├─ IdleState
   ├─ RunState
   ├─ JumpState
   ├─ SlashState
   │   └─ ToSlashFollowUpState  (StateTransition — triggered_by_inputs: ["attack"])
   ├─ SlashFollowUpState
   └─ FallState
```

Assign the `current_state` export in the Inspector to the state the entity should start in, and assign `animation_player` if your states need it.

### 3. Write a state

Extend `State` and override the hooks you need:

```gdscript
# run_state.gd
class_name RunState
extends State

const SPEED = 500

func can_transition_to_state() -> bool:
    return owner.is_on_floor()   # prerequisite guard

func enter() -> void:
    super.enter()
    is_finished = true           # immediately ready to transition away
    animation_player.play("run")

func exit() -> void:
    super.exit()

func process(delta: float) -> void:
    super.process(delta)
    owner.velocity.x = SPEED * owner.direction

func process_inputs(inputs: Array[String], delta: float) -> void:
    # Physics / movement goes here; super() evaluates transitions
    super.process_inputs(inputs, delta)
```

Key members available inside every state:

| Member              | Type                     | Description                                           |
| ------------------- | ------------------------ | ----------------------------------------------------- |
| `state_machine`     | `StateMachine`           | The owning state machine                              |
| `animation_player`  | `AnimationPlayer`        | Forwarded from the state machine                      |
| `sec_since_enter`   | `float`                  | Seconds elapsed since `enter()` was called            |
| `is_finished`       | `bool`                   | Set to `true` when the state has completed its action |
| `state_transitions` | `Array[StateTransition]` | Child `StateTransition` nodes                         |

Emit `transition_to_state` signal directly when you need an immediate, imperative transition:

```gdscript
transition_to_state.emit(state_machine.get_default_state("idle"), true)
```

### 4. Override `can_transition_to_state`

Return `false` to prevent the state machine from entering this state unless `force = true` is used. For example if you want to prevent the player from dashing while in the air or while the dash is on cooldown, you could do this:

```gdscript
func can_transition_to_state() -> bool:
    return owner.is_on_floor() and dash_cooldown_timer.time_left == 0
```

### 5. Add a `StateTransition`

To set up a transition from one state to another based on some input, add a `StateTransition` node as a child of a `State`. Name it `To<TargetStateName>` — the target is resolved by stripping the `To` prefix and looking up the node in the state machine.

```gdscript
StateTransition
    triggered_by_inputs: ["attack"]
    trigger_time_extension: 0.5   # seconds the transition stays valid after leaving the parent state
```

---

## Signals

### StateMachine

| Signal                          | Arguments      | Fires when                              |
| ------------------------------- | -------------- | --------------------------------------- |
| `transitioning_away_from_state` | `state: State` | Just before the current state is exited |
| `transitioned_to_state`         | `state: State` | Just after the new state is entered     |

---
