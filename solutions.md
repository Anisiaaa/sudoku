# Sudoku Solving Techniques

The scorer solves a puzzle using only human-style deduction techniques,
ordered easiest to hardest. A puzzle's difficulty score is the hardest
technique required to solve it.

The score loop always restarts from the easiest technique after any
placement or elimination, so if a puzzle can be solved with singles
alone, it never needs to reach for pairs.

---

## Tier 1 — Singles

### Naked Single

**What it is:** A cell whose candidate mask contains exactly one digit.

**Why it works:** Every other digit is already blocked by a peer (same
row, column, or box). Only one option remains.

**Action:** Place that digit.

**Example:**
```
Row contains: 1 2 3 4 _ 6 7 8 9
The empty cell can only be 5.
```

**Difficulty:** Trivial. Most puzzles above ~45 clues are solvable with
naked singles alone.

**How the program does it:**

1. Loop through all 81 cells.
2. Skip any cell that already has a digit in it.
3. For each empty cell, count the set bits in its candidate mask.
   If the count is 1, that's a naked single.
4. Find which digit the set bit represents (loop digits 1–9 and test
   `mask & (1 << digit)`).
5. Place the digit using the shared `place()` helper, which:
   - Writes the digit into the grid.
   - Sets the cell's mask to `1 << digit` (so it now reflects "this
     cell is filled").
   - Loops through every empty peer and clears that digit's bit from
	 their masks.
6. Return true so the score loop restarts from the easiest technique.

If no cell qualifies, return false and the scorer moves on to the next
technique.

---

### Hidden Single

**What it is:** A digit that can only go in one cell of a unit (row,
column, or box), even if that cell has other candidates.

**Why it works:** The digit must appear somewhere in the unit. If only
one cell can possibly hold it, that cell must be it — regardless of the
cell's other candidates.

**Action:** Place the digit in that cell.

**Example:**
```
Box (3x3):
  5 _ _     The digit 7 appears as a candidate
  _ _ _     only in the top-right cell of this
  _ _ 7     box, so it must go there.
```

**Difficulty:** Easy. Still intuitive — no scanning across multiple
units required.

**How the program does it:**

1. Loop through all 27 units (9 rows, then 9 columns, then 9 boxes).
2. For each unit, loop through digits 1–9.
3. First check: is this digit already placed somewhere in the unit? If
   yes, skip it — we only care about digits that still need to go
   somewhere.
4. Otherwise, scan the 9 cells of the unit. Count how many empty cells
   have this digit as a candidate, and remember the last one seen.
5. If the count is exactly 1, that cell is the only place the digit can
   go. Place it via `place()` and return true.
6. If the count is 0 (digit can't go anywhere in this unit — a sign of
   a broken puzzle) or 2+, move on.


---

## Tier 2 — Subsets

### Naked Pair

**What it is:** Two cells in a unit that share the exact same two
candidates (e.g. both are `{3, 7}`).

**Why it works:** Those two cells must hold 3 and 7 in some order. No
other cell in the unit can be 3 or 7.

**Action:** Eliminate 3 and 7 from every other cell in the unit.

**Example:**
```
Row cells (candidates shown):
  A: {3, 7}
  B: {3, 7}
  C: {1, 3, 5, 7, 9}
  D: {2, 7, 9}
→ 3 and 7 are locked into A and B.
→ Remove 3 and 7 from C and D.
```

**Difficulty:** Easy-medium. First technique that requires holding two
cells in mind at once.

**How the program does it:**

1. Loop through all 27 units.
2. Build two parallel lists for the unit: the indices of its empty
   cells, and their candidate masks.
3. If fewer than 2 empty cells, skip the unit.
4. Enumerate every pair of empty-cell indices within the unit. For 9
   cells, that's 36 pairs.
5. For each pair, check that **both** masks have exactly 2 bits set.
   This is the crucial filter — a cell with 3+ candidates can't be part
   of a naked pair, even if it happens to share two candidates with
   another cell.
6. Combine the two masks with OR. If the result has more than 2 bits
   set, the pair isn't "naked" — skip.
7. Otherwise we have a naked pair. For every other empty cell in the
   unit, clear both pair bits from its mask (`mask &= ~pair_mask`).
8. If any mask actually changed, return true. If nothing changed (the
   eliminations were already done), keep looking.

Step 5 is where most naive implementations get it wrong. Consider
`{1,2,3}` and `{1,2}` in the same unit. Combined = `{1,2,3}`, which is
3 bits. Not a pair — the `{1,2,3}` cell has a third candidate and
could legitimately hold 3. Only when *both* cells are exactly
two-candidate does the logic hold.

---

### Hidden Pair

**What it is:** Two digits in a unit that can only go in the same two
cells (even if those cells have other candidates too).

**Why it works:** Those two digits must be placed in those two cells.
Any *other* candidate in those cells is impossible.

**Action:** Restrict those two cells to only the two hidden digits.

**Example:**
```
Unit cells (candidates shown):
  A: {1, 4, 7}
  B: {2, 4, 7}
  C: {1, 2, 4, 7}
  ...
Digits 4 and 7 both appear only in A and B.
So A = one of {4, 7}, B = the other.
Any other candidate in A or B (1 in A, 2 in B) is eliminated.
```

**Difficulty:** Medium. The insight is that *fewer* candidates is not
always easier — the constraint is on the digits, not the cells.

**How the program does it:**

1. Loop through all 27 units.
2. For the unit, build a map: digit → list of cells where that digit
   is still a candidate.
   - Skip any digit already placed in the unit (nothing to find).
   - Only keep digits that appear in **2 or more** empty cells. A digit
	 in 0 cells is impossible; in 1 cell it's already a hidden single
	 (which we try first).
3. Enumerate every pair of digits from that map.
4. Union the two cell lists for the pair.
5. If the union has exactly 2 cells, we have a hidden pair: two digits
   confined to two cells.
6. Build a mask containing only those two digits.
7. For each of the two cells, AND its candidate mask with that pair
   mask. This strips away every other candidate, leaving only the two
   hidden digits.
8. If anything changed, return true.

---

### Naked Triple

**What it is:** Three cells in a unit whose combined candidates total
exactly three digits.

**Why it works:** Same as naked pair, scaled up.

**Action:** Eliminate those three digits from the rest of the unit.

**Example:**
```
Row cells (candidates shown):
  A: {1, 2}
  B: {2, 3}
  C: {1, 3}
Combined: {1, 2, 3}
→ Remove 1, 2, 3 from all other cells in the row.
```

**Notes:** A naked triple can include cells with only 2 of the 3 digits
(as in the example above).

**Difficulty:** Medium.


**How the program does it:**

1. Loop through all 27 units.
2. Build the empty-cells list and their masks, same as naked pair.
3. Enumerate every combination of 3 empty cells (for 9 cells, that's
   84 combinations).
4. For each trio, check every cell's mask: each must have between 2
   and 3 bits set. A cell with 1 candidate would have been a naked
   single; a cell with 4+ can't participate.
5. OR the three masks together. If the union has more than 3 bits set,
   the trio isn't naked — skip.
6. Otherwise, clear all three digits from every other empty cell in
   the unit.
7. Return true if anything changed.

---

### Hidden Triple

**What it is:** Three digits that only fit in the same three cells of a
unit.

**Why it works:** Same as hidden pair, scaled up.

**Action:** Restrict those three cells to only those three digits.

**Example:**
```
Box cells (candidates shown):
  A: {1, 4, 5, 7, 9}
  B: {2, 4, 5, 8, 9}
  C: {3, 4, 5, 6, 9}
Digits 4, 5, 9 appear only in A, B, C.
→ Restrict A, B, C to only {4, 5, 9}.
```

**Difficulty:** Medium-hard. Much rarer than hidden pairs, and harder to
spot because the cells often have many candidates.

**How the program does it:**

1. Loop through all 27 units.
2. Build the same digit → cells map as hidden pair, filtering to digits
   that appear in 2 or more empty cells.
3. Enumerate every combination of 3 digits from that map.
4. Union their cell lists. Count the distinct cells.
5. If the union contains exactly 3 cells, we have a hidden triple.
6. Build a 3-digit mask and AND it into each of the 3 cells.
7. Return true if anything changed.

---

## Tier 3 — Intersections (planned)

### Pointing Pair / Triple

**What it is:** A digit whose only candidates within a box all lie in a
single row or column.

**Why it works:** The digit must be placed somewhere in that box, and
every option is in that row/column. So the digit must be somewhere in
that line too.

**Action:** Eliminate that digit from the rest of the row/column
(outside the box).

**Example:**
```
Box (top-left 3x3):
  row 0: _ 5 _     Digit 5 appears as a candidate
  row 1: _ 5 _     only in column 1 of this box.
  row 2: _ _ _
→ 5 is somewhere in column 1 of rows 0-2.
→ Remove 5 from column 1 in rows 3-8.
```

**Difficulty:** Medium. Requires scanning boxes and their overlaps with
rows/columns.

---

### Box-Line Reduction (Claiming)

**What it is:** The mirror of pointing pairs. A digit whose only
candidates within a row or column lie inside a single box.

**Why it works:** The digit must be in that line, and every option is in
that box. So the digit is in that box.

**Action:** Eliminate that digit from the rest of the box.

**Example:**
```
Row 3: candidates for 5 only at columns 6 and 7.
Columns 6 and 7 in row 3 both belong to the top-right box.
→ 5 must be in row 3 within the top-right box.
→ Remove 5 from row 4 and row 5 of the top-right box.
```

**Difficulty:** Medium.

---

## Tier 4 — Fish (planned)

### X-Wing

**What it is:** A single digit that appears as a candidate in exactly
two cells of one row, and those two cells share a column with two cells
of another row with the same pattern.

**Why it works:** In each of the two rows, the digit must go in one of
its two cells. The two placements are linked — one row picks the left
column, the other picks the right. Either way, the digit occupies both
columns.

**Action:** Eliminate the digit from all other cells in those two
columns.

**Example:**
```
Row 2: candidate for 7 at cols 3 and 7
Row 5: candidate for 7 at cols 3 and 7
→ 7 in row 2 is at col 3 or col 7.
→ 7 in row 5 is at the other.
→ Either way, 7 occupies cols 3 and 7.
→ Remove 7 from cols 3 and 7 in all other rows.
```

**Difficulty:** Hard. Requires cross-unit reasoning.

---

### Swordfish

**What it is:** The 3-row / 3-column generalization of X-Wing. A digit
that appears in 2–3 cells per row across 3 rows, confined to the same 3
columns.

**Why it works:** Across the 3 rows, the digit must occupy 3 distinct
columns drawn from the same set of 3. So those 3 columns are fully
consumed by the digit somewhere in the 3 rows.

**Action:** Eliminate the digit from those 3 columns in other rows.

**Example:**
```
Row 1: 7 in cols {2, 5}
Row 3: 7 in cols {2, 5, 8}
Row 6: 7 in cols {5, 8}
Columns involved: {2, 5, 8}
→ Remove 7 from cols 2, 5, 8 in rows other than 1, 3, 6.
```

**Difficulty:** Expert.

---

### Jellyfish

**What it is:** The 4-row / 4-column generalization.

**Why it works:** Same pattern as X-Wing and Swordfish, scaled to 4.

**Action:** Eliminate the digit from those 4 columns in other rows.

**Difficulty:** Very expert. Rarely needed for puzzles under ~20 clues.

---

## Tier 5 — Wings (planned)

### XY-Wing

**What it is:** Three cells: a "pivot" with candidates `{X, Y}`, and two
"wings" — one `{X, Z}`, one `{Y, Z}` — each a peer of the pivot, not of
each other. Any cell seeing both wings cannot be `Z`.

**Why it works:** Whichever value the pivot takes, one wing must be `Z`.

**Example:**
```
Pivot: {3, 5}
Wing 1: {3, 8}  (sees pivot)
Wing 2: {5, 8}  (sees pivot)
If pivot = 3, Wing 2 = 8. If pivot = 5, Wing 1 = 8.
Either way, one of the wings is 8.
→ Remove 8 from any cell seeing both wings.
```

**Difficulty:** Hard.

---

### XYZ-Wing

**What it is:** Variant of XY-Wing where the pivot also contains `Z`.

**Why it works:** Same logic, but eliminations are restricted to cells
visible to all three cells (pivot + both wings).

**Example:**
```
Pivot: {3, 5, 8}
Wing 1: {3, 8}
Wing 2: {5, 8}
→ Remove 8 from cells seeing all three cells.
```

**Difficulty:** Expert.

---

### W-Wing

**What it is:** Two cells with the same `{X, Y}` pair, connected by a
strong link on `Y`, imply an elimination on `X` in cells seeing both.

**Why it works:** The strong link forces one end to be `Y`. The other
end must therefore be `X`.

**Difficulty:** Expert.

---

## Tier 6 — Single-Digit Patterns (planned)

### Skyscraper

**What it is:** Two rows (or columns) where a digit appears exactly
twice, with one column aligned between them. The two "tops" of the
skyscraper see a common cell that can be eliminated.

**Why it works:** The two rows force the digit to one of two columns
each, and the shared column means one of the two "top" cells must be
the digit.

**Difficulty:** Expert.

---

### 2-String Kite

**What it is:** Two rows and two columns where the digit appears exactly
twice, forming a kite shape. The "tail" cells share a box and the
elimination happens at the intersection.

**Why it works:** A chained implication between the two rows and the two
columns forces the digit away from a specific cell.

**Difficulty:** Expert.

---

### Empty Rectangle

**What it is:** A digit confined to one row and one column inside a box,
plus a strong link elsewhere, yields an elimination.

**Why it works:** The confined pattern inside the box creates a local
implication that combines with the external strong link.

**Difficulty:** Expert.

---

## Tier 7 — Chains (planned)

### X-Chain

**What it is:** An alternating chain of strong and weak links on a
single digit. The endpoints of the chain eliminate the digit from cells
seeing both.

**Why it works:** Strong links force "at least one endpoint is true."
Weak links allow the implication to travel. If both endpoints see a
cell, that cell cannot contain the digit.

**Difficulty:** Expert.

---

### XY-Chain

**What it is:** Same idea as X-Chain, but each link is a `{X, Y}`-style
bivalue cell.

**Why it works:** Chains of bivalue cells carry a "which digit is left
over" implication from one end to the other.

**Difficulty:** Expert.

---

### AIC (Alternating Inference Chains)

**What it is:** The general form: any chain of strong and weak links on
any candidates. X-Chain and XY-Chain are special cases.

**Why it works:** Strong links = "at least one of these is true." Weak
links = "at most one of these is true." Alternating them across a chain
propagates implications.

**Difficulty:** Top expert. Where brute force starts to compete with
human reasoning.

---

## Tier 8 — Uniqueness (not huma possible/ not deductable)

### Unique Rectangle

**What it is:** Relies on the guarantee that the puzzle has exactly one
solution. A pattern that would force two solutions if certain candidates
were true can be eliminated.

**Why it works:** Four cells forming a rectangle, each containing the
same two candidates `{X, Y}`, would admit two valid solutions. Since the
puzzle has one, at least one of those cells must contain a third
candidate.

**Difficulty:** Contested. Some purists reject uniqueness-based
techniques because they rely on meta-knowledge of the puzzle rather than
the puzzle itself.

---

## How the scorer maps these to difficulty

| Band | Hardest technique allowed | Preferred clue range |
|------|---------------------------|----------------------|
| Beginner | Naked single | 45–60 |
| Easy | Hidden single | 38–52 |
| Medium | Naked pair, hidden pair | 30–42 |
| Hard | Naked triple, hidden triple, pointing, box-line, X-Wing | 24–34 |
| Extreme | Swordfish, Jellyfish, wings, single-digit patterns, chains | 20–30 |


Each puzzle's score is the *hardest* technique it required. Puzzles
whose score exceeds our highest implemented technique get `STUCK`,
meaning "requires something we can't handle yet."
