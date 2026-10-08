class_name SudokuSolver
extends RefCounted

const SIZE := 81
const ALL_BITS := 0b1111111110  # bits 1..9 set

static var _peers: Array = _build_peers()

# For each cell, the indices of its 20 peers (row + col + box).
static func _build_peers() -> Array:
	var peers: Array = []
	for i in SIZE:
		var r: int = i / 9
		var c: int = i % 9
		var br: int = (r / 3) * 3
		var bc: int = (c / 3) * 3
		var s := {}
		for k in 9:
			s[r * 9 + k] = true
			s[k * 9 + c] = true
		for dr in 3:
			for dc in 3:
				s[(br + dr) * 9 + (bc + dc)] = true
		s.erase(i)
		peers.append(s.keys())
	return peers


# Count set bits in bits 1..9 of a candidate mask.
static func _popcount(mask: int) -> int:
	var count := 0
	for d in range(1, 10):
		if mask & (1 << d):
			count += 1
	return count


#Public API


static func solve(puzzle: PackedInt32Array, shuffle := false) -> PackedInt32Array:
	var grid: PackedInt32Array = puzzle.duplicate()
	var cands := _build_candidates(grid)
	if cands.is_empty():
		return PackedInt32Array()
	if not _search_solve(grid, cands, shuffle):
		return PackedInt32Array()
	return grid


# Count solutions up to `limit`
static func count_solutions(puzzle: PackedInt32Array, limit := 2) -> int:
	var grid: PackedInt32Array = puzzle.duplicate()
	var cands := _build_candidates(grid)
	if cands.is_empty():
		return 0
	var counter := [0]
	_search_count(grid, cands, limit, counter)
	return counter[0]


#Setup

static func _build_candidates(grid: PackedInt32Array) -> PackedInt32Array:
	var cands := PackedInt32Array()
	cands.resize(SIZE)

	# Validate givens and mark their masks.
	for i in SIZE:
		var d: int = grid[i]
		if d == 0:
			continue
		for p in _peers[i]:
			if grid[p] == d:
				return PackedInt32Array()
		cands[i] = 1 << d

	# Build candidate masks for empty cells.
	for i in SIZE:
		if grid[i] != 0:
			continue
		var mask := ALL_BITS
		for p in _peers[i]:
			var pd: int = grid[p]
			if pd != 0:
				mask &= ~(1 << pd)
		cands[i] = mask

	return cands


#Search

static func _search_solve(grid: PackedInt32Array, cands: PackedInt32Array, shuffle: bool) -> bool:
	#pick the empty cell with the fewest candidates.
	var best := -1
	var best_count := 10
	var best_mask := 0
	for i in SIZE:
		if grid[i] != 0:
			continue
		var m: int = cands[i]
		var c: int = _popcount(m)
		if c == 0:
			return false
		if c < best_count:
			best_count = c
			best = i
			best_mask = m
			if c == 1:
				break

	if best == -1:
		return true  # no empty cells — solved

	var digits: Array = _bits_to_array(best_mask)
	if shuffle:
		digits.shuffle()

	for d in digits:
		var digit: int = d
		var bit: int = 1 << digit
		grid[best] = digit

		# Remove this digit from peers' candidates.
		var removed := PackedInt32Array()
		for p in _peers[best]:
			var pi: int = p
			if grid[pi] == 0 and (cands[pi] & bit) != 0:
				cands[pi] &= ~bit
				removed.append(pi)

		if _search_solve(grid, cands, shuffle):
			return true

		# Undo.
		grid[best] = 0
		for pi in removed:
			cands[pi] |= bit

	return false


static func _search_count(grid: PackedInt32Array, cands: PackedInt32Array, limit: int, counter: Array) -> void:
	if counter[0] >= limit:
		return

	var best := -1
	var best_count := 10
	var best_mask := 0
	for i in SIZE:
		if grid[i] != 0:
			continue
		var m: int = cands[i]
		var c: int = _popcount(m)
		if c == 0:
			return
		if c < best_count:
			best_count = c
			best = i
			best_mask = m
			if c == 1:
				break

	if best == -1:
		counter[0] += 1
		return

	var digits: Array = _bits_to_array(best_mask)
	for d in digits:
		var digit: int = d
		var bit: int = 1 << digit
		grid[best] = digit

		var removed := PackedInt32Array()
		for p in _peers[best]:
			var pi: int = p
			if grid[pi] == 0 and (cands[pi] & bit) != 0:
				cands[pi] &= ~bit
				removed.append(pi)

		_search_count(grid, cands, limit, counter)

		grid[best] = 0
		for pi in removed:
			cands[pi] |= bit

		if counter[0] >= limit:
			return


#Helpers

static func _bits_to_array(mask: int) -> Array:
	var out: Array = []
	for d in range(1, 10):
		if mask & (1 << d):
			out.append(d)
	return out
