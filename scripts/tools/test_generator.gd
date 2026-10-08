extends SceneTree

func _init():
	for target in [50, 40, 30, 25, 22]:
		var t0 := Time.get_ticks_msec()
		var full := SudokuGenerator.generate_full_grid()
		var puzzle := SudokuGenerator.dig_holes(full, target)
		var t1 := Time.get_ticks_msec()

		var clues := 0
		for v in puzzle:
			if v != 0:
				clues += 1

		var t2 := Time.get_ticks_msec()
		var solutions := SudokuSolver.count_solutions(puzzle, 2)
		var t3 := Time.get_ticks_msec()

		print("Target=", target,
			"  Clues=", clues,
			"  Solutions=", solutions,
			"  Dig=", t1 - t0, "ms",
			"  Verify=", t3 - t2, "ms")
	quit()
