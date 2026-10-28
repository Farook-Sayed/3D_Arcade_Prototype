class_name RaceUI
extends Control

@export var car : Car
@onready var checkpoint_missed_label: Label = $HBoxContainer/left/checkpoint_missed_label
@onready var timer_label: Label = $HBoxContainer/center/timer_label
@onready var lap_label: Label = $HBoxContainer/right/lap_label

var time_checkpoint_missed := -999999

const TIME_SHOW_CHECKPOINT_MISS = 3_000
const FLASH_PERIOD = 100

func _physics_process(delta: float) -> void:
	var time = Time.get_ticks_msec()
	if time > time_checkpoint_missed + TIME_SHOW_CHECKPOINT_MISS:
		checkpoint_missed_label.hide()
	else:
		checkpoint_missed_label.visible = ((time - time_checkpoint_missed / FLASH_PERIOD) % 2) == 0
	
	lap_label.text = "Lap: %d/%d" % [car.current_lap + 1, car.max_laps]
	var time_elapsed : int = time - car.time_race_started
	var time_remaining : int = car.MAX_RACE_TIME - time_elapsed
	
	var minutes : int = time_remaining / 60_000
	var seconds : int = ((time_remaining + 500) / 1_000) % 60
	timer_label.text = "Time Left: %02d:%02d" % [minutes, seconds]

func flash_checkpoint_missed() -> void:
	time_checkpoint_missed = Time.get_ticks_msec()
