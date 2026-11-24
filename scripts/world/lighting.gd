class_name Lighting
extends RefCounted
## Answers "is this spot lit?" for gameplay (auto-attacks only target what you can see).
## Light sources join the group "light_sources" and implement `light_reach() -> float`.

const WALL_MASK := 1


static func is_lit(from: Node2D, pos: Vector2) -> bool:
	var space := from.get_world_2d().direct_space_state
	for node in from.get_tree().get_nodes_in_group("light_sources"):
		var src := node as Node2D
		if src == null or not src.has_method("light_reach"):
			continue
		var reach: float = src.call("light_reach")
		if src.global_position.distance_to(pos) > reach:
			continue
		var query := PhysicsRayQueryParameters2D.create(src.global_position, pos, WALL_MASK)
		if space.intersect_ray(query).is_empty():
			return true
	return false
