#+feature dynamic-literals
package polyomino

import "core:fmt"
import "core:os"
import "core:mem"
import "core:math/rand"
import rl "vendor:raylib"

// A001168 - Number of fixed polyominoes with n cells

// The polyomino, maximum size of 64
Polyomino :: struct {
	string: [2]u128
}

Cell :: [2]int

FieldValue :: enum {
	FREE,
	OCCUPIED,
	CHECKED,
	BORDER
}
Field :: [64][128]FieldValue

PolyominoIndex :: struct {
	
}

tile :i32 = 10
new_click := true
del_mode := false
screen := init_field() 

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				for _, entry in track.allocation_map {
					fmt.eprintf("%v leaked %v bytes\n", entry.location, entry.size)
				}
			}
			if len(track.bad_free_array) > 0 {
				for entry in track.bad_free_array {
					fmt.eprintf("%v bad free at %v\n", entry.location, entry.memory)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}
	buf: [256]byte

	init_window()
	draw_window()
	/*for {
		num_bytes, err := os.read(os.stdin, buf[:])
		generate_random(64)
	}*/
}

init_window :: proc () {
	rl.InitWindow(128 * tile, 64 * tile, "Polyominoes")
	rl.SetTraceLogLevel(.ERROR)
}

init_field :: proc() -> Field {
	field : Field
	field[0][65] = .OCCUPIED
	for i := 0; i < 65; i += 1 do field[0][i] = .BORDER
	return field
}

draw_window :: proc () {
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		rl.SetTargetFPS(60)

		for y := len(screen) - 1; y >= 0; y -= 1 {
			for x := 0; x < len(screen[0]); x += 1 {
				c := [2]i32{ i32(x) * tile, 64 * tile - i32(y + 1) * tile }
				
				switch screen[y][x] {
				case .OCCUPIED:
					rl.DrawRectangle(c.x, c.y, tile, tile, rl.GREEN)
				case .FREE:
				case .CHECKED:
				case .BORDER:
					rl.DrawRectangle(c.x, c.y, tile, tile, rl.BLACK)
				}
			}
		}

		mouse := [2]i32{ rl.GetMouseX() / tile, (64 * tile - rl.GetMouseY()) / tile }

		if rl.IsMouseButtonDown(.LEFT) {
			if mouse.x > 0 && mouse.x < 128 && mouse.y >= 0 && mouse.y <= 64 {
				val := screen[mouse.y][mouse.x]

				if new_click {
					del_mode = val == .OCCUPIED
					new_click = false
				}

				if screen[mouse.y][mouse.x] == .OCCUPIED && mouse != {0, 65} && del_mode {
					screen[mouse.y][mouse.x] = .FREE
				} else if screen[mouse.y][mouse.x] == .FREE && !del_mode {
					screen[mouse.y][mouse.x] = .OCCUPIED
				}
			}
		}

		if rl.IsMouseButtonReleased(.LEFT) {
			new_click = true
			fmt.printfln("%b", field_to_polyomino(screen).string)
		}
			
		rl.EndDrawing()
	}
	

	rl.CloseWindow()
}

generate_random :: proc (size: int) -> Polyomino {
	result : Polyomino

	result.string[1] = 0b1
	str_length := 1 
	carry :uint = 1 

	length :int = 1
	bounds := [4]int{64, 0, 66, 1}

	free : [dynamic]Cell
	defer delete(free)

	field := init_field()

	for length < size {
		calc_free(&free, bounds, &field)
	
		if len(free) == 0 do break
		rand_index := rand.int_max(len(free))

		for cell, i in free {
			str_length += 1
			if str_length > 128 {
				str_length = 1
				carry = 0
			}

			if i == rand_index {
				field[cell.y][cell.x] = .OCCUPIED
				if cell.y >= bounds[3] do bounds[3] = cell.y + 1
				if cell.x <= bounds[0] do bounds[0] = cell.x - 1
				if cell.x >= bounds[2] do bounds[2] = cell.x + 1

				result.string[carry] |= u128(0b1) << uint(str_length - 1)

				break
			} else {
				field[cell.y][cell.x] = .CHECKED
			}
		}
		length += 1
	}

	draw_field(field)
	fmt.printfln("%b", result.string)

	return result
}

calc_free :: proc(free: ^[dynamic]Cell, bounds: [4]int, field: ^Field) {

	clear(free)

	range := field[0:bounds[3] + 1] 

	for row, y in range {
		for x := bounds[0]; x <= bounds[2]; x += 1 {
			val := row[x]
			if row[x] == .OCCUPIED || row[x] == .BORDER || row[x] == .CHECKED do continue

			if y - 1 >= 0 && range[y - 1][x] == .OCCUPIED {
				append(free, Cell{x, y})
				continue
			} else if y + 1 < len(range) && range[y + 1][x] == .OCCUPIED {
				append(free, Cell{x, y})
				continue
			} else if x - 1 >= 0 && range[y][x - 1] == .OCCUPIED {
				append(free, Cell{x, y})
				continue
			} else if x + 1 < len(range[0]) && range[y][x + 1] == .OCCUPIED {
				append(free, Cell{x, y})
				continue
			}
		}
	}
}

draw_field :: proc(field: Field) {
	for y := len(field) - 1; y >= 0; y -= 1 {
		for x := 0; x < len(field[0]); x += 1 {
			switch field[y][x] {
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

field_to_polyomino :: proc(field: Field) -> Polyomino {
	res : Polyomino
	res.string[1] = 0b1
	carry := 1
	str_length := 1

	dum := init_field()
	free : [dynamic]Cell
	defer delete(free)
	bounds := [4]int{ 64, 0, 66, 1 }
	
	for {
		calc_free(&free, bounds, &dum)
		if len(free) == 0 do break

		for cell, i in free {
			str_length += 1
			if str_length > 128 {
				str_length = 1
				carry = 0
			}

			if field[cell.y][cell.x] == .OCCUPIED {
				dum[cell.y][cell.x] = .OCCUPIED
				if cell.y >= bounds[3] do bounds[3] = cell.y + 1
				if cell.x <= bounds[0] do bounds[0] = cell.x - 1
				if cell.x >= bounds[2] do bounds[2] = cell.x + 1

				res.string[carry] |= u128(0b1) << uint(str_length - 1)
				break
			} else {
				dum[cell.y][cell.x] = .OCCUPIED
			}
		}
	}

	return res
}
