package polyomino

import "core:math/bits"
import "core:fmt"
import "core:os"
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

Variations :: [8]Polyomino

make_polyomino :: proc() -> Polyomino {
	res : Polyomino
	append(&res.bin, 0b1)
	return res
}

destroy_polyomino :: proc(poly: ^Polyomino) {
	delete(poly.bin)
	delete(poly.bin_str)
}

destroy_variations :: proc(variations: ^Variations) {
	for &v in variations do destroy_polyomino(&v)
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

inc_polyomino :: proc(poly: ^Polyomino) {
	i := 1
	move_ones := 1
	for {
		cur_carry := (i) / 128
		next_carry := (i + 1) / 128
		if len(poly.bin) == next_carry do append(&poly.bin, 0)

		cur := poly.bin[cur_carry] >> uint(i - 128 * cur_carry) & 1
		next := poly.bin[next_carry] >> uint((i - 128 * next_carry) + 1) & 1

		if cur == 1 {
			if next == 0 {
				poly.bin[next_carry] |= u128(1) << uint((i - 128 * next_carry) + 1)
				break
			}
			move_ones += 1
		}

		i += 1
	}
	max_index := i / 128 + 1
	for cur in 0..<max_index {
		if cur != max_index - 1 {
			poly.bin[cur] = 0
		} else {
			shift := uint(i - 128 * cur) + 1
			poly.bin[cur] = poly.bin[cur] >> shift << shift
		}

		if move_ones >= 128 {
			poly.bin[cur] = max(u128)
			move_ones -= 128
		} else {
			poly.bin[cur] |= max(u128) >> uint(128 - move_ones)
		}
	}
}

valid_polyomino :: proc(poly: Polyomino, size: int) -> (Field, PolyominoError) {
	return polyomino_to_field(poly)
}

valid_free_polyomino :: proc(poly: Polyomino, size: int) -> (Field, bool) {
	tmp_field, valid := polyomino_to_field(poly)
	// defer destroy_field(tmp_field)
	if valid != .NONE do return tmp_field, false

	vars := field_variations(tmp_field)
	defer destroy_variations(&vars)
	smallest, free := get_smallest(vars)
	defer destroy_polyomino(&smallest)

	return tmp_field, free
}

copy_polyomino :: proc(poly: Polyomino) -> Polyomino {
	res : Polyomino
	for i in poly.bin do append(&res.bin, i)
	tmp_str := string(poly.bin_str)
	res.bin_str = str.clone_to_cstring(tmp_str)
	return res
}

get_polyomino_size :: proc(poly: Polyomino) -> int {
	cells := 0
	for i in poly.bin do cells += int(bits.count_ones(i))
	return cells
}

get_smallest :: proc(vars: Variations) -> (Polyomino, bool) {
	smallest := 0
	is_free := true
	for i in 1..<8 {
		p0 := vars[smallest]
		p1 := vars[i]
		res := compare_polyomino(p0, p1)
		if res > 0 {
			smallest = i
			is_free = false
		}
	}
	return copy_polyomino(vars[smallest]), is_free
}

compare_polyomino :: proc(poly0: Polyomino, poly1: Polyomino) -> int {
	l0 := len(poly0.bin)
	l1 := len(poly1.bin)

	if l0 < l1 && poly1.bin[l1 - 1] > 0 {
		return 0
	} else if l0 > l1 && poly0.bin[l0 - 1] > 0 {
		return 1
	}

	smaller_len := l0 >= l1 ? l1 : l0
	s0 := poly0.bin[:smaller_len]
	s1 := poly1.bin[:smaller_len]

	for i := smaller_len - 1; i > -1; i -= 1 {
		if s0[i] == s1[i] {
	continue
		} else if s0[i] < s1[i] {
			return 0 
		} else if s0[i] > s1[i] {
			return 1 
		}
	}
	return -1
}

starting_polyomino :: proc(size: int) -> Polyomino {
	res : Polyomino
	append(&res.bin, 0)

	carry := 0
	write_i :uint = 0
	for i in 0..<size {
		if write_i > 127 {
			write_i = 0
			carry += 1
			append(&res.bin, 1)
		}
		res.bin[carry] |= u128(1) << write_i
		write_i += 1
	}
	return res
}


