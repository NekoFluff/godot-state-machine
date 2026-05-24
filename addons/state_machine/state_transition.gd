class_name StateTransition
extends Node

signal expired

@export var triggered_by_inputs: Array[String] = []

# For X seconds after transitioning away from the parent state, you can still perform this state transition as if you were still in the parent state.
# This allows for things like coyote time, where you can still jump for a short period of time after walking off a ledge.
@export var trigger_time_extension: float = 0.5

var timer: Timer

func _init():
    timer = Timer.new()
    timer.set_one_shot(true)
    timer.timeout.connect(_on_timer_timeout)
    add_child(timer)

func is_triggered_by_inputs(inputs: Array[String]) -> bool:
    for input in inputs:
        if triggered_by_inputs.find(input) != -1:
            return true
    return false

func state() -> State:
    return get_parent().state_machine.get_node(self.name.substr(2))

func _start_trigger_extension_timer():
    timer.start(trigger_time_extension)

func expire():
    timer.stop()
    expired.emit(self )

func _on_timer_timeout():
    expired.emit(self )