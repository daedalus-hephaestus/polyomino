package polyomino

import "core:fmt"
import bits "core:math/bits"

// The possible field states:
// Free - an empty cell
// Occupied - a filled cell
// Checked - a cell that isn't occupied, but can't be filled
// Border - Stops the polyomino from growing below the origin
FieldState :: enum {
	FREE,
	OCCUPIED,
	CHECKED,
	BORDER
}

Direction :: enum {
	UP,
	LEFT,
	RIGHT
}

// Stores the coordinates of a cell in a field
Cell :: [2]int

FieldError :: enum {
	NONE,
	OUT_OF_RANGE_FREE,
	OUT_OF_RANGE_X,
	OUT_OF_RANGE_Y,
	NOT_FREE
}

Field :: [dynamic][dynamic]FieldState
FilteredField :: Field

make_field :: proc(origin: Cell = {1, 0}, size: [2]int = {3, 2}) -> Field {
	res : Field

	for i in 0..< size.y {
		row := make([dynamic]FieldState, size.x)
		append(&res, row)
	}

	// set the origin to occupied
	res[origin.y][origin.x] = .OCCUPIED
	for i in 0..<origin.x {
		res[0][i] = .BORDER
	}
	return res
}

destroy_field :: proc(field: Field) {
	for row in field do delete(row) 
	delete(field)
}

grow_field :: proc(field: ^Field, dir: Direction) {
	switch dir {
	case .UP:
		append(field, make([dynamic]FieldState, len(field^[0])))
	case .LEFT:
		for &row, i in field {
			if i == 0 {
				inject_at(&row, 0, FieldState(.BORDER))
			} else {
				inject_at(&row, 0, FieldState(.FREE))
			}
		}
	case .RIGHT:
		for &row in field do append(&row, FieldState(.FREE))
	}
}

get_free :: proc(field: ^Field, free: ^[dynamic]Cell) {
	clear(free)		

	for row, y in field {
		for cell, x in row {
			if cell == .OCCUPIED || cell == .BORDER || cell == .CHECKED do continue	

			if y - 1 >= 0 && field[y - 1][x] == .OCCUPIED {
				append(free, Cell{x, y})
				continue
			} else if y + 1 < len(field) && field[y + 1][x] == .OCCUPIED {
				append(free, Cell{x, y})
			} else if x - 1 >= 0 && field[y][x - 1] == .OCCUPIED {
				append(free, Cell{x, y})
				continue
			} else if x + 1 < len(field[0]) && field[y][x + 1] == .OCCUPIED {
				append(free, Cell{x, y})
				continue
			}
		}
	}	
}

add_cell_from_free :: proc(field: ^Field, free: []Cell, index: int) -> FieldError {
	if index >= len(free) do return .OUT_OF_RANGE_FREE 

	for cell in free[:index] {
		if field[cell.y][cell.x] != .FREE {
			return .NOT_FREE
		}
		field[cell.y][cell.x] = .CHECKED
	}
	err := add_cell(field, free[index])
	return err 
}

add_cell :: proc(field: ^Field, cell: Cell) -> FieldError {
	size := [2]int{ len(field[0]), len(field) }
	if cell.y >= size.y || cell.y < 0 do return .OUT_OF_RANGE_Y 
	if cell.x >= size.x || cell.x < 0 do return .OUT_OF_RANGE_X

	target := field[cell.y][cell.x]
	if target != .FREE do return .NOT_FREE

	field[cell.y][cell.x] = .OCCUPIED
	if cell.y == size.y - 1 do grow_field(field, .UP)
	if cell.x == 0 do grow_field(field, .LEFT)
	if cell.x == size.x - 1 do grow_field(field, .RIGHT)
	return .NONE
}

draw_cell :: proc(field: ^Field, cell: Cell, value: FieldState) {
	cur_coords := cell
	size := [2]int{ len(field[0]), len(field) }

	origin := get_origin(field^)
	if origin == cur_coords do return

	for cur_coords.y + 1 >= size.y {
		grow_field(field, .UP)
		size.y = len(field)
	}
	for cur_coords.x - 1 < 0 {
		cur_coords.x += 1
		grow_field(field, .LEFT)
		size.x = len(field[0])
	}
	for cur_coords.x + 1 >= size.x {
		grow_field(field, .RIGHT)
		size.x = len(field[0])
	}
	if field[cur_coords.y][cur_coords.x] != .BORDER {
		field[cur_coords.y][cur_coords.x] = value
	}
}

print_field :: proc(field: Field) {
	for y := len(field) - 1; y >= 0; y -= 1 {
		for cell, x in field[y] {
			switch cell {
			case .OCCUPIED:
				fmt.print("#")
			case .FREE:
				fmt.print(".")
			case .CHECKED:
				fmt.print(".")
			case .BORDER:
				fmt.print("_")
			}
		}
		fmt.println("")
	}
}

field_to_polyomino :: proc(field: Field) -> Polyomino {
	res := make_polyomino()
	carry := 0
	cur_index := 1
	dum := make_field(get_origin(field), { len(field[0]), len(field) })
	defer destroy_field(dum)
	free : [dynamic]Cell
	defer delete(free)

	outer: for {
		get_free(&dum, &free)
		if len(free) == 0 do break outer
		for cell, i in free {
			cur_index += 1

			if cur_index > 128 {
				append(&res.bin, 0)
				cur_index = 1
				carry += 1
			}
			if field[cell.y][cell.x] == .OCCUPIED {
				err := add_cell_from_free(&dum, free[:], i)
				res.bin[carry] |= u128(1) << uint(cur_index - 1)
				break
			} else if i == len(free) - 1 {
				break outer
			}
		}
	}
	return res
}

get_origin :: proc(field: Field) -> Cell {
	for cell, i in field[0] {
		if cell == .OCCUPIED do return { i, 0 }
	}
	return { -1, -1 }
}

filter_field :: proc(field: Field) -> FilteredField {
	empty_field : FilteredField

	keep_col := make(map[int]bool)
	keep_row := make(map[int]bool)
	defer delete(keep_col)
	defer delete(keep_row)

	offset := [2]int{ -1, -1 }

	for row, y in field {
		for val, x in row {
			if val == .OCCUPIED {
				keep_col[x] = true
				keep_row[y] = true
				if offset.x == -1 || x < offset.x do offset.x = x
				if offset.y == -1 || y < offset.y do offset.y = y
			}			
		}
	}
	size := [2]int{ len(keep_col), len(keep_row) }
	for i in 0..<size.y do append(&empty_field, make([dynamic]FieldState, size.x))

	for y := offset.y; y - offset.y < size.y; y += 1 {
		for x := offset.x; x - offset.x < size.x; x += 1 {
			if field[y][x] == .OCCUPIED do empty_field[y - offset.y][x-offset.x] = .OCCUPIED 
		}
	}
	return empty_field
}

copy_field :: proc(field: Field) -> Field {
	res : Field
	for row, y in field {
		append(&res, make([dynamic]FieldState))
		for val, x in row {
			append(&res[y], val)
		}
	}
	return res
}

flip_field :: proc(field: ^Field) {
	tmp_field := copy_field(field^)
	defer destroy_field(tmp_field)

	for row, y in tmp_field {
		i := len(row) - 1 
		for val, x in row {
			field[y][i] = val
			i -= 1
		}
	}
}

rotate_field :: proc(field: ^Field) {
	tmp_field := copy_field(field^)
	defer destroy_field(tmp_field)

	for i in field do delete(i)
	clear(field)

	for _, x in tmp_field[0] {
		append(field, make([dynamic]FieldState, len(tmp_field)))
	}

	for row, y in tmp_field {
		i := len(row) - 1
		for val, x in row {
			field[i][y] = val
			i -= 1
		}
	}
	
}

unfilter_field :: proc(field: FilteredField) -> Field {
	res := copy_field(field) 

	end_border := false
	for val, x in res[0] {
		if !end_border && val == .FREE do res[0][x] = .BORDER	
		if val == .OCCUPIED do end_border = true
	}

	grow_field(&res, .LEFT)
	grow_field(&res, .RIGHT)
	grow_field(&res, .UP)

	return res
}

field_variations :: proc(field: Field) -> Variations {
	res : Variations
	filtered := filter_field(field)
	defer destroy_field(filtered)

	res[0] = field_to_polyomino(field)

	for i in 1..<8 {
		rotate_field(&filtered)
		if i == 4 do flip_field(&filtered)

		tmp_field := unfilter_field(filtered)
		defer destroy_field(tmp_field)

		res[i] = field_to_polyomino(tmp_field)
	}

	return res
}
