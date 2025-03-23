package polyomino

import "core:math/bits"
import str "core:strings"

Polyomino :: struct {
	bin: [dynamic]u128,
	bin_str: cstring
}

PolyominoError :: enum {
	NONE,
	ONE_OVERFLOW,
	ZERO_OVERFLOW,
	SIZE_MISMATCH,
}

make_polyomino :: proc() -> Polyomino {
	res : Polyomino
	append(&res.bin, 0b1)
	return res
}

destroy_polyomino :: proc(poly: ^Polyomino) {
	delete(poly.bin)
	delete(poly.bin_str)
}

get_polyomino_len :: proc(poly: Polyomino) -> int {
	cells := 0
	for seg, i in poly.bin {
		if i == len(poly.bin) - 1 {
			cells += int(bits.leading_zeros(poly.bin[i]))
		} else {
			cells += 128
		}
	}
	return 0
}

polyomino_to_field :: proc(poly: Polyomino) -> (Field, PolyominoError) {
	res := make_field()
	carry := 0
	skip := 0
	free : [dynamic]Cell
	defer delete(free)
	get_free(&res, &free)

	last_seg := poly.bin[len(poly.bin) - 1]
	last_len := 128 - bits.count_leading_zeros(last_seg)

	for seg, i in poly.bin {
		is_last := i == len(poly.bin) - 1
		cur_len := 128 - bits.count_leading_zeros(seg)

		for j :uint = 0; j < 128; j += 1 {
			// skip over first bit, as that gets initialized with the field
			if i == 0 && j == 0 do continue
			// if this is the last segment, don't loop over leading zeros
			if is_last && j == uint(last_len) do break
			// if there are more than two segments, but the last is only 0, don't loop over
			// leading zeroes in the second to last segment
			if last_seg == 0 && j == uint(cur_len) && i + 2  == len(poly.bin) do break

			if bit_at(j, seg) == 1 {
				if skip > len(free) - 1 do return res, .ONE_OVERFLOW
				add_cell_from_free(&res, free[:], skip)
				skip = 0
				get_free(&res, &free)
			} else if bit_at(j, seg) == 0 {
				if skip > len(free) - 1 do return res, .ZERO_OVERFLOW
				skip += 1
			}
		}
	}

	return res, .NONE
}

polyomino_to_string :: proc(poly: Polyomino) -> cstring {
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

string_to_polyomino :: proc(str: cstring) -> Polyomino {
	res := make_polyomino() 
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

valid_polyomino :: proc(poly: Polyomino, size: int) -> PolyominoError {
	cells := 0
	for i in poly.bin do cells += int(bits.count_ones(i))
	if cells != size do return .SIZE_MISMATCH 

	_, valid := polyomino_to_field(poly)
	return valid 
}

get_polyomino_size :: proc(poly: Polyomino) -> int {
	cells := 0
	for i in poly.bin do cells += int(bits.count_ones(i))
	return cells
}
