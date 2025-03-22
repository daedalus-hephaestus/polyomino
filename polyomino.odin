package polyomino

import "core:math/bits"

NewPolyomino :: struct {
	bin: [dynamic]u128,
	bin_str: cstring
}

make_polyomino :: proc() -> NewPolyomino {
	res : NewPolyomino
	append(&res.bin, 0b1)
	return res
}

destroy_polyomino :: proc(poly: ^NewPolyomino) {
	delete(poly.bin)
	delete(poly.bin_str)
}

get_polyomino_len :: proc(poly: NewPolyomino) -> int {
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
