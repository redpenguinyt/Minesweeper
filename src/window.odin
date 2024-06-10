package main

import "core:time"
import SDL "vendor:sdl2"
import SDL_TTF "vendor:sdl2/ttf"

RENDER_FLAGS :: SDL.RENDERER_ACCELERATED
WINDOW_FLAGS :: SDL.WINDOW_SHOWN | SDL.WINDOW_RESIZABLE
FPS :: 60

@(deferred_out = free_sdl)
init_sdl :: proc() -> ^SDL.Window {

	sdl_init_error := SDL.Init(SDL.INIT_VIDEO)
	assert(sdl_init_error == 0, SDL.GetErrorString())

	window := SDL.CreateWindow(
		"Minesweeper",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		GRID_WIDTH * TILE_SIDE_LENGTH * 3,
		GRID_HEIGHT * TILE_SIDE_LENGTH * 3,
		WINDOW_FLAGS,
	)
	assert(window != nil, SDL.GetErrorString())

	game.renderer = SDL.CreateRenderer(window, -1, RENDER_FLAGS)
	assert(game.renderer != nil, SDL.GetErrorString())
	SDL.RenderSetLogicalSize(
		game.renderer,
		GRID_WIDTH * TILE_SIDE_LENGTH,
		GRID_HEIGHT * TILE_SIDE_LENGTH,
	)

	ttf_init_error := SDL_TTF.Init()
	assert(ttf_init_error != -1, SDL.GetErrorString())

	return window
}

free_sdl :: proc(window: ^SDL.Window) {
	SDL.Quit()
	SDL.DestroyWindow(window)
	SDL.DestroyRenderer(game.renderer)
	SDL_TTF.Quit()
}

sleep_frame :: proc() {
	@(static)
	frame_started: time.Time

	FPS_DURATION :: time.Second / FPS
	elapsed := time.since(frame_started)

	if elapsed < FPS_DURATION {
		time.sleep(FPS_DURATION - elapsed)
	}

	frame_started = time.now()
}
