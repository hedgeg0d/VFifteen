module utils

import gx

pub fn delete[T](arr []T, index int) []T {
	if index < 0 || index >= arr.len {
		return arr
	}

	mut new_arr := unsafe { arr[..index] }
	new_arr << arr[index + 1..]
	return new_arr
}

pub fn count_inversions(puzzle [][]u8, size u8) int {
	mut inversions := 0
	mut flat_puzzle := []int{}

	for i in 0 .. size {
		for j in 0 .. size {
			if puzzle[i][j] != 0 {
				flat_puzzle << puzzle[i][j]
			}
		}
	}
	for i in 0 .. flat_puzzle.len {
		for j in i + 1 .. flat_puzzle.len {
			if flat_puzzle[i] > flat_puzzle[j] {
				inversions++
			}
		}
	}
	return inversions
}

pub fn is_solvable(puzzle [][]u8, size u8) bool {
	inversions := count_inversions(puzzle, size)
	mut empty_tile_row := 0
	for i in 0 .. size {
		for j in 0 .. size {
			if puzzle[i][j] == 0 {
				empty_tile_row = i + 1
			}
		}
	}
	if (inversions % 2 == 0 && empty_tile_row % 2 == 0)
		|| (inversions % 2 != 0 && empty_tile_row % 2 != 0) {
		return true
	}
	return false
}

pub fn pad(n u64, len u8) string {
	mut num_str := n.str()
	for num_str.len < int(len) {
		num_str = '0' + num_str
	}
	return num_str
}

@[inline]
pub fn min(a u16, b u16) u16 {
	if a < b {
		return a
	}
	return b
}

@[inline]
pub fn max(a u16, b u16) u16 {
	if a > b {
		return a
	}
	return b
}

pub fn find(arr []u8, n u8) i16 {
	for i in 0 .. arr.len {
		if arr[i] == n {
			return i
		}
	}
	return -1
}

pub fn transpose(matrix [][]u8, size u8) [][]u8 {
	mut nm := matrix.clone()
	for i in 0 .. size {
		for j in 0 .. size {
			nm[i][j] = matrix[j][i]
		}
	}
	return nm
}

pub fn f32_to_str(num f32) string {
	rounded := int(num * 100 + 0.5)
	integer_part := rounded / 100
	fractional_part := rounded % 100
	return '${integer_part}.${fractional_part:02d}'
}

pub fn color_transition(start_color gx.Color, end_color gx.Color, total_steps int, current_step int) gx.Color {
	if current_step <= 0 {
		return start_color
	}
	if current_step >= total_steps {
		return end_color
	}

	r1, g1, b1, a1 := start_color.r, start_color.g, start_color.b, start_color.a
	r2, g2, b2, a2 := end_color.r, end_color.g, end_color.b, end_color.a

	t := f32(current_step) / f32(total_steps)

	r := u8(f32(r1) + (f32(r2) - f32(r1)) * t)
	g := u8(f32(g1) + (f32(g2) - f32(g1)) * t)
	b := u8(f32(b1) + (f32(b2) - f32(b1)) * t)
	a := u8(f32(a1) + (f32(a2) - f32(a1)) * t)

	return gx.Color{r, g, b, a}
}
