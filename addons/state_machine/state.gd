class_name State
extends Node

# Populated by the state machine
var state_machine: StateMachine
var animation_player: AnimationPlayer
var debug_enabled: bool = false

var sec_since_enter: float = 0
var is_finished: bool = false # Set by the state when it determines it has finished its action and is ready to transition to another state. Used by the state machine to determine if it should check for state_transitions or not.
var state_transitions: Array[StateTransition] = []

func _ready():
    for child in get_children():
        if child is StateTransition:
            state_transitions.append(child)

# Called by the state machine after it has set up the state with any necessary references such as the animation player
func _after_state_machine_ready():
    pass

# Extra prerequisites determined by the state that must be fulfilled
# for the state machine to transition to this state
func can_transition_to_state() -> bool:
    return true

func enter():
    is_finished = false
    sec_since_enter = 0
    if owner and debug_enabled:
        print(owner.name, " entering state ", name)

    if animation_player:
        animation_player.clear_queue()

func exit():
    if owner && debug_enabled:
        print(owner.name, " exiting state ", name)
    sec_since_enter = 0

# Called by the state machine in its _process function.
# Physics-related updates should not be done here, but instead in the process_inputs.
func process(_delta: float):
    pass

# Called by the state machine in its _physics_process function.
# Do not override this function
func _update_sec_since_enter(delta: float):
    sec_since_enter += delta

# Should be called by the state machine in its _physics_process function.
# Evaluates inputs to decide state transitions and emits a signal if a transition occurs
func process_inputs(inputs: Array[String], _delta: float) -> void:
    if not is_finished:
        return

    if trigger_state_transitons(inputs, state_machine.possible_state_transitions.values()):
        return

    if trigger_state_transitons(inputs, state_transitions):
        return

    for input in inputs:
        var state = state_machine.get_default_state(input)

        # Check the next input if the current input doesn't have a default state transition
        if state == null:
            continue

        if state == self and state.can_transition_to_state():
            return

        if state.can_transition_to_state():
            state_machine.transition_to_state(state)
            return

# Checks if any of the state_transitions are triggered by the inputs and transitions to the corresponding state if triggered.
# Returns true if a state_transition is triggered, false otherwise.
func trigger_state_transitons(inputs: Array[String], potential_state_transitions: Array) -> bool:
    for state_transition in potential_state_transitions:
        if state_transition.is_triggered_by_inputs(inputs):
            var state = state_transition.state()

            if state.can_transition_to_state():
                state_machine.transition_to_state(state)
                state_transition.expire()
                return true

    return false
