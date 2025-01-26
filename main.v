module main

import os
import time
import gg
import gx
import rand
import utils

struct App {
mut:
	gg             &gg.Context = unsafe { nil }
	ui             UI
	field          [][]u8
	moves          u32
	frame_counter  u64
	txtcfg         gx.TextCfg
	timer_started  bool
	start_time     u64
	elapsed_time   u64
	is_solved      bool
	win_animation  u8 = 15
	animated_tiles [][]u8
	is_debug_mode  bool
	state          GameState
	state_changed  bool
	theme_idx      u8
	frame_start    i64
	field_size     u8 = 4
}

enum GameState {
	play
	pause
	victory
	settings
	stats
}

struct UI {
mut:
	window_width    u16
	window_height   u16
	field_size      u16
	tile_padding    u16
	tile_size       u16
	font_size       u16
	label_font_size u16
	f_x             u16
	f_y             u16
	spawn_anim_len  u16 = 30
	theme           Theme
	dpi_scale       f32
	buttons         [][]u16
	fade            [][]u8
}

struct Theme {
mut:
	background   gx.Color
	font         gx.Color
	font_dark    gx.Color
	font_accent  gx.Color
	tile         gx.Color
	tile_correct gx.Color
	field        gx.Color
}

const window_title = 'VFifteen'
const default_window_width = 600
const default_window_height = 800

const themes = [
	Theme{
		background:   gx.rgb(10, 23, 16)
		font:         gx.rgb(253, 251, 252)
		font_dark:    gx.rgb(0, 66, 46)
		font_accent:  gx.rgb(7, 220, 162)
		tile:         gx.rgb(67, 113, 102)
		tile_correct: gx.rgb(0, 255, 165)
	},
	Theme{
		background:   gx.rgb(23, 10, 16)
		font:         gx.rgb(251, 253, 252)
		font_dark:    gx.rgb(66, 0, 46)
		font_accent:  gx.rgb(220, 7, 162)
		tile:         gx.rgb(113, 67, 102)
		tile_correct: gx.rgb(255, 0, 165)
	},
	Theme{
		background:   gx.rgb(10, 16, 23)
		font:         gx.rgb(253, 252, 251)
		font_dark:    gx.rgb(0, 46, 66)
		font_accent:  gx.rgb(7, 162, 220)
		tile:         gx.rgb(67, 102, 113)
		tile_correct: gx.rgb(0, 165, 255)
	},
]

fn (mut app App) add_button(x u16, y u16, width u16, height u16, id u16) {
	for n, i in app.ui.buttons {
		if i[4] == id {
			app.ui.buttons[n][0] = x
			app.ui.buttons[n][1] = y
			app.ui.buttons[n][2] = width
			app.ui.buttons[n][3] = height
			return
		}
	}
	app.ui.buttons << [x, y, width, height, id, 0]
}

fn (mut app App) remove_button(id u16) {
	for n, i in app.ui.buttons {
		if i[4] == id {
			app.ui.buttons = utils.delete(app.ui.buttons, n)
			return
		}
	}
}

fn (mut app App) check_buttons(mx u16, my u16) {
	for n, i in app.ui.buttons {
		if (mx > i[0] && mx < i[0] + i[2]) && (my > i[1] && my < i[1] + i[3]) {
			app.process_button(u16(n))
			app.ui.buttons[n][5] = 20
			return
		}
	}
}

fn (mut app App) draw_button(id u16, r u16, c gx.Color) {
	for n, i in app.ui.buttons {
		if i[4] == id {
			if i[5] > 10 {
				diffw := (i[2] - i[2] / 5) / 20 * (20 - i[5])
				diffh := (i[3] - i[3] / 5) / 20 * (20 - i[5])
				app.gg.draw_rounded_rect_filled(i[0] + diffw / 2, i[1] + diffh / 2, i[2] - diffw,
					i[3] - diffh, r, c)
				app.ui.buttons[n][5]--
				return
			} else if i[5] > 0 {
				diffw := (i[2] - i[2] / 5) / 20 * (i[5])
				diffh := (i[3] - i[3] / 5) / 20 * (i[5])
				app.gg.draw_rounded_rect_filled(i[0] + diffw / 2, i[1] + diffh / 2, i[2] - diffw,
					i[3] - diffh, r, c)
				app.ui.buttons[n][5]--
				return
			}
			app.gg.draw_rounded_rect_filled(i[0], i[1], i[2], i[3], r, c)
			return
		}
	}
}

fn (mut app App) draw() {
	app.gg.draw_rect_filled(0, 0, app.ui.window_width, app.ui.window_height, app.ui.theme.background)
	app.gg.set_text_cfg(gx.TextCfg{
		...app.txtcfg
		size: app.ui.label_font_size
	})
	mut tw, mut th := app.gg.text_size('Moves: 000')
	tw, th = int(f32(tw) * 1.2), int(f32(th) * 1.2)
	if app.timer_started || app.is_solved {
		th += app.ui.label_font_size + app.ui.label_font_size / 5
		tw = utils.max(u16(app.gg.text_width('Time: 00:00')), u16(tw))
	}
	app.gg.draw_rounded_rect_filled(app.ui.f_x, app.ui.label_font_size - app.gg.text_height('H') / 2 - 4,
		tw, th, 20, app.ui.theme.tile_correct)
	app.add_button(u16(app.ui.f_x), u16(app.ui.label_font_size - app.gg.text_height('H') / 2 - 4),
		u16(tw), u16(th), 1)
	app.add_button(u16(app.ui.f_x + tw + app.ui.tile_padding * 3), u16(
		app.ui.label_font_size - app.gg.text_height('H') / 2 - 4 + app.ui.tile_padding),
		u16(f32(app.ui.label_font_size) * 1.5), u16(f32(app.ui.label_font_size) * 1.5),
		2)
	app.add_button(u16(app.ui.f_x + tw + app.ui.tile_padding * 3 +
		u16(f32(app.ui.label_font_size) * 1.5) + app.ui.tile_padding), u16(
		app.ui.label_font_size - app.gg.text_height('H') / 2 - 4 + app.ui.tile_padding),
		u16(f32(app.ui.label_font_size) * 1.5), u16(f32(app.ui.label_font_size) * 1.5),
		3)

	app.draw_button(2, 30 * 4 / app.field_size, app.ui.theme.tile_correct)
	app.draw_button(3, 30 * 4 / app.field_size, app.ui.theme.tile)

	app.gg.draw_text(app.ui.f_x + tw / 2, app.ui.label_font_size, 'Moves: ${app.moves}',
		gx.TextCfg{
		size:           app.ui.label_font_size
		color:          app.ui.theme.font_dark
		vertical_align: .middle
		align:          .center
	})

	if app.timer_started || app.is_solved {
		// TODO: fix elapsed time calculation to encount time in pause

		if !app.is_solved && app.state != .pause {
			app.elapsed_time = u64(time.now().unix()) - app.start_time
		}
		app.gg.draw_text(app.ui.f_x + tw / 2, app.ui.label_font_size * 2, 'Time: ${app.elapsed_time / 60}:${utils.pad(app.elapsed_time % 60,
			2)}', gx.TextCfg{
			size:           app.ui.label_font_size
			color:          app.ui.theme.font_dark
			vertical_align: .middle
			align:          .center
		})
	}
	
	mut title_parts := [2]string{}
	title_font_size := int(f32(app.ui.label_font_size) * 1.2)
	match app.field_size {
	  3 {title_parts = ['Small ', '3x3']!}
		4 {title_parts = ['Classic', '4x4']!}
		5 {title_parts = ['Big ', '5x5']!}
		else {title_parts = ['Large ', '6x6']!}
	}
	app.gg.draw_text(app.ui.window_width / 4 * 3, app.ui.f_y / $if android {
		4
	} $else {
		2
	}, title_parts[0], gx.TextCfg{
		...app.txtcfg
		color: app.ui.theme.font
		size: title_font_size
	})
	tx := app.ui.window_width / 4 * 3 + app.gg.text_width(title_parts[0])
	app.gg.draw_text(tx, app.ui.f_y / $if android { 4 } $else { 2 }, title_parts[1], gx.TextCfg{
		...app.txtcfg
		color: app.ui.theme.font_accent
		size: title_font_size
	})
	
	app.add_button(u16(app.ui.window_width / 3 * 2), 0, u16(app.gg.text_width('${title_parts[0]}${title_parts[0]}')), app.ui.f_y, 4)

	// spawn animation
	tsize := app.ui.tile_size
	mut xc, mut yc := app.ui.f_x + app.ui.tile_padding / 2, app.ui.f_y + app.ui.tile_padding / 2
	if app.frame_counter < app.ui.spawn_anim_len {
		diff := u16(app.ui.spawn_anim_len - app.frame_counter)
		asize := u16(tsize / diff)
		padding := u16(app.ui.tile_padding + (tsize - asize))
		xc, yc = app.ui.f_x + padding / 2, app.ui.f_y + padding / 2
		for i in 0 .. app.field_size {
			for j in 0 .. app.field_size {
				if app.field[i][j] == 0 {
					xc += asize + padding
					continue
				}
				c := if i * 4 + j == app.field[i][j] + 1 {
					app.ui.theme.tile_correct
				} else {
					app.ui.theme.tile
				}
				app.gg.draw_rounded_rect_filled(xc, yc, asize, asize, 30 * 4 / app.field_size, c)
				xc += asize + padding
			}
			xc = app.ui.f_x + padding / 2
			yc += asize + padding
		}
		return
	}

	app.draw_animated_tiles()
	xc, yc = app.ui.f_x + app.ui.tile_padding / 2, app.ui.f_y + app.ui.tile_padding / 2
	for i in 0 .. app.field_size {
		for j in 0 .. app.field_size {
			if app.field[i][j] == 0 || app.is_animated(j, i) {
				xc += tsize + app.ui.tile_padding
				continue
			}
			mut c := if i * app.field_size + j == app.field[i][j] - 1 {
				app.ui.theme.tile_correct
			} else {
				app.ui.theme.tile
			}

			for n, f in app.ui.fade {
				if f[0] > 0 && f[0] == app.field[i][j] {
					if f[1] == 0 {
						app.ui.fade = utils.delete(app.ui.fade, n)
						break
					} else {
						c = utils.color_transition(app.ui.theme.tile_correct, app.ui.theme.tile,
							15, f[1])
						app.ui.fade[n][1]--
					}
				}
			}

			app.gg.draw_rounded_rect_filled(xc, yc, tsize, tsize, 30 * 4 / app.field_size, c)
			if app.state == .play {
  			app.gg.draw_text((xc + tsize / 2) + 2, (yc + tsize / 2) + 2, '${app.field[i][j]}',
  				gx.TextCfg{
  				...app.txtcfg
  				color: gx.rgba(10, 23, 16, 100)
  			})
  			app.gg.draw_text(xc + tsize / 2, yc + tsize / 2, '${app.field[i][j]}', app.txtcfg)
			}
			xc += tsize + app.ui.tile_padding
		}
		xc = app.ui.f_x + app.ui.tile_padding / 2
		yc += tsize + app.ui.tile_padding
	}
	if app.state == .pause {
		app.draw_pause_screen()
	}
}

fn (mut app App) draw_animated_tiles() {
	if app.animated_tiles.len == 0 {
		return
	}
	tsize := app.ui.tile_size
	c := app.ui.theme.tile
	for i in app.animated_tiles {
		if app.field[i[1]][i[0]] == 0 {
			continue
		}
		if i[3] == 0 {
			continue
		}
		match i[2] {
			1 {
				cx := app.ui.f_x + app.ui.tile_padding / 2 + (tsize +
					app.ui.tile_padding) * (i[0] - 1)
				rx := cx + (tsize / 15) * (15 - i[3])
				yc := app.ui.f_y + app.ui.tile_padding / 2 + (tsize + app.ui.tile_padding) * i[1]
				app.gg.draw_rounded_rect_filled(rx, yc, tsize, tsize, 30 * 4 / app.field_size, c)
				app.gg.draw_text(rx + tsize / 2, yc + tsize / 2, '${app.field[i[1]][i[0]]}',
					app.txtcfg)
			}
			2 {
				cx := app.ui.f_x + app.ui.tile_padding / 2 + (tsize + app.ui.tile_padding) * (i[0] +
					1)
				rx := cx - (tsize / 15) * (15 - i[3])
				yc := app.ui.f_y + app.ui.tile_padding / 2 + (tsize + app.ui.tile_padding) * i[1]
				app.gg.draw_rounded_rect_filled(rx, yc, tsize, tsize, 30 * 4 / app.field_size, c)
				app.gg.draw_text(rx + tsize / 2, yc + tsize / 2, '${app.field[i[1]][i[0]]}',
					app.txtcfg)
			}
			3 {
				cy := app.ui.f_y + app.ui.tile_padding / 2 + (tsize +
					app.ui.tile_padding) * (i[1] - 1)
				ry := cy + (tsize / 15) * (15 - i[3])
				xc := app.ui.f_x + app.ui.tile_padding / 2 + (tsize + app.ui.tile_padding) * i[0]
				app.gg.draw_rounded_rect_filled(xc, ry, tsize, tsize, 30 * 4 / app.field_size, c)
				app.gg.draw_text(xc + tsize / 2, ry + tsize / 2, '${app.field[i[1]][i[0]]}',
					app.txtcfg)
			}
			4 {
				cy := app.ui.f_y + app.ui.tile_padding / 2 + (tsize + app.ui.tile_padding) * (i[1] +
					1)
				ry := cy - (tsize / 15) * (15 - i[3])
				xc := app.ui.f_x + app.ui.tile_padding / 2 + (tsize + app.ui.tile_padding) * i[0]
				app.gg.draw_rounded_rect_filled(xc, ry, tsize, tsize, 30 * 4 / app.field_size, c)
				app.gg.draw_text(xc + tsize / 2, ry + tsize / 2, '${app.field[i[1]][i[0]]}',
					app.txtcfg)
			}
			else {}
		}
	}
}

fn (mut app App) draw_win_screen() {
	if app.win_animation > 0 {
		app.gg.draw_rect_filled(0, 0, app.ui.window_width, app.ui.window_height, gx.rgba(0,
			0, 0, 120 / app.win_animation))
		app.gg.draw_text(app.ui.window_width / 2, app.ui.window_height / 3, 'You won!',
			gx.TextCfg{
			...app.txtcfg
			align:          .center
			vertical_align: .middle
			color:          app.ui.theme.font_accent
			size: 69 / app.win_animation
		})
		app.gg.draw_text(app.ui.window_width / 2, app.ui.window_height / 3 +
			app.ui.label_font_size + app.ui.tile_padding * 2, 'Press N to start new game',
			gx.TextCfg{
			...app.txtcfg
			align:          .center
			vertical_align: .middle
			size: app.ui.label_font_size / app.win_animation
		})
		app.win_animation--
		return
	}
	app.gg.draw_rect_filled(0, 0, app.ui.window_width, app.ui.window_height, gx.rgba(0,
		0, 0, 120))
	app.gg.draw_text(app.ui.window_width / 2, app.ui.window_height / 3, 'You won!', gx.TextCfg{
		...app.txtcfg
		align:          .center
		vertical_align: .middle
		color:          app.ui.theme.font_accent
	})
	app.gg.draw_text(app.ui.window_width / 2, app.ui.window_height / 3 + app.ui.label_font_size +
		app.ui.tile_padding * 2, 'Press N to start new game', gx.TextCfg{
		...app.txtcfg
		align:          .center
		vertical_align: .middle
		size: app.ui.label_font_size
	})
	if app.moves == 0 {
		return
	}
	app.gg.draw_text(app.ui.window_width / 2, app.ui.window_height / 3 +
		app.ui.label_font_size * 2 + app.ui.tile_padding * 2, 'Your speed was ${utils.f32_to_str(f32(app.moves) / f32(app.elapsed_time))}',
		gx.TextCfg{
		...app.txtcfg
		align:          .center
		vertical_align: .middle
		size: app.ui.label_font_size
	})
}

fn (mut app App) draw_pause_screen() {
	app.gg.draw_rect_filled(0, 0, app.ui.window_width, app.ui.window_height, gx.rgba(0,
		0, 0, 120))
	app.gg.draw_text(app.ui.window_width / 2, app.ui.window_height / 2 - app.ui.tile_size,
		'Paused', gx.TextCfg{
		...app.txtcfg
	})
}

fn (mut app App) dbg_buttons() {
	if !app.is_debug_mode {
		return
	}
	for _, i in app.ui.buttons {
		app.gg.draw_rect_filled(i[0], i[1], i[2], i[3], gx.rgba(200, 20, 20, 130))
	}
}

const frame_time = (1000 / 65) * 1000000

fn frame(mut app App) {
	// attempt to make fps lock. makes animations not smooth now
	// current_time := time.now().unix_nano()
	// if current_time - app.frame_start < frame_time {return}
	app.gg.begin()
	app.draw()
	if app.is_solved {
		app.draw_win_screen()
	}
	app.dbg_buttons()
	app.frame_counter++
	if app.frame_counter % 180 == 0 {
		if gc_is_enabled() {
			gc_disable()
		}
		gc_enable()
		gc_collect()
		gc_disable()
		$if android {
			app.resize()
		}
	}
	app.gg.end()
	// app.frame_start = current_time
}

fn (app &App) print_field() {
  for i in 0 .. app.field_size {
    for j in 0 .. app.field_size {
			print('${utils.pad(app.field[i][j], 2)} ')
		}
		println('')
	}
	println('============')
}

fn (mut app App) scramble() {
  mut unused := []u8{len: int(app.field_size * app.field_size), cap: int(app.field_size * app.field_size)}
	for i in 0 .. app.field_size * app.field_size {
		unused[i] = u8(i)
	}
	for i in 0 .. app.field_size {
		for j in 0 .. app.field_size {
			mut idx := rand.int_in_range(0, unused.len) or { panic('Error: 1') }
			app.field[i][j] = unused[idx]
			unused = utils.delete(unused, int(idx))
		}
	}
}

fn (mut app App) new_game() {
  app.field = [][]u8{len: int(app.field_size), cap: int(app.field_size), init: []u8{len: int(app.field_size), cap: int(app.field_size)}}
	app.scramble()
	for !utils.is_solvable(app.field, app.field_size) || app.is_solved() {
		app.scramble()
	}
	app.moves = 0
	app.timer_started = false
	app.is_solved = false
	app.elapsed_time = 0
	app.frame_counter = 0
	app.win_animation = 15
}

fn (app &App) is_solved() bool {
	mut expected := u8(1)
	for i in 0 .. app.field_size * app.field_size - 1 {
		if app.field[i / app.field_size][i % app.field_size] != expected {
			return false
		}
		expected++
	}
	return true
}

//@[inline]
fn init(mut app App) {
	app.resize()
	app.new_game()
}

fn (mut app App) handle_tap(x i32, y i32) {
	if app.is_solved {
		app.new_game()
		return
	}
	if app.state == .pause {
		if app.state_changed {
			app.state_changed = false
			return
		}
		app.state = .play
		return
	}
	if x < app.ui.f_x || x > app.ui.f_x + app.ui.field_size {
		return
	}
	if y < app.ui.f_y || y > app.ui.f_y + app.ui.field_size {
		return
	}
	ny, nx := u8((x - app.ui.f_x) / (app.ui.field_size / app.field_size)), u8((y - app.ui.f_y) / (app.ui.field_size / app.field_size))
	if nx < 0 || nx > app.field_size - 1 || ny < 0 || ny > app.field_size - 1 {
		return
	}
	app.process_move(nx, ny)
}

fn (mut app App) is_animated(x u8, y u8) bool {
	for n, i in app.animated_tiles {
		if i[0] == x && i[1] == y {
			if i[3] == 0 {
				app.animated_tiles = utils.delete(app.animated_tiles, n)
				return false
			} else if i[0] == x && i[1] == y {
				app.animated_tiles[n][3]--
				return true
			}
		}
	}
	return false
}

fn (mut app App) process_move(x u8, y u8) {
	nx, ny := y, x
	if app.field[y][x] == 0 {
		return
	}
	mut line := app.field[ny]
	mut idx := utils.find(line[..], 0)
	if idx != -1 {
		if idx > nx {
			for i := idx - 1; i >= nx; i-- {
				line[i + 1] = line[i]
				app.animated_tiles << [u8(i + 1), u8(ny), 1, 15]
				if i + 1 + ny * app.field_size == line[i + 1] - 1 {
					app.ui.fade << [line[i + 1], 15]
				}
			}
		} else if nx > idx {
			for i in idx + 1 .. nx + 1 {
				line[i - 1] = line[i]
				app.animated_tiles << [u8(i - 1), u8(ny), 2, 15]
				if i - 1 + ny * app.field_size == line[i - 1] - 1 {
					app.ui.fade << [line[i - 1], 15]
				}
			}
		}
		line[nx] = 0
		app.field[x] = line
		app.moves++
		if !app.timer_started {
			app.timer_started = true
			app.start_time = u64(time.now().unix())
		}
		app.is_solved = app.is_solved()
		return
	}
	mut nf := utils.transpose(app.field, app.field_size)
	line = nf[y]
	idx = utils.find(line[..], 0)
	if idx != -1 {
		if idx > x {
			for i := idx - 1; i >= x; i-- {
				line[i + 1] = line[i]
				app.animated_tiles << [u8(nx), u8(i + 1), 3, 15]
				if (i + 1) * app.field_size + nx == line[i + 1] - 1 {
					app.ui.fade << [line[i + 1], 15]
				}
			}
		} else if x > idx {
			for i in idx + 1 .. x + 1 {
				line[i - 1] = line[i]
				app.animated_tiles << [u8(nx), u8(i - 1), 4, 15]
				if (i - 1) * app.field_size + nx == line[i - 1] - 1 {
					app.ui.fade << [line[i - 1], 15]
				}
			}
		}
		line[x] = 0
		nf[y] = line
		app.field = utils.transpose(nf, app.field_size)
		app.moves++
		if !app.timer_started {
			app.timer_started = true
			app.start_time = u64(time.now().unix())
		}
		app.is_solved = app.is_solved()
	}
}

fn on_event(e &gg.Event, mut app App) {
	match e.typ {
		.mouse_down {
			app.check_buttons(u16(e.mouse_x), u16(e.mouse_y))
		}
		.mouse_up {
			app.handle_tap(i32(e.mouse_x), i32(e.mouse_y))
		}
		.touches_ended {
			if e.num_touches > 0 {
				t := e.touches[0]
				app.handle_tap(i32(t.pos_x / app.ui.dpi_scale), i32(t.pos_y / app.ui.dpi_scale))
			}
		}
		.touches_began {
			if e.num_touches > 0 {
				t := e.touches[0]
				app.check_buttons(u16(t.pos_x / app.ui.dpi_scale), u16(t.pos_y / app.ui.dpi_scale))
			}
		}
		.key_down {
			app.on_key_down(e.key_code)
		}
		.resized, .restored, .resumed {
			app.resize()
		}
		else {}
	}
}

@[inline]
fn (mut app App) next_theme() {
	app.theme_idx++
	app.theme_idx %= u8(themes.len)
	app.ui.theme = themes[app.theme_idx]
}

fn (mut app App) process_button(n u16) {
	match app.ui.buttons[n][4] {
		1 {
			if !app.is_solved {
				app.new_game()
			}
		}
		2 {
			if app.state == .play {
				app.state = .pause
			} else {
				app.state = .play
			}
			app.state_changed = true
		}
		3 {
			app.next_theme()
		}
		4 {
		  app.field_size++
			if app.field_size > 6 {app.field_size = 3}
			app.resize()
			app.new_game()
		}
		else {}
	}
}

fn (mut app App) resize() {
	mut s := app.gg.scale
	if s == 0.0 {
		s = 1.0
	}
	app.ui.dpi_scale = s
	window_size := app.gg.window_size()
	w := u16(window_size.width)
	h := u16(window_size.height)
	m := utils.min(w, h)
	app.ui.window_width = w
	app.ui.window_height = h
	app.ui.field_size = u16(m - f32(m) * 1 / 9)
	app.ui.f_x = (w - app.ui.field_size) / 2
	app.ui.tile_padding = app.ui.field_size / 80
	app.ui.tile_size = app.ui.field_size / app.field_size - app.ui.tile_padding
	app.ui.font_size = u16(m * 13 / 100) * 4 / app.field_size
	app.ui.label_font_size = u16(m * 13 / 200)
	app.txtcfg = gx.TextCfg{
		...app.txtcfg
		size: app.ui.font_size
	}
	app.gg.set_text_cfg(gx.TextCfg{
		...app.txtcfg
		size: app.ui.label_font_size
	})
	app.ui.f_y = u16(app.ui.label_font_size - app.gg.text_height('H') / 2 - 4 +
		app.gg.text_height('Moves: 000') + (app.ui.label_font_size + app.ui.label_font_size / 5)) +
		app.ui.tile_padding * 2
	$if android {
		app.ui.f_y *= 2
	}
}

fn (mut app App) on_key_down(key gg.KeyCode) {
	match key {
		.escape {
			app.gg.quit()
		}
		.n, .r {
			app.new_game()
		}
		.w {
			if app.is_debug_mode {
				app.is_solved = true
			}
		}
		.p {
			if app.state == .play {
				app.state = .pause
			} else if app.state == .pause {
				app.state = .play
			}
		}
		.t {
			app.next_theme()
		}
		else {}
	}
}

fn main() {
	mut app := &App{}
	app.is_debug_mode = os.args.contains('-d')
	if app.is_debug_mode {
		println('Debug mode activated')
	}
	app.ui.theme = themes[0]
	app.txtcfg = gx.TextCfg{
		color:          app.ui.theme.font
		align:          .center
		vertical_align: .middle
	}
	app.gg = gg.new_context(
		bg_color:      app.ui.theme.background
		width:         600
		height:        800
		window_title:  window_title
		frame_fn:      frame
		init_fn:       init
		event_fn:      on_event
		user_data:     app
		sample_count:  4
		swap_interval: 1
	)
	app.gg.set_text_cfg(gx.TextCfg{
		...app.txtcfg
		size: app.ui.label_font_size
	})
	app.gg.run()
}
