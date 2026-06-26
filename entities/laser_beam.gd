class_name LaserBeam
extends Area2D

const SPEED: float = 800.0

func _ready():
	var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
	if notifier:
		notifier.screen_exited.connect(queue_free)

func _physics_process(delta: float):
	position.y -= SPEED * delta
