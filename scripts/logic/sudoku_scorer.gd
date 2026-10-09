class_name SudokuScorer
extends RefCounted

const SIZE := 81
const ALL_BITS := 0b1111111110

# Technique levels, easiest to hardest
const NAKED_SINGLE := 1
const HIDDEN_SINGLE := 2
const NAKED_PAIR := 3
const HIDDEN_PAIR := 4
const NAKED_TRIPLE := 5
const HIDDEN_TRIPLE := 6
const POINTING := 7
const BOX_LINE := 8
const X_WING := 9
const SWORDFISH := 10
const JELLYFISH := 11
const STUCK := 99

static var _units: Array = _build_units()


#Public API

static func score(puzzle: PackedInt32Array) -> int:
	var grid: PackedInt32Array = puzzle.duplicate()
	var cands := SudokuSolver.build_candidates(grid)
	if cands.is_empty():
		return STUCK

	var hardest := 0
	while true:
		if _is_solved(grid):
			return hardest
		if _naked_single(grid, cands):
			hardest = max(hardest, NAKED_SINGLE)
			continue
		if _hidden_single(grid, cands):
			hardest = max(hardest, HIDDEN_SINGLE)
			continue
		if _naked_subset(grid, cands, 2):
			hardest = max(hardest, NAKED_PAIR)
			continue
		if _hidden_subset(grid, cands, 2):
			hardest = max(hardest, HIDDEN_PAIR)
			continue
		if _naked_subset(grid, cands, 3):
			hardest = max(hardest, NAKED_TRIPLE)
			continue
		if _hidden_subset(grid, cands, 3):
			hardest = max(hardest, HIDDEN_TRIPLE)
			continue
		if _pointing(grid, cands):
			hardest = max(hardest, POINTING)
			continue
		if _box_line(grid, cands):
			hardest = max(hardest, BOX_LINE)
			continue
		if _fish(grid, cands, 2):
			hardest = max(hardest, X_WING)
			continue
		if _fish(grid, cands, 3):
			hardest = max(hardest, SWORDFISH)
			continue
		if _fish(grid, cands, 4):
			hardest = max(hardest, JELLYFISH)
			continue
		return STUCK

	return STUCK

#Setup

static func _build_units() -> Array:
	var units: Array = []
	for r in 9:
		var row: Array = []
		for c in 9:
			row.append(r * 9 + c)
		units.append(row)
	for c in 9:
		var col: Array = []
		for r in 9:
			col.append(r * 9 + c)
		units.append(col)
	for br in 3:
		for bc in 3:
			var box: Array = []
			for dr in 3:
				for dc in 3:
					box.append((br * 3 + dr) * 9 + (bc * 3 + dc))
			units.append(box)
	return units
	
static func _box_of(cell: int) -> int:
	return (cell / 27) * 3 + (cell % 9) / 3


static func _is_solved(grid: PackedInt32Array) -> bool:
	for v in grid:
		if v == 0:
			return false
	return true


# Place a digit and eliminate it from peers.
static func _place(grid: PackedInt32Array, cands: PackedInt32Array, cell: int, digit: int) -> void:
	grid[cell] = digit
	cands[cell] = 1 << digit
	var bit := 1 << digit
	for p in SudokuSolver._peers[cell]:
		var pi: int = p
		if grid[pi] == 0:
			cands[pi] &= ~bit
			
#helpers

static func _combinations(n: int, k: int) -> Array:
	var result: Array = []
	var combo: Array = []
	_combinations_rec(n, k, 0, combo, result)
	return result


static func _combinations_rec(n: int, k: int, start: int, combo: Array, result: Array) -> void:
	if combo.size() == k:
		result.append(combo.duplicate())
		return
	for i in range(start, n):
		combo.append(i)
		_combinations_rec(n, k, i + 1, combo, result)
		combo.pop_back()


#Techniques

static func _naked_single(grid: PackedInt32Array, cands: PackedInt32Array) -> bool:
	for i in SIZE:
		if grid[i] != 0:
			continue
		if SudokuSolver.popcount(cands[i]) == 1:
			var m: int = cands[i]
			for d in range(1, 10):
				if m & (1 << d):
					_place(grid, cands, i, d)
					return true
	return false


static func _hidden_single(grid: PackedInt32Array, cands: PackedInt32Array) -> bool:
	for unit in _units:
		for d in range(1, 10):
			var bit := 1 << d
			var count := 0
			var target := -1
			var already_placed := false
			for c in unit:
				var ci: int = c
				if grid[ci] == d:
					already_placed = true
					break
				if grid[ci] == 0 and (cands[ci] & bit) != 0:
					count += 1
					target = ci
			if already_placed:
				continue
			if count == 1:
				_place(grid, cands, target, d)
				return true
	return false

static func _naked_subset(grid: PackedInt32Array, cands: PackedInt32Array, k: int) -> bool:
	for unit in _units:
		var cells: Array = []
		var masks: Array = []
		for c in unit:
			var ci: int = c
			if grid[ci] == 0:
				cells.append(ci)
				masks.append(cands[ci])

		var n := cells.size()
		if n < k:
			continue

		for combo in _combinations(n, k):
			var combined := 0
			var ok := true
			for idx in combo:
				var m: int = masks[idx]
				var pc := SudokuSolver.popcount(m)
				if pc < 2 or pc > k:
					ok = false
					break
				combined |= m
			if not ok:
				continue
			if SudokuSolver.popcount(combined) != k:
				continue

			var changed := false
			for i in n:
				if combo.has(i):
					continue
				var ci: int = cells[i]
				var before: int = cands[ci]
				cands[ci] &= ~combined
				if cands[ci] != before:
					changed = true
			if changed:
				return true
	return false


# Hidden subset: k digits in a unit that can only go in the same k cells.
# Restrict those cells to only those k digits.
static func _hidden_subset(grid: PackedInt32Array, cands: PackedInt32Array, k: int) -> bool:
	for unit in _units:
		var digit_cells := {}
		for d in range(1, 10):
			var cells_for_d: Array = []
			var already_placed := false
			for c in unit:
				var ci: int = c
				if grid[ci] == d:
					already_placed = true
					break
				if grid[ci] == 0 and (cands[ci] & (1 << d)) != 0:
					cells_for_d.append(ci)
			if not already_placed and cells_for_d.size() >= 2:
				digit_cells[d] = cells_for_d

		var digits_present: Array = digit_cells.keys()
		if digits_present.size() < k:
			continue

		for combo in _combinations(digits_present.size(), k):
			var cell_set := {}
			for idx in combo:
				var d: int = digits_present[idx]
				for ci in digit_cells[d]:
					cell_set[ci] = true
			if cell_set.size() != k:
				continue

			var mask := 0
			for idx in combo:
				mask |= 1 << digits_present[idx]

			var changed := false
			for ci in cell_set:
				if cands[ci] & ~mask:
					cands[ci] &= mask
					changed = true
			if changed:
				return true
	return false

# Pointing: a digit's candidates in a box all share one row or column.
static func _pointing(grid: PackedInt32Array, cands: PackedInt32Array) -> bool:
	for b in 9:
		var box_unit: Array = _units[18 + b]
		for d in range(1, 10):
			var bit := 1 << d
			var cells: Array = []
			var already := false
			for c in box_unit:
				var ci: int = c
				if grid[ci] == d:
					already = true
					break
				if grid[ci] == 0 and (cands[ci] & bit) != 0:
					cells.append(ci)
			if already or cells.size() < 2:
				continue

			var r0: int = cells[0] / 9
			var c0: int = cells[0] % 9
			var same_row := true
			var same_col := true
			for c in cells:
				var ci: int = c
				if ci / 9 != r0:
					same_row = false
				if ci % 9 != c0:
					same_col = false
			if not same_row and not same_col:
				continue

			var changed := false
			if same_row:
				for k in 9:
					var ci := r0 * 9 + k
					if _box_of(ci) == b:
						continue
					if grid[ci] == 0 and (cands[ci] & bit) != 0:
						cands[ci] &= ~bit
						changed = true
			else:
				for k in 9:
					var ci := k * 9 + c0
					if _box_of(ci) == b:
						continue
					if grid[ci] == 0 and (cands[ci] & bit) != 0:
						cands[ci] &= ~bit
						changed = true
			if changed:
				return true
	return false


# Box-line reduction: a digit's candidates in a row/column all lie in one box.
static func _box_line(grid: PackedInt32Array, cands: PackedInt32Array) -> bool:
	for u in 18:
		var line_unit: Array = _units[u]
		for d in range(1, 10):
			var bit := 1 << d
			var cells: Array = []
			var already := false
			for c in line_unit:
				var ci: int = c
				if grid[ci] == d:
					already = true
					break
				if grid[ci] == 0 and (cands[ci] & bit) != 0:
					cells.append(ci)
			if already or cells.size() < 2:
				continue

			var b0: int = _box_of(cells[0])
			var same_box := true
			for c in cells:
				var ci: int = c
				if _box_of(ci) != b0:
					same_box = false
					break
			if not same_box:
				continue

			var box_unit: Array = _units[18 + b0]
			var changed := false
			for c in box_unit:
				var ci: int = c
				if line_unit.has(ci):
					continue
				if grid[ci] == 0 and (cands[ci] & bit) != 0:
					cands[ci] &= ~bit
					changed = true
			if changed:
				return true
	return false

# N-fish: a digit whose candidates across N base lines occupy exactly N
# cross lines. Eliminate the digit from those cross lines elsewhere.
# size=2 → X-Wing, size=3 → Swordfish, size=4 → Jellyfish.
static func _fish(grid: PackedInt32Array, cands: PackedInt32Array, size: int) -> bool:
	for axis in 2:
		if _fish_axis(grid, cands, size, axis):
			return true
	return false


 #axis=0: base rows, cross columns. axis=1: base columns, cross rows.
static func _fish_axis(grid: PackedInt32Array, cands: PackedInt32Array, size: int, axis: int) -> bool:
	for d in range(1, 10):
		var bit := 1 << d
		var candidates_per_base: Array = []
		for b in 9:
			var crosses: Array = []
			var has_digit := false
			for s in 9:
				var ci: int = b * 9 + s if axis == 0 else s * 9 + b
				if grid[ci] == d:
					has_digit = true
					break
				if grid[ci] == 0 and (cands[ci] & bit) != 0:
					crosses.append(s)
			if has_digit or crosses.size() < 2 or crosses.size() > size:
				candidates_per_base.append([])
			else:
				candidates_per_base.append(crosses)

		var valid: Array = []
		for b in 9:
			if not candidates_per_base[b].is_empty():
				valid.append(b)
		if valid.size() < size:
			continue

		for combo in _combinations(valid.size(), size):
			var chosen: Array = []
			for idx in combo:
				chosen.append(valid[idx])

			var cross_set := {}
			for b in chosen:
				for s in candidates_per_base[b]:
					cross_set[s] = true
			if cross_set.size() != size:
				continue
				
			#print("[FISH DETECTED] size=", size, " axis=", axis, " digit=", d, " bases=", chosen, " crosses=", cross_set.keys())

			var changed := false
			for b in 9:
				if chosen.has(b):
					continue
				for s in cross_set:
					var ci: int = b * 9 + s if axis == 0 else s * 9 + b
					if grid[ci] == 0 and (cands[ci] & bit) != 0:
						cands[ci] &= ~bit
						changed = true
			if changed:
				return true
	return false
