'use strict';

import * as lv from 'lv';
import { FONT_SEMI_21, FONT_REG_20 } from 'lvgl.assets';
import { C_SCREEN, C_SURFACE, C_TXT, C_TXT_DIM, W, H, HEAD_TOP,
	 HEAD_X } from 'lvgl.theme';

/*
 * The furniture every phone screen shares: the fixed title and the four soft
 * key labels along the bottom, under the hardware keys S1 to S4.
 */

export const SOFTBAR_H	= 32;
export const BODY_Y	= 32;
export const BODY_H	= H - SOFTBAR_H - BODY_Y;

/*
 * The four soft keys under the display, left to right. On the D735 matrix they
 * are F9 to F12; confirmed by logging the keys on the hardware.
 */
export const KEY_S1	= 67;
export const KEY_S2	= 68;
export const KEY_S3	= 87;
export const KEY_S4	= 88;

let background;

/**
 * background_set - the image drawn behind every screen from now on
 * @src: an image index from lv.image_load(), or null for a plain black screen
 */
export function background_set(src) {
	background = src;
};

/**
 * screen_new - a blank phone screen
 *
 * Return: the lv screen, black and not scrollable.
 */
export function screen_new() {
	let obj = lv.screen_create();

	obj.style({ bg_color: C_SCREEN, bg_opa: lv.OPA_COVER, border_width: 0,
		    pad_all: 0 });
	obj.scrollbar(lv.SCROLLBAR_OFF);
	obj.scrollable(false);

	/* The gradient sits behind the content: z order is creation order, so it
	   is built before anything the caller adds. */
	if (background != null) {
		let image = lv.image(obj);

		image.src(background);
		image.set({ x: 0, y: 0 });
		image.clickable(false);
	}

	return obj;
};

/**
 * title_new - the page title, top left
 * @parent: the screen
 * @text: the title
 *
 * Return: the label.
 */
export function title_new(parent, text) {
	let label = lv.label(parent);

	label.text(text);
	label.style({ text_color: C_TXT, text_font: FONT_SEMI_21 });
	label.set({ x: HEAD_X, y: HEAD_TOP });

	return label;
};

/**
 * softbar_new - the four soft key labels along the bottom
 * @parent: the screen
 * @labels: four entries, each a string, or null for an empty key, or an object
 *	    of text and colour
 * @opacity: the bar fill, from ctx.card_opa, or null for solid
 *
 * Return: an object carrying set(index, label), so a screen can relabel a key.
 */
export function softbar_new(parent, labels, opacity) {
	let bar = lv.obj(parent);

	bar.set({ x: 0, y: H - SOFTBAR_H, w: W, h: SOFTBAR_H });
	bar.style({ bg_color: C_SURFACE, bg_opa: opacity ?? lv.OPA_COVER,
		    border_width: 0, pad_all: 0, radius: 0 });
	bar.scrollable(false);
	bar.clickable(false);

	let cells = [];
	let width = int(W / 4);

	for (let i = 0; i < 4; i++) {
		if (i > 0) {
			let rule = lv.obj(bar);

			rule.set({ x: i * width, y: 0, w: 1, h: SOFTBAR_H });
			rule.style({ bg_color: C_SCREEN, bg_opa: lv.OPA_COVER,
				     border_width: 0, pad_all: 0, radius: 0 });
			rule.clickable(false);
			rule.scrollable(false);
		}

		let label = lv.label(bar);

		label.style({ text_font: FONT_REG_20, text_color: C_TXT });
		label.set({ x: i * width, y: 4, w: width });
		label.style({ text_align: lv.TEXT_ALIGN_CENTER });

		push(cells, label);
	}

	let obj = { obj: bar };

	obj.set = function(i, label) {
		let text = type(label) == 'object' ? label.text : label;

		cells[i].text(text ?? '');
		cells[i].style({ text_color:
				 type(label) == 'object' ? label.colour : C_TXT });
	};

	for (let i = 0; i < 4; i++)
		obj.set(i, labels?.[i]);

	return obj;
};
