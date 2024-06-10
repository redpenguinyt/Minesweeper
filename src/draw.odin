package main

import SDL "vendor:sdl2"

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

			// Draw X on mine tiles when game is over
			// oh my god this code is horrific
			if game.state != .Playing && tile.is_mine {
				SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 100)

				draw_top_left_to_bottom_right := proc(
					origin: SDL.Point,
					x, y: i32,
				) {
					SDL.RenderDrawLine(
						game.renderer,
						origin.x + 3 + x,
						origin.y + 3 + y,
						origin.x + TILE_SIDE_LENGTH - 3 - y,
						origin.y + TILE_SIDE_LENGTH - 3 - x,
					)
				}
				draw_top_left_to_bottom_right(origin, 0, 0)
				draw_top_left_to_bottom_right(origin, 1, 0)
				draw_top_left_to_bottom_right(origin, 0, 1)

				draw_top_right_to_bottom_left := proc(
					origin: SDL.Point,
					x, y: i32,
				) {
					SDL.RenderDrawLine(
						game.renderer,
						origin.x + TILE_SIDE_LENGTH - 3 - x,
						origin.y + 3 + y,
						origin.x + 3 + y,
						origin.y + TILE_SIDE_LENGTH - 3 - x,
					)
				}

				draw_top_right_to_bottom_left(origin, 0, 0)
				draw_top_right_to_bottom_left(origin, 1, 0)
				draw_top_right_to_bottom_left(origin, 0, 1)
			}
		}
	}
}

draw_game_over_messages :: proc() {
	if game.state == .Playing {
		return
	}

	SDL.SetRenderDrawColor(game.renderer, 255, 255, 255, 100)
	SDL.RenderFillRect(game.renderer, &SDL.Rect{60, 70, 200, 36})
	SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 100)

	#partial switch game.state {
	case .Died:
		died_text: Text = create_text("You died", 2)
		died_text.dest.x = 65
		died_text.dest.y = 70
		SDL.RenderCopy(game.renderer, died_text.tex, nil, &died_text.dest)
	case .Won:
		died_text: Text = create_text("You won!", 2)
		died_text.dest.x = 74
		died_text.dest.y = 90
		SDL.RenderCopy(game.renderer, died_text.tex, nil, &died_text.dest)
	}
}
