class_name SudokuGenerator
extends RefCounted


#Public API

# Returns a full 81-cell solved grid, randomized.
static func generate_full_grid() -> PackedInt32Array:
	var empty := PackedInt32Array()
	empty.resize(SudokuSolver.SIZE)
	empty.fill(0)
	return SudokuSolver.solve(empty, true)
	
	
# Dig holes in a solved grid, keeping a unique solution.
static func dig_holes(full_grid: PackedInt32Array, target_clues: int) -> PackedInt32Array:
	var grid: PackedInt32Array = full_grid.duplicate()

	var order: Array = []
	for i in SudokuSolver.SIZE:
		order.append(i)
	order.shuffle()

	var clues := SudokuSolver.SIZE
	for c in order:
		if clues <= target_clues:
			break
		var cell: int = c
		var saved: int = grid[cell]
		grid[cell] = 0
		if SudokuSolver.count_solutions(grid, 2) == 1:
			clues -= 1
		else:
			grid[cell] = saved

	return grid
