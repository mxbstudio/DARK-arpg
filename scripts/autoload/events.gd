extends Node
## Global gameplay event bus.

## Something made a noise that AI can hear. `radius` is the hearing range in px.
@warning_ignore("unused_signal")
signal noise_emitted(position: Vector2, radius: float, source: Node)
