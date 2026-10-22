'use strict';

import * as lv from 'lv';
import { FONT_REG_15, IMAGE_SUN } from 'lvgl.assets';
import { C_TXT_DIM, C_FILL, C_IDLE, W, GROUP_X, GROUP_W } from 'lvgl.theme';
import { icon_new } from 'lvgl.widget';
import { screen_new, title_new, softbar_new, BODY_Y,
	 KEY_S4 } from '../lib/ui.uc';

const STEP	= 10;
const FILL_MIN	= 46;

/**
 * brightness_new - the backlight bar, moved by the left and right keys
 * @ctx: brightness (get, set, save), nav
 *
 * Return: a keynav entry.
 */
export function brightness_new(ctx) {
	let obj = screen_new();
	let group = lv.group();

	title_new(obj, 'Brightness');

	let track = lv.obj(obj);
	track.set({ x: GROUP_X, y: BODY_Y + 50, w: GROUP_W, h: 48 });
	track.style({ bg_color: C_IDLE, bg_opa: lv.OPA_COVER, radius: 24,
		      border_width: 0, pad_all: 0 });
	track.scrollable(false);
	group.add(track);

	let fill = lv.obj(track);
	fill.set({ x: 0, y: 0, h: 48 });
	fill.style({ bg_color: C_FILL, bg_opa: lv.OPA_COVER, radius: 24,
		     border_width: 0, pad_all: 0 });
	fill.scrollable(false);
	fill.clickable(false);

	let sun = icon_new(fill, IMAGE_SUN, 0x000000);
	sun.set({ align: lv.ALIGN_LEFT_MID, align_x: 12 });

	let hint = lv.label(obj);
	hint.text('Left and right to adjust');
	hint.style({ text_color: C_TXT_DIM, text_font: FONT_REG_15 });
	hint.set({ x: 0, y: BODY_Y + 118, w: W });
	hint.style({ text_align: lv.TEXT_ALIGN_CENTER });

	softbar_new(obj, [ null, null, null, 'Back' ], ctx.card_opa);

	function redraw() {
		let pct = ctx.brightness.get();
		let w = int(GROUP_W * pct / 100);

		fill.set({ w: w < FILL_MIN ? FILL_MIN : w });
	}

	function nudge(by) {
		let pct = ctx.brightness.get() + by;

		if (pct < STEP)
			pct = STEP;
		if (pct > 100)
			pct = 100;

		ctx.brightness.set(pct);
		ctx.brightness.save();
		redraw();
	}

	track.on(lv.EVENT_KEY, function(code, key) {
		if (key == lv.KEY_LEFT)
			nudge(-STEP);
		else if (key == lv.KEY_RIGHT)
			nudge(STEP);
	});

	redraw();

	return {
		obj,
		group,
		key: function(code) {
			if (code == KEY_S4) {
				ctx.nav.back();

				return true;
			}

			return false;
		}
	};
};
