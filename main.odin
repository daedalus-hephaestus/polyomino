#+feature dynamic-literals
package polyomino

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

// A001168 - Number of fixed polyominoes with n cells

// The polyomino, maximum size of 64
Polyomino :: struct {
	string: u64
}

Cell :: [2]i32
Field :: [64][64]bool

PolyominoIndex :: struct {
	
}

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
}

generate_random :: proc (size: i32) -> Polyomino {
	result : Polyomino

	result.string = 0x1
	cur_size := 1
	cur_height := 0

	free := [dynamic]Cell{
		{2, 0},
		{0, 0},
		{1, 1}
	}
	defer delete(free)
	field : Field

	return result
}

calc_free :: proc(height: i32, field: Field) -> (Field, [dynamic]Cell) {
	return field, {}
	
	// checks if the polyomino is currently sitting at the edge of the field
	edge := false
	for row, y in field {
		if row[0] {
			edge = true
			break
		}
	}
	if 
	
}

