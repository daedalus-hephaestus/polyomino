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

// Stores the polyomino in a 128x64 grid
// Currently only able to store every version of 62-ominoes, but I hope to
// make it dynamically scalable eventually
Field :: [64][128]FieldState

NewField :: [dynamic][dynamic]FieldState

make_field :: proc(origin: Cell = {1, 0}, size: [2]int = {3, 2}) -> NewField {
	res : NewField

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

destroy_field :: proc(field: NewField) {
	for row in field do delete(row) 
	delete(field)
}

grow_field :: proc(field: ^NewField, dir: Direction) {
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

get_free :: proc(field: ^NewField, free: ^[dynamic]Cell) {
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

add_cell_from_free :: proc(field: ^NewField, free: []Cell, index: int) -> FieldError {
	if index >= len(free) do return .OUT_OF_RANGE_FREE 

	for cell in free[:index] {
		if field[cell.y][cell.x] != .FREE {
			fmt.println(cell)
			return .NOT_FREE
		}
		field[cell.y][cell.x] = .CHECKED
	}

	err := add_cell(field, free[index])
	return err 
}

add_cell :: proc(field: ^NewField, cell: Cell) -> FieldError {
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

draw_cell :: proc(field: ^NewField, cell: Cell, value: FieldState) {
	cur_coords := cell
	size := [2]int{ len(field[0]), len(field) }

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

print_field :: proc(field: NewField) {
	for y := len(field) - 1; y >= 0; y -= 1 {
		for cell, x in field[y] {
			switch cell {
			case .OCCUPIED:
				fmt.print("#")
			case .FREE:
				fmt.print(" ")
			case .CHECKED:
				fmt.print(".")
			case .BORDER:
				fmt.print("_")
			}
		}
		fmt.println("")
	}
}

newfield_to_polyomino :: proc(field: NewField) -> NewPolyomino {
	res := make_polyomino()
	carry := 0
	cur_index := 1
	dum := make_field(get_origin(field), { len(field[0]), len(field) })
	defer destroy_field(dum)
	free : [dynamic]Cell
	defer delete(free)

	outer: for {
		get_free(&dum, &free)
		if len(free) == 0 {
			fmt.println("no spaces")
			break outer
		}

		for cell, i in free {
			cur_index += 1

			if cur_index > 128 {
				append(&res.bin, 0)
				cur_index = 1
				carry += 1
			}

			fmt.println(field[cell.y][cell.x])
			if field[cell.y][cell.x] == .OCCUPIED {
				err := add_cell_from_free(&dum, free[:], i)
				res.bin[carry] |= u128(1) << uint(cur_index - 1)
				break
			} else if i == len(free) - 1 {
				fmt.println(free)
				fmt.println("reached end of free")
				break outer
			}
		}
	}
	return res
}

get_origin :: proc(field: NewField) -> Cell {
	for cell, i in field[0] {
		if cell == .OCCUPIED do return { i, 0 }
	}
	return { -1, -1 }
}




init_field :: proc() -> Field {
	field : Field
	field[0][65] = .OCCUPIED
	for i := 0; i < 65; i += 1 do field[0][i] = .BORDER
	return field
}


polyomino_to_field :: proc(poly: Polyomino) -> (Field, bool) {
	carry := 0

	res := init_field()
	free : [dynamic]Cell
	defer delete(free)

	bounds := [4]int{ 64, 0, 66, 1 }

	last := poly.bin[len(poly.bin) - 1]
	last_len := 128 - bits.count_leading_zeros(last)

	calc_free(&free, bounds, &res)

	skip := 0
	for seg, i in poly.bin {
		is_last := i == len(poly.bin) - 1
		cur_len := 128 - bits.count_leading_zeros(last)

		for j :uint = 0; j < 128; j += 1 {
			if i == 0 && j == 0 do continue
			if is_last && j == uint(last_len) do break
			if last == 0 && j == uint(cur_len) && i + 2 == len(poly.bin) do break

			if bit_at(j, seg) == 1 {
				if skip > len(free) - 1 {
					return res, false
				}
				
				cell := free[skip]
				res[cell.y][cell.x] = .OCCUPIED
				if cell.y >= bounds[3] do bounds[3] = cell.y + 1
				if cell.x <= bounds[0] do bounds[0] = cell.x - 1
				if cell.x >= bounds[2] do bounds[2] = cell.x + 1

				skip = 0
				calc_free(&free, bounds, &res)
			} else if bit_at(j, seg) == 0 {
				if skip > len(free) - 1 {
					return res, false
				}
				
				cell := free[skip]
				res[cell.y][cell.x] = .CHECKED
				skip += 1 
			}
		}
	}

	return res, true
}
