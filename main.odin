package main

import "core:fmt"
import "core:math/rand" // for rand seed
import "core:strings"
import "core:time"
import "core:unicode/utf8"
import SDL "vendor:sdl2"
import SDL_TTF "vendor:sdl2/ttf"

RENDER_FLAGS :: SDL.RENDERER_ACCELERATED
WINDOW_FLAGS :: SDL.WINDOW_SHOWN | SDL.WINDOW_RESIZABLE
GRID_WIDTH: i32 : 16
GRID_HEIGHT: i32 : 16
TILE_SIDE_LENGTH :: 20
MINE_COUNT :: 40
FONT_SIZE :: 12

Tile :: struct {
	is_mine:      bool,
	nearby_mines: int,
	is_uncovered: bool,
	hovered:      bool,
	flagged:      bool,
}

Text :: struct {
	tex:  ^SDL.Texture,
	dest: SDL.Rect,
}

Game :: struct {
	renderer: ^SDL.Renderer,
	font:     ^SDL_TTF.Font,
	chars:    [10]Text,
	grid:     [GRID_WIDTH][GRID_HEIGHT]Tile,
}

game := Game{}

create_chars :: proc() {
	chars := "0123456789"

	i := 0
	for c in chars[:] {
		str := utf8.runes_to_string([]rune{c})
		defer delete(str)

		game.chars[i] = create_text(cstring(raw_data(str)))
		i += 1
	}

}

// create textures for the given str
// optional scale param allows us to easily size the texture generated
// relative to the current game.font_size
create_text :: proc(str: cstring, scale: i32 = 1) -> Text {
	// create surface
	surface := SDL_TTF.RenderText_Solid(
		game.font,
		str,
		SDL.Color{0, 0, 0, 255},
	)
	defer SDL.FreeSurface(surface)

	// create texture to render
	texture := SDL.CreateTextureFromSurface(game.renderer, surface)

	// destination SDL.Rect
	dest_rect := SDL.Rect{}
	SDL_TTF.SizeText(game.font, str, &dest_rect.w, &dest_rect.h)

	// scale the size of the text
	dest_rect.w *= scale
	dest_rect.h *= scale

	return Text{tex = texture, dest = dest_rect}
}

main :: proc() {
	// initialize SDL
	sdl_init_error := SDL.Init(SDL.INIT_VIDEO)
	assert(sdl_init_error == 0, SDL.GetErrorString())
	defer SDL.Quit()

	// Window
	window := SDL.CreateWindow(
		"SDL2 Example",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		GRID_WIDTH * TILE_SIDE_LENGTH * 3,
		GRID_HEIGHT * TILE_SIDE_LENGTH * 3,
		WINDOW_FLAGS,
	)
	assert(window != nil, SDL.GetErrorString())
	defer SDL.DestroyWindow(window)

	// Renderer
	// This is used throughout the program to render everything.
	// You only require ONE renderer for the entire program.
	game.renderer = SDL.CreateRenderer(window, -1, RENDER_FLAGS)
	assert(game.renderer != nil, SDL.GetErrorString())
	defer SDL.DestroyRenderer(game.renderer)

	SDL.RenderSetLogicalSize(
		game.renderer,
		GRID_WIDTH * TILE_SIDE_LENGTH,
		GRID_HEIGHT * TILE_SIDE_LENGTH,
	)

	ttf_init_error := SDL_TTF.Init()
	assert(ttf_init_error != -1, SDL.GetErrorString())
	defer SDL_TTF.Quit()

	game.font = SDL_TTF.OpenFont("mine-sweeper.ttf", FONT_SIZE)
	assert(game.font != nil, SDL.GetErrorString())
	create_chars()
	generate_mine_field()

	// We'll have to poll for queued events each game loop
	event: SDL.Event

	game_loop: for {
		if SDL.PollEvent(&event) {
			// Quit event is clicking on the X on the window
			if event.type == SDL.EventType.QUIT {
				break game_loop
			}

			if event.type == SDL.EventType.KEYDOWN {
				// a #partial switch allows us to ignore other scancode types;
				// otherwise, the compiler will refuse to compile the program, alerting us of the unhandled cases
				#partial switch event.key.keysym.scancode {
				case .ESCAPE:
					break game_loop
				}
			}

			x, y: i32
			if SDL.GetMouseState(&x, &y) == 1 {
				tile_pos := SDL.Point {
					event.button.x / TILE_SIDE_LENGTH,
					event.button.y / TILE_SIDE_LENGTH,
				}

				if !game.grid[tile_pos.x][tile_pos.y].flagged {
					for &column in game.grid {
						for &tile in column {
							tile.hovered = false
						}
					}
					game.grid[tile_pos.x][tile_pos.y].hovered = true
				}
			} else {
				for &column in game.grid {
					for &tile in column {
						tile.hovered = false
					}
				}
			}

			if event.type == SDL.EventType.MOUSEBUTTONUP &&
			   event.button.button == 1 {
				tile_pos := SDL.Point {
					event.button.x / TILE_SIDE_LENGTH,
					event.button.y / TILE_SIDE_LENGTH,
				}

				if !game.grid[tile_pos.x][tile_pos.y].flagged {
					if uncover_tile(tile_pos) {
						fmt.println("Game over!")
						break game_loop
					}

					if has_cleared_mine_field() {
						fmt.println("You win!")
						break game_loop
					}
				}
			}

			if event.type == SDL.EventType.MOUSEBUTTONDOWN &&
			   event.button.button == 3 {
				tile_pos := SDL.Point {
					event.button.x / TILE_SIDE_LENGTH,
					event.button.y / TILE_SIDE_LENGTH,
				}

				if game.grid[tile_pos.x][tile_pos.y].is_uncovered {
					game.grid[tile_pos.x][tile_pos.y].flagged =
					!game.grid[tile_pos.x][tile_pos.y].flagged
				}

			}
		}

		SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 100)
		SDL.RenderClear(game.renderer)

		draw_grid()

		// actual flipping / presentation of the copy
		// read comments here :: https://wiki.libsdl.org/SDL_RenderCopy
		SDL.RenderPresent(game.renderer)
	}
}

generate_mine_field :: proc() {
	my_rand: rand.Rand
	rand.init(&my_rand, cast(u64)time.time_to_unix_nano(time.now()))

	for i := 0; i < MINE_COUNT; i += 1 {
		tile_pos := SDL.Point {
			rand.int31(&my_rand) % GRID_WIDTH,
			rand.int31(&my_rand) % GRID_HEIGHT,
		}
		if game.grid[tile_pos.x][tile_pos.y].is_mine {
			i -= 1
		} else {
			game.grid[tile_pos.x][tile_pos.y].is_mine = true
		}
	}
}

get_neigbouring_positions :: proc(pos: SDL.Point) -> [dynamic]SDL.Point {
	positions: [dynamic]SDL.Point

	for offset_x: i32 = -1; offset_x < 2; offset_x += 1 {
		for offset_y: i32 = -1; offset_y < 2; offset_y += 1 {
			if offset_x == 0 && offset_y == 0 {
				continue
			}

			neighbour_pos := SDL.Point{pos.x + offset_x, pos.y + offset_y}

			if neighbour_pos.x < 0 || neighbour_pos.x >= GRID_WIDTH {
				continue
			}
			if neighbour_pos.y < 0 || neighbour_pos.y >= GRID_HEIGHT {
				continue
			}

			append(&positions, neighbour_pos)
		}
	}

	return positions
}

// Uncovers a tile and all its neighbouring tiles. Returns true if the uncovered tile is a mine
uncover_tile :: proc(tile_pos: SDL.Point) -> bool {
	if game.grid[tile_pos.x][tile_pos.y].is_uncovered {
		return false
	}
	if game.grid[tile_pos.x][tile_pos.y].is_mine {
		return true
	}

	game.grid[tile_pos.x][tile_pos.y].is_uncovered = true
	game.grid[tile_pos.x][tile_pos.y].nearby_mines = 0

	for neighbour_pos in get_neigbouring_positions(tile_pos) {
		if game.grid[neighbour_pos.x][neighbour_pos.y].is_mine {
			game.grid[tile_pos.x][tile_pos.y].nearby_mines += 1
		}
	}

	if game.grid[tile_pos.x][tile_pos.y].nearby_mines == 0 {
		for neighbour_pos in get_neigbouring_positions(tile_pos) {
			uncover_tile(neighbour_pos)
		}
	}

	return false
}

has_cleared_mine_field :: proc() -> bool {
	cleared := true

	for grid_x in 0 ..< GRID_WIDTH {
		for grid_y in 0 ..< GRID_HEIGHT {
			tile := game.grid[grid_x][grid_y]

			if !tile.is_uncovered && !tile.is_mine {
				cleared = false
			}
		}
	}

	return cleared
}

draw_grid :: proc() {
	for grid_x in 0 ..< GRID_WIDTH {
		for grid_y in 0 ..< GRID_HEIGHT {
			origin := SDL.Point {
				grid_x * TILE_SIDE_LENGTH,
				grid_y * TILE_SIDE_LENGTH,
			}
			tile := game.grid[grid_x][grid_y]

			SDL.SetRenderDrawColor(game.renderer, 111, 111, 111, 100)
			SDL.RenderDrawLine(
				game.renderer,
				origin.x,
				origin.y,
				origin.x + TILE_SIDE_LENGTH,
				origin.y,
			)
			SDL.RenderDrawLine(
				game.renderer,
				origin.x,
				origin.y,
				origin.x,
				origin.y + TILE_SIDE_LENGTH,
			)
			SDL.SetRenderDrawColor(game.renderer, 189, 189, 189, 100)
			SDL.RenderFillRect(
				game.renderer,
				&SDL.Rect {
					origin.x + 1,
					origin.y + 1,
					TILE_SIDE_LENGTH - 1,
					TILE_SIDE_LENGTH - 1,
				},
			)

			if tile.is_uncovered {
				SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 100)
				if tile.nearby_mines > 0 {
					// grab the texture for the single character
					char: Text = game.chars[tile.nearby_mines]

					// render this character after the previous one
					char.dest.x = origin.x + 4
					char.dest.y = origin.y + 2

					SDL.RenderCopy(game.renderer, char.tex, nil, &char.dest)
				}
			} else if !tile.hovered {
				SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 100)
				SDL.RenderFillRect(
					game.renderer,
					&SDL.Rect {
						origin.x + 1,
						origin.y + 1,
						TILE_SIDE_LENGTH - 1,
						3,
					},
				)
				SDL.RenderFillRect(
					game.renderer,
					&SDL.Rect {
						origin.x + 1,
						origin.y + 1,
						3,
						TILE_SIDE_LENGTH - 1,
					},
				)
				SDL.SetRenderDrawColor(game.renderer, 123, 123, 123, 100)
				SDL.RenderFillRect(
					game.renderer,
					&SDL.Rect {
						origin.x + 1,
						origin.y + 17,
						TILE_SIDE_LENGTH - 1,
						3,
					},
				)
				SDL.RenderFillRect(
					game.renderer,
					&SDL.Rect {
						origin.x + 17,
						origin.y + 1,
						3,
						TILE_SIDE_LENGTH - 1,
					},
				)
			}

			if tile.flagged {
				SDL.SetRenderDrawColor(game.renderer, 255, 0, 0, 100)
				SDL.RenderFillRect(
					game.renderer,
					&SDL.Rect {
						origin.x + 4,
						origin.y + 4,
						TILE_SIDE_LENGTH - 7,
						TILE_SIDE_LENGTH - 7,
					},
				)
			}
		}
	}
}