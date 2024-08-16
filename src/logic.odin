package main

import "core:math/rand" // for rand seed
import "core:time"
import SDL "vendor:sdl2"

generate_mine_field :: proc() {
	for i := 0; i < MINE_COUNT; i += 1 {
		tile_pos := SDL.Point {
			rand.int31() % GRID_WIDTH,
			rand.int31() % GRID_HEIGHT,
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
