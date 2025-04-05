#+feature dynamic-literals
package polyomino

import "core:fmt"
import "core:os"
import "core:mem"
import "core:math/rand"
import str "core:strings"
import bits "core:math/bits"
import rl "vendor:raylib"
import "core:sync"
import "core:thread"
import "core:time"
import "core:flags"

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

stopwatch : time.Stopwatch

Mode :: enum {
	INDEX,
	COUNT,
	COUNTALL
}

Type :: enum {
	FIXED,
	FREE
}

Options :: struct {
	threads: int,
	index: u128,
	size: int,
	timer: bool,
	print: u128,
	mode: Mode,
	type: Type
}

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

	//tmp_calc()

	opt : Options
	flags.parse_or_exit(&opt, os.args, .Unix) 
	if opt.timer do time.stopwatch_start(&stopwatch)

	fmt.printf("\033[s")
	if opt.mode == .INDEX {
		calc_polyomino(opt.size, opt.threads, opt.index, opt.print)
	} else if opt.mode == .COUNT {
		if opt.type == .FREE {
			calc_length_free(opt.size, opt.threads, opt.index)
		} else if opt.type == .FIXED {
			calc_length_fixed(opt.size, opt.threads, opt.index)
		}
	} else if opt.mode == .COUNTALL {
		if opt.type == .FREE {
			for i in opt.size..=(opt.size - 1) * 3 {
				fmt.printf("\033[s")
				calc_length_free(opt.size, opt.threads, u128(i))
			}
		} else if opt.type == .FIXED {
			for i in opt.size..=(opt.size - 1) * 3 {
				fmt.printf("\033[s")
				calc_length_fixed(opt.size, opt.threads, u128(i))
			}
		}
	}

	if opt.timer {
		time.stopwatch_stop(&stopwatch)
		fmt.println(time.clock_from_stopwatch(stopwatch))
	}
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
		}

		rl.EndDrawing()
	}

	rl.CloseWindow()
}
