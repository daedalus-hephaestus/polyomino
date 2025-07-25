package polyomino

import "core:math/bits"
import "core:math/rand"
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
			cells += 128 - int(bits.leading_zeros(seg))
		} else {
			cells += 128
		}
	}
	return cells 
}

polyomino_to_field :: proc(poly: Polyomino) -> (Field, PolyominoError) {
	res := make_field()
	carry := 0 // the current u128 that is being read
	skip := 0 // how many zeroes since the last one
	free : [dynamic]Cell
	defer delete(free)
	get_free(&res, &free)

	// gets the last u128
	last_seg := poly.bin[len(poly.bin) - 1]
	// the length of the last u128
	last_len := 128 - bits.count_leading_zeros(last_seg)

	for seg, i in poly.bin {
		// if the current u128 is the last one
		is_last := i == len(poly.bin) - 1
		// gets the length of the current u128
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
				// if the skip is greater than free spaces
				if skip > len(free) - 1 do return res, .ONE_OVERFLOW
				add_cell_from_free(&res, free[:], skip)
				skip = 0
				get_free(&res, &free)
			} else if bit_at(j, seg) == 0 {
				// if the skip is greater than free spaces
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
	// Get the first 1 that is followed by a 0, and shift it to the left
	// e.g. 101101 -> 110101 (first one is ignored)
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
	// Shifts all of the ones to the right which are before the previously moved 1
	// e.g. 110101 -> 110011
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

valid_fixed_polyomino :: proc(poly: Polyomino, size: int) -> (Field, PolyominoError) {
	field, err := polyomino_to_field(poly)
	return field, err
}

valid_free_polyomino :: proc(poly: Polyomino, size: int) -> (Field, bool) {
	tmp_field, valid := polyomino_to_field(poly)
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

starting_polyomino :: proc(size: int, length: int=-1) -> Polyomino {
	res : Polyomino
	append(&res.bin, 0)

	carry := 0
	write_i :uint = 0

	if length <= size {
		for i in 0..<size {
			if write_i > 127 {
				write_i = 0
				carry += 1
				append(&res.bin, 1)
			}
			res.bin[carry] |= u128(1) << write_i
			write_i += 1
		}		
	} else {
		for i in 0..<size - 1 {
			if write_i > 127 {
				write_i = 0
				carry += 1
				append(&res.bin, 1)
			}
			res.bin[carry] |= u128(1) << write_i
			write_i += 1
		}
		last_carry := (length - 1) / 128
		last_write := length - (last_carry * 128) - 1

		for len(res.bin) - 1 < last_carry do append(&res.bin, 0)
		res.bin[last_carry] |= u128(1) << uint(last_write)
	}
	return res
}

random_polyomino_bin :: proc(size: int, type: Type) -> Polyomino {
	res : Polyomino

	str_length := (size - 1) * 3 
 	if type == .FREE && size >= 9 do str_length -= 4

	seg_count := (str_length - 1) / 128 + 1
	last_len := str_length % 128

	for i in 0..<seg_count do append(&res.bin, 0)

	count := size
	res.bin[0] = 1
	count -= 1

	for count > 0 {
		i := rand.int_max(str_length) + 1
		cur_seg := (i - 1) / 128 
		cur_i := i % 128 - 1
		if bit_at(uint(cur_i), res.bin[cur_seg]) == 1 {
			continue
		} else {
			res.bin[cur_seg] |= u128(1) << uint(cur_i)
			count -= 1
		}
	}
	return res
}

random_polyomino :: proc(size: int, type: Type) -> Polyomino {
	res : Polyomino

	for {
		tmp := random_polyomino_bin(size, type)
		field, val := valid_free_polyomino(tmp, size)	
		if val {
			res = copy_polyomino(tmp)
			print_field(field)
			destroy_field(field)
			destroy_polyomino(&tmp)
			break
		}
		destroy_field(field)
		destroy_polyomino(&tmp)
	}	

	return res
}
