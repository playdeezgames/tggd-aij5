// The only place meaning changes: words for a held thing at a given stage. Pure functions of (id, stage).
package game

import "core:fmt"

noun_rung :: proc(stage: int) -> int {
	return clamp(stage / 2, 0, NOUN_RUNGS - 1)
}

item_text :: proc(id: Item_Id, stage: int) -> string {
	return fmt.tprintf("%s %s", STATUS_LADDER[clamp(stage, 0, DRIFT_STEPS - 1)], ITEM_NOUNS[id][noun_rung(stage)])
}

grudge_text :: proc(id: Grudge_Id, stage: int) -> string {
	intensity := INTENSITY_LADDER[clamp(stage, 0, DRIFT_STEPS - 1)]
	target := GRUDGE_TARGETS[id][noun_rung(stage)]
	if stage < REASON_LOST_STAGE {
		return fmt.tprintf("%s against %s for %s", intensity, target, GRUDGE_REASONS[id])
	}
	return fmt.tprintf("%s against %s, though nobody remembers why", intensity, target)
}
