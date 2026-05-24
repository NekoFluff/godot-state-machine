class_name StateMachine
extends Node

signal transitioning_away_from_state(state: State)
signal transitioned_to_state(state: State)

@export var debug_enabled: bool = false
@export var current_state: State
@export var animation_player: AnimationPlayer

var possible_state_transitions: Dictionary[String, StateTransition] = {}

func _ready():
    for child in get_children():
        if child is State:
            child.transition_to_state.connect(transition_to_state)
            child.animation_player = animation_player
            child.debug_enabled = debug_enabled
            child.state_machine = self

            child._after_state_machine_ready()

    if current_state:
        current_state.enter()

func _process(delta: float):
    if current_state:
        current_state.process(delta)

func _physics_process(delta: float):
    if current_state:
        current_state._update_sec_since_enter(delta)

func can_transition_to_state(new_state: State) -> bool:
    if not new_state:
        push_error(owner, " trying to move to NULL state")
        return false

    if not new_state.can_transition_to_state():
        return false

    # Don't transition to the new state if it's the same as the current state and the current state hasn't finished its action yet
    # This allows repeating the same state after it has finished
    if current_state == new_state and not current_state.is_finished:
        return false

    return true

func transition_to_state(new_state: State, force: bool = false) -> bool:
    if not new_state:
        return false

    if not force and not can_transition_to_state(new_state):
        return false

    # Once the current sate has finished, keep track of any state_transitions it has
    # so they can be triggered by inputs in the future
    if current_state:
        for state_transition in current_state.state_transitions:
            possible_state_transitions[state_transition.name] = state_transition
            if not state_transition.expired.is_connected(_remove_state_transition):
                state_transition.expired.connect(_remove_state_transition)
            state_transition._start_trigger_extension_timer()
        current_state.exit()

    transitioning_away_from_state.emit(current_state)
    current_state = new_state
    current_state.enter()
    transitioned_to_state.emit(current_state)

    return true

func get_default_state(_input: String) -> State:
    push_error("get_default_state has not been implemented")
    return null

func _remove_state_transition(state_transition: StateTransition):
    possible_state_transitions.erase(state_transition.name)
