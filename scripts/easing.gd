extends Node

func exp_smooth(speed : float, delta : float) -> float:
	return 1.0 - exp(-speed * delta)
