extends SceneTree

func _init():
	var names := {
		SudokuScorer.NAKED_SINGLE: "naked single",
		SudokuScorer.HIDDEN_SINGLE: "hidden single",
		SudokuScorer.NAKED_PAIR: "naked pair",
		SudokuScorer.HIDDEN_PAIR: "hidden pair",
		SudokuScorer.NAKED_TRIPLE: "naked triple",
		SudokuScorer.HIDDEN_TRIPLE: "hidden triple",
		SudokuScorer.POINTING: "pointing",
		SudokuScorer.BOX_LINE: "box-line",
		SudokuScorer.X_WING: "x-wing",
		SudokuScorer.STUCK: "STUCK",
	}

	for target in [55, 50, 45, 40, 35, 30, 28, 25, 22]:
		var full := SudokuGenerator.generate_full_grid()
		var puzzle := SudokuGenerator.dig_holes(full, target)
		var clues := 0
		for v in puzzle:
			if v != 0:
				clues += 1
		var t0 := Time.get_ticks_msec()
		var s := SudokuScorer.score(puzzle)
		var t1 := Time.get_ticks_msec()
		print("Target=", target,
			"  Clues=", clues,
			"  Score=", names[s],
			"  Time=", t1 - t0, "ms")
	quit()
