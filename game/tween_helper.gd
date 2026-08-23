class_name TweenHelper
extends RefCounted

## Shared tween lifecycle utility.
## Replaces the repeated "if tween and tween.is_valid(): tween.kill()" guard.


static func kill_if_valid(tween: Tween) -> void:
	if tween and tween.is_valid():
		tween.kill()
