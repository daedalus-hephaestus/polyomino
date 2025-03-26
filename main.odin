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

max_threads :: 15 

polyomino_size :: 20 
polyomino_index :: 10000 

stopwatch : time.Stopwatch


Index :: [dynamic]u128

IsValid :: enum {
	UNCHECKED,
	YES,
	NO
}

QueueItem :: struct {
	poly: Polyomino,
	is_valid: IsValid
}

Queue :: struct {
	list: [max_threads]QueueItem,
	count: u128,
	wait_group: sync.Wait_Group,
	testing_done: sync.Barrier, 
	counting_done: sync.Barrier
}

init_queue :: proc() -> Queue {
	res : Queue
	sync.barrier_init(&res.testing_done, max_threads)
	sync.barrier_init(&res.counting_done, max_threads + 1)
	sync.wait_group_add(&res.wait_group, max_threads)
	tmp := starting_polyomino(polyomino_size)
	defer destroy_polyomino(&tmp)
	for i in 0..<max_threads {
		res.list[i].poly = copy_polyomino(tmp)
		inc_polyomino(&tmp)
		inc_polyomino(&tmp)
	}
	return res
}

destroy_queue :: proc(queue: ^Queue) {
	for &i in queue.list do destroy_polyomino(&i.poly)
}

print_queue :: proc(queue: Queue) {
	for i in queue.list do fmt.printfln("%b - %v", i.poly.bin, i.is_valid)
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

	time.stopwatch_start(&stopwatch)

	threads: [max_threads]^thread.Thread
	mutex : sync.Mutex

	queue := init_queue()
	defer destroy_queue(&queue)


	for i in 0 ..< len(threads) {
		thread_id := i
		threads[i] = thread.create_and_start_with_poly_data3(
			&queue,
			&mutex,
			thread_id,
			process_poly
		)
	}

	reader := thread.create_and_start_with_poly_data2(&queue, &mutex, read_queue)

	thread.join_multiple(..threads[:])
	thread.join(reader)

	time.stopwatch_stop(&stopwatch)		
	fmt.println(time.clock_from_stopwatch(stopwatch))

	defer thread.destroy(reader)
	for t in threads do thread.destroy(t)
	 //print_queue(queue)


	//
	//fmt.printf("\033[s")
	//
	//for queue.index < queue.max {
	//	queue.checked += 1
	//	fmt.printf("\033[u")
	//	fmt.printfln("current: %v - checked: %v", queue.index, queue.checked)
	//	if valid_free_polyomino(queue.cur, size) {
	//		tmp_field, _ := polyomino_to_field(queue.cur)
	//		defer destroy_field(tmp_field)
	//		queue.index += 1
	//		fmt.printf("\033[0J")
	//		print_field(tmp_field)
	//	}
	//	inc_polyomino(&queue.cur)
	//	inc_polyomino(&queue.cur)
	//}
	//
	//init_window()
	//draw_window()
}

process_poly :: proc(queue: ^Queue, mutex: ^sync.Mutex, id: int) {
	for queue.count <= polyomino_index {
		// run tests here
		cur := queue.list[id]
		if valid_free_polyomino(cur.poly, polyomino_size) {
			queue.list[id].is_valid = .YES	
		} else {
			queue.list[id].is_valid = .NO
		}
		sync.wait_group_done(&queue.wait_group)
		sync.barrier_wait(&queue.counting_done)
		if queue.count >= polyomino_index do break
		for i in 0..<max_threads*2 {
			inc_polyomino(&queue.list[id].poly)
		}
	}
}

read_queue :: proc(queue: ^Queue, mutex: ^sync.Mutex) {
	outer: for queue.count <= polyomino_index {
		sync.wait_group_wait(&queue.wait_group)

		for queue_item in queue.list do if queue_item.is_valid == .YES {
			queue.count += 1
			if queue.count == polyomino_index {
				tmp_field, _ := polyomino_to_field(queue_item.poly)
				defer destroy_field(tmp_field)
				print_field(tmp_field)
				sync.barrier_wait(&queue.counting_done)
				break outer	
			}
		}
		sync.wait_group_add(&queue.wait_group, max_threads)
		sync.barrier_wait(&queue.counting_done)
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
