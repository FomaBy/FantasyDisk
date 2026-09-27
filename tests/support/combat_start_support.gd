extends RefCounted

# FAN-3977: `CombatDirector._finalize_combat_start` (boss/elite spawn,
# encounter waves) no longer runs synchronously inside `_start_combat` when
# the encounter's full-frame roster is not resident yet — it is re-entered
# from the registry prefetch tick once the last pack lands (a few hundred
# milliseconds headless for the whole core roster). Suites that start a fight
# and then inspect spawned actors await this helper first; the Player, HUD
# and `combat_active` are still created synchronously.

const MAX_WAIT_FRAMES := 6000


# Returns true when the combat start finalized (spawns happened) within the
# frame budget. Returns false without waiting when combat is not active or
# when the start is waiting on something other than the roster (a Priest's
# battle-prayer choice UI): those flows keep their own sequencing.
static func await_finalized(main: Node, max_frames := MAX_WAIT_FRAMES) -> bool:
	var combat = main.get("combat")
	var tree := main.get_tree()
	if combat == null or tree == null:
		return false
	for _frame in range(max_frames):
		if not is_instance_valid(main) or not is_instance_valid(combat):
			return false
		if bool(combat.get("_combat_start_finalized")):
			return true
		if not bool(main.get("combat_active")) or not bool(combat.get("_combat_roster_wait_pending")):
			return false
		await tree.process_frame
	return is_instance_valid(combat) and bool(combat.get("_combat_start_finalized"))
