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
	COUNTALL,
	RANDOM,
	BENCHMARK,
	SAVE
}

Type :: enum {
	FIXED,
	FREE
}

Time :: [3]int

Options :: struct {
	threads: int `usage:"The number of threads to utilize"`,
	index: u128 `usage:"INDEX mode: the index to go to
	COUNT mode: The length of the polyomino binary string"`,
	size: int `args:"required" usage:"The size of the polyomino"`,
	timer: bool `usage:"Whether or not to time the run"`,
	print: u128 `usage:"When to print in index mode (0=only the last, n=print every nth polyomino)"`,
	mode: Mode `args:"required" usage:"INDEX: Get the polyomino at index
	COUNT: count all polyominos of string length index
	COUNTALL: count all polyominos of all possible string lengths
	RANDOM: get a random polyomino
	BENCHMARK: calculates the average time to generate a random polyomino"`,
	type: Type `usage:"FIXED: run mode on fixed polyominos (default)
	FREE: run mode on free polyominos"`
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

	opt : Options
	flags.parse_or_exit(&opt, os.args, .Unix)

	if opt.threads == 0 do opt.threads = 16

	if opt.timer || opt.mode == .BENCHMARK do time.stopwatch_start(&stopwatch)

	if opt.mode == .INDEX {
		if opt.type == .FREE{
			poly :=	index_polyomino_free(opt.size, opt.threads, opt.index, opt.print)
			destroy_polyomino(&poly)
		} else if opt.type == .FIXED {
			poly := index_polyomino_fixed(opt.size, opt.threads, opt.index, opt.print)
			fmt.println(poly)
			destroy_polyomino(&poly)
		}
	} else if opt.mode == .COUNT {
		if opt.type == .FREE {
			fmt.printfln("Counting free %v-ominos with string length %v", opt.size, opt.index)
			fmt.println("---------------------------------------------------------------")

			count, checked := count_length_free(opt.size, opt.threads, opt.index, opt.print)

			fmt.printfln("Found: %v - Checked: %v\n", count, checked)
		} else if opt.type == .FIXED {
			fmt.printfln("Counting fixed %v-ominos with string length %v", opt.size, opt.index)
			fmt.println("---------------------------------------------------------------")

			count, checked := count_length_fixed(opt.size, opt.threads, opt.index, opt.print)

			fmt.printfln("Found: %v - Checked: %v\n", count, checked)
		}
	} else if opt.mode == .COUNTALL {
		if opt.type == .FREE {
			max := (opt.size - 1) * 3
			if opt.size >= 9 do max -= 4

			total : u128
			
			fmt.printfln("Counting free %v-ominos", opt.size)
			fmt.println("---------------------------------------------------------------")

			progress := int(opt.index) > opt.size ? int(opt.index) : opt.size

			for i in progress..=max {
				count, checked := count_length_free(opt.size, opt.threads, u128(i), opt.print)
				if count <= 0 do break

				total += count
				fmt.printfln("string: %v | %v of %v\n", i, count, checked)
			}

			fmt.println("---------------------------------------------------------------")
			fmt.printfln("TOTAL: %v", total)
		} else if opt.type == .FIXED {
			total : u128

			fmt.printfln("Counting fixed %v-ominos", opt.size)
			fmt.println("---------------------------------------------------------------")

			progress := int(opt.index) > opt.size ? int(opt.index) : opt.size

			for i in progress..=(opt.size - 1) * 3 {
				count, checked := count_length_fixed(opt.size, opt.threads, u128(i), opt.print)
				if count <= 0 do break

				total += count
				fmt.printfln("string: %v | %v of %v\n", i, count, checked)
			}

			fmt.println("---------------------------------------------------------------")
			fmt.printfln("TOTAL: %v", total)
		}
	} else if opt.mode == .RANDOM {
		if opt.type == .FREE {
			poly := find_random_free(opt.size, opt.threads)
			fmt.println(poly)
			destroy_polyomino(&poly)
		}	else if opt.type == .FIXED {
			poly := find_random_fixed(opt.size, opt.threads)
			fmt.println(poly)
			destroy_polyomino(&poly)
		}
	} else if opt.mode == .BENCHMARK {

		times : [dynamic]Time
		defer delete(times)

		for {
			if opt.type == .FREE {
				find_random_free(opt.size, opt.threads)
			}	else if opt.type == .FIXED {
				find_random_fixed(opt.size, opt.threads)
			}

			time.stopwatch_stop(&stopwatch)
			
			t := get_time(stopwatch)
			fmt.printf("found 1 after: ")
			print_time(t)
			append(&times, t)

			avg := average_time(times)
			fmt.printf("new average: ")
			print_time(avg)

			time.stopwatch_reset(&stopwatch)
			time.stopwatch_start(&stopwatch)
		}
	} else if opt.mode == .SAVE {
			
	}

	if opt.timer {
	 	time.stopwatch_stop(&stopwatch)
		t := get_time(stopwatch)
		print_time(t)
	}
}

get_time :: proc(watch: time.Stopwatch) -> Time {
	h, m, s := time.clock_from_stopwatch(watch)
	return {h, m, s}
}
print_time :: proc(t: Time) {
	fmt.printfln("%vh %vm %vs", t[0], t[1], t[2])
}
average_time :: proc(times: [dynamic]Time) -> Time {
	final : Time

	for t in times {
		final += t	
	}

	return final / len(times)
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
