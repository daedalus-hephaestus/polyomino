#+feature dynamic-literals
package polyomino

import "core:fmt"
import "core:os"
import "core:mem"
import "core:math/rand"
import str "core:strings"
import bits "core:math/bits"
import rl "vendor:raylib"

// A001168 - Number of fixed polyominoes with n cells

// The polyomino - data is stored in the bin (binary) field as a dynamic array
// of 128 bit unsigned-integers. The array can grow to the right as more bits are
// added to the Polyomino. The bin_str is a cstring which stores the binary data
// as a string (currently inverted)
Polyomino :: struct {
	bin: [dynamic]u128,
	bin_str: cstring
}

// The tile size for the raylib window
tile :i32 = 10
origin := [2]i32{ tile * 64, tile * 64 }

// The field that stores the currently displayed polyomino
screen_field := make_field() 
// The polyomino being displayed on the screen
screen_poly := newfield_to_polyomino(screen_field) 
// Whether or not the currently displayed polyomino is valid
valid : bool

// The polyomino being intially loaded - will change to paste eventually
init_bin :cstring = ""
init_size : int
cur_index := 0

main :: proc() {
	// memory leak detection
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

	defer destroy_field(screen_field)
	defer destroy_polyomino(&screen_poly)
	init_window()
	draw_window()
}

// Intializes the raylib window
init_window :: proc () {
	rl.InitWindow(128 * tile, 64 * tile + 100, "Polyominoes")
	rl.SetTraceLogLevel(.ERROR)
}

draw_window :: proc () {
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		rl.SetTargetFPS(60)

		origin := get_origin(screen_field)
		offset := [2]i32{
			64 - i32(origin.x),
			64
		}
		for y := len(screen_field) - 1; y >= 0; y -= 1 {
			row := screen_field[y]
			for cell, x in row {
				switch cell {
				case .FREE:
					// rl.DrawRectangle((i32(x) + offset.x) * tile, (-i32(y) + offset.y) * tile, tile, tile, rl.PINK)
				case. BORDER:
					rl.DrawRectangle((i32(x) + offset.x) * tile, (-i32(y) + offset.y) * tile, tile, tile, rl.BLACK)
				case. OCCUPIED:
					rl.DrawRectangle((i32(x) + offset.x) * tile, (-i32(y) + offset.y) * tile, tile, tile, rl.GREEN)
				case. CHECKED:
				}
			}
		}

		mouse := Cell{
			int(rl.GetMouseX() / tile - offset.x),
			-int(rl.GetMouseY() / tile - offset.y)
		}

		if rl.IsMouseButtonDown(.LEFT) && mouse.y >= 0 {
			draw_cell(&screen_field, mouse, .OCCUPIED)
		} else if rl.IsMouseButtonDown(.RIGHT) && mouse.y >= 0 {
			draw_cell(&screen_field, mouse, .FREE)
		}

		if rl.IsMouseButtonReleased(.LEFT) || rl.IsMouseButtonReleased(.RIGHT) {
			destroy_polyomino(&screen_poly)
			print_field(screen_field)
			screen_poly = newfield_to_polyomino(screen_field)	
			fmt.printfln("%b", screen_poly.bin)
		}


		rl.EndDrawing()
	}

	rl.CloseWindow()
}

generate_random :: proc (size: int) -> Polyomino {
	result : Polyomino

	append(&result.bin, 0b1)
	str_length := 1 
	carry :uint = 0 

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
				append(&result.bin, 0)
				str_length = 1
				carry += 1 
			}

			if i == rand_index {
				field[cell.y][cell.x] = .OCCUPIED
				if cell.y >= bounds[3] do bounds[3] = cell.y + 1
				if cell.x <= bounds[0] do bounds[0] = cell.x - 1
				if cell.x >= bounds[2] do bounds[2] = cell.x + 1

				result.bin[carry] |= u128(0b1) << uint(str_length - 1)

				break
			} else {
				field[cell.y][cell.x] = .CHECKED
			}
		}
		length += 1
	}

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


field_to_polyomino :: proc(field: Field) -> Polyomino {
	res : Polyomino
	append(&res.bin, 0b1)
	carry := 0 
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
				append(&res.bin, 0)
				str_length = 1
				carry += 1 
			}

			if field[cell.y][cell.x] == .OCCUPIED {
				dum[cell.y][cell.x] = .OCCUPIED
				if cell.y >= bounds[3] do bounds[3] = cell.y + 1
				if cell.x <= bounds[0] do bounds[0] = cell.x - 1
				if cell.x >= bounds[2] do bounds[2] = cell.x + 1

				res.bin[carry] |= u128(0b1) << uint(str_length - 1)
				break
			} else {
				dum[cell.y][cell.x] = .CHECKED
			}
		}
	}

	res.bin_str = binary_to_string(res)
	return res
}

binary_to_string :: proc(poly: Polyomino) -> cstring {
	build := str.builder_make()
	last := poly.bin[len(poly.bin) - 1]
	last_len := 128 - bits.count_leading_zeros(last)

	for seg, i in poly.bin {
		is_last := i == len(poly.bin) - 1
		cur_len := 128 - bits.count_leading_zeros(seg)

		for j :uint = 0; j < 128; j += 1 {
			if is_last && j == uint(last_len) do break
			if last == 0 && j == uint(cur_len) && i + 2 == len(poly.bin) do break
			str.write_int(&build, bit_at(j, seg))
		}
	}

	out_str, _ := str.clone_to_cstring(str.to_string(build))
	str.builder_destroy(&build)
	return out_str 
}

string_to_binary :: proc(str: cstring) -> Polyomino {
	res : Polyomino
	reg_str := string(str)

	append(&res.bin, 0)

	carry := 0
	cur_len :uint = 0

	for char in reg_str {
		add_val := (char == '1' ? u128(0b1) : u128(0b0)) << cur_len
		res.bin[carry] |= add_val
		cur_len += 1
		if cur_len == 128 {
			cur_len = 0
			carry += 1
			append(&res.bin, 0)
		}
	}

	fmt.printfln("%b", res.bin)

	return res	
}

bit_at :: proc(i: uint, b: u128) -> int {
	shift := (b >> i) & 0b1
	return shift == 1 ? 1 : 0
}

dec_polyomino :: proc(poly: ^Polyomino) -> bool {
	i := 0
	for {
		new_val := poly^.bin[i] - 1
		if new_val > poly.bin[i] {
			if len(poly.bin) - 1 == i {
				return true
			} else {
				poly.bin[i] = new_val
				i += 1
			}
		} else {
			poly.bin[i] = new_val 
			return false
		}
	}
}

valid_polyomino :: proc(poly: Polyomino, size: int) -> bool {
	cells := 0
	for i in poly.bin do cells += int(bits.count_ones(i))
	if cells != size do return false

	_, valid := polyomino_to_field(poly)
	return valid 
}

get_polyomino_size :: proc(poly: Polyomino) -> int {
	cells := 0
	for i in poly.bin do cells += int(bits.count_ones(i))
	return cells
}
