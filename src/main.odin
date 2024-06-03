package main

import "core:fmt"
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

GameState :: enum {
	Playing,
	Died,
	Won,
}

Game :: struct {
	window:   ^SDL.Window,
	renderer: ^SDL.Renderer,
	font:     ^SDL_TTF.Font,
	chars:    [10]Text,
	grid:     [GRID_WIDTH][GRID_HEIGHT]Tile,
	state:    GameState,
}

game := Game{}

init_sdl :: proc() {
	sdl_init_error := SDL.Init(SDL.INIT_VIDEO)
	assert(sdl_init_error == 0, SDL.GetErrorString())

	game.window = SDL.CreateWindow(
		"SDL2 Example",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		GRID_WIDTH * TILE_SIDE_LENGTH * 3,
		GRID_HEIGHT * TILE_SIDE_LENGTH * 3,
		WINDOW_FLAGS,
	)
	assert(game.window != nil, SDL.GetErrorString())

	game.renderer = SDL.CreateRenderer(game.window, -1, RENDER_FLAGS)
	assert(game.renderer != nil, SDL.GetErrorString())
	SDL.RenderSetLogicalSize(
		game.renderer,
		GRID_WIDTH * TILE_SIDE_LENGTH,
		GRID_HEIGHT * TILE_SIDE_LENGTH,
	)

	ttf_init_error := SDL_TTF.Init()
	assert(ttf_init_error != -1, SDL.GetErrorString())
}

free_sdl :: proc() {
	defer SDL.Quit()
	defer SDL.DestroyWindow(game.window)
	defer SDL.DestroyRenderer(game.renderer)
	defer SDL_TTF.Quit()
}

main :: proc() {
	init_sdl()
	defer free_sdl()

	// Set up game
	game.font = SDL_TTF.OpenFont("minesweeper-font/minesweeper.ttf", FONT_SIZE)
	assert(game.font != nil, SDL.GetErrorString())
	create_chars()
	generate_mine_field()

	// We'll have to poll for queued events each game loop
	event: SDL.Event

	game_loop: for {
		if SDL.PollEvent(&event) {
			if event.type == SDL.EventType.QUIT || event.key.keysym.scancode == .ESCAPE do break game_loop

			if game.state == .Playing {
				handle_game_events(&event)
			} else {
				// R to restart
				if event.key.keysym.scancode == .R {
					game.state = .Playing
					empty_tileset: [GRID_WIDTH][GRID_HEIGHT]Tile
					game.grid = empty_tileset
					generate_mine_field()
				}
			}
		}

		SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 100)
		SDL.RenderClear(game.renderer)

		draw_grid()

		draw_game_over_messages()

		SDL.RenderPresent(game.renderer)
	}
}

handle_game_events :: proc(event: ^SDL.Event) {
	// Hover effect
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

	// Uncovering a tile
	if event.type == SDL.EventType.MOUSEBUTTONUP && event.button.button == 1 {
		tile_pos := SDL.Point {
			event.button.x / TILE_SIDE_LENGTH,
			event.button.y / TILE_SIDE_LENGTH,
		}

		if !game.grid[tile_pos.x][tile_pos.y].flagged {
			if uncover_tile(tile_pos) {
				game.state = .Died
			}

			if has_cleared_mine_field() {
				game.state = .Won
			}
		}
	}

	// Flagging a tile
	if event.type == SDL.EventType.MOUSEBUTTONDOWN &&
	   event.button.button == 3 {
		tile_pos := SDL.Point {
			event.button.x / TILE_SIDE_LENGTH,
			event.button.y / TILE_SIDE_LENGTH,
		}

		if !game.grid[tile_pos.x][tile_pos.y].is_uncovered {
			game.grid[tile_pos.x][tile_pos.y].flagged =
			!game.grid[tile_pos.x][tile_pos.y].flagged
		}
	}
}