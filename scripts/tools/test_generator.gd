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
		SudokuScorer.SWORDFISH: "swordfish",
		SudokuScorer.JELLYFISH: "jellyfish",
		SudokuScorer.STUCK: "STUCK",
	}

	var counts := {}
	var n := 500

	for i in n:
		var full := SudokuGenerator.generate_full_grid()
		var puzzle := SudokuGenerator.dig_holes(full, 21)
		var s := SudokuScorer.score(puzzle)
		counts[s] = counts.get(s, 0) + 1

	print("=== ", n, " puzzles, dug to 21 clues ===")
	for k in counts:
		print("  ", names[k], ": ", counts[k])
	quit()
