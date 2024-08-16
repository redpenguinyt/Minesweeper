package main

import "core:fmt"
import "core:strings"
import "core:unicode/utf8"
import SDL "vendor:sdl2"
import SDL_TTF "vendor:sdl2/ttf"

Text :: struct {
	tex:  ^SDL.Texture,
	dest: SDL.Rect,
}

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
	surface := SDL_TTF.RenderText_Solid(game.font, str, SDL.Color{0, 0, 0, 255})
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
