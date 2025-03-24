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

// The tile size for the raylib window
tile :i32 = 10
origin := [2]i32{ tile * 64, tile * 64 }

// The field that stores the currently displayed polyomino
screen_field := make_field() 
// The polyomino being displayed on the screen
screen_poly : Polyomino
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

	screen_poly = field_to_polyomino(screen_field)
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
			screen_poly = field_to_polyomino(screen_field)
			filtered := filter_field(screen_field)

			print_field(filtered)
			fmt.println("")
			rotate_field(&filtered)
			print_field(filtered)

			unfiltered := unfilter_field(filtered)
			destroy_field(filtered)

			new_poly := field_to_polyomino(unfiltered)
			fmt.printfln("%b", new_poly.bin)

			destroy_field(unfiltered)
			destroy_polyomino(&new_poly)

		}

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

//generate_random :: proc (size: int) -> Polyomino {
//	result : Polyomino
//
//	append(&result.bin, 0b1)
//	str_length := 1 
//	carry :uint = 0 
//
//	length :int = 1
//	bounds := [4]int{64, 0, 66, 1}
//
//	free : [dynamic]Cell
//	defer delete(free)
//
//	field := init_field()
//
//	for length < size {
//		calc_free(&free, bounds, &field)
//
//		if len(free) == 0 do break
//		rand_index := rand.int_max(len(free))
//
//		for cell, i in free {
//			str_length += 1
//			if str_length > 128 {
//				append(&result.bin, 0)
//				str_length = 1
//				carry += 1 
//			}
//
//			if i == rand_index {
//				field[cell.y][cell.x] = .OCCUPIED
//				if cell.y >= bounds[3] do bounds[3] = cell.y + 1
//				if cell.x <= bounds[0] do bounds[0] = cell.x - 1
//				if cell.x >= bounds[2] do bounds[2] = cell.x + 1
//
//				result.bin[carry] |= u128(0b1) << uint(str_length - 1)
//
//				break
//			} else {
//				field[cell.y][cell.x] = .CHECKED
//			}
//		}
//		length += 1
//	}
//
//	return result
//}
