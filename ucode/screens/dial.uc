'use strict';

import * as lv from 'lv';
import { FONT_REG_26, FONT_REG_15, FONT_SEMI_21 } from 'lvgl.assets';
import { C_TXT, C_TXT_DIM, C_SURFACE, C_OK, C_ACTION, W, GROUP_X,
	 GROUP_W } from 'lvgl.theme';
import { screen_new, softbar_new, title_new, BODY_Y, KEY_S1,
	 KEY_S4 } from '../lib/ui.uc';

/**
 * dial_new - the dial entry screen
 * @ctx: voice, nav
 *
 * A hidden focusable widget collects the digit keys. The far end is dialled by
 * the Call soft key, by OK, or by lifting the handset, which the panel routes.
 *
 * Return: a keynav entry.
 */
export function dial_new(ctx, seed) {
	let obj = screen_new();
	let group = lv.group();
	let digits = seed ?? '';

	title_new(obj, 'Dial');

	let field = lv.obj(obj);
	field.set({ x: GROUP_X, y: BODY_Y + 40, w: GROUP_W, h: 56 });
	field.style({ bg_color: C_SURFACE, bg_opa: ctx.card_opa ?? lv.OPA_COVER,
		      radius: 9, border_width: 0, pad_all: 0 });
	field.scrollable(false);

	let shown = lv.label(field);
	shown.style({ text_color: C_TXT, text_font: FONT_REG_26 });
	shown.set({ align: lv.ALIGN_CENTER });

	let hint = lv.label(obj);
	hint.text('Enter a number, then OK or lift the handset');
	hint.style({ text_color: C_TXT_DIM, text_font: FONT_REG_15 });
	hint.set({ x: 0, y: BODY_Y + 110, w: W });
	hint.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let bar = softbar_new(obj, [ 'Delete', null, null,
				     { text: 'Call', colour: C_OK } ], ctx.card_opa);

	/* A focusable, invisible widget so the digit keys reach this screen. */
	let sink = lv.obj(obj);
	sink.set({ x: 0, y: BODY_Y, w: 1, h: 1 });
	sink.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0 });
	group.add(sink);

	function redraw() {
		shown.text(digits != '' ? digits : ' ');
	}

	function del() {
		/* Delete on an empty field backs out of the dialer. */
		if (digits == '') {
			ctx.nav.back();

			return;
		}

		digits = substr(digits, 0, length(digits) - 1);

		redraw();
	}

	function dial() {
		if (digits == '')
			return;

		ctx.voice.dial(digits);
	}

	sink.on(lv.EVENT_KEY, function(code, key) {
		if ((key >= 48 && key <= 57) || key == 42 || key == 35) {
			if (length(digits) < 24)
				digits += chr(key);

			redraw();
		}
	});

	/* OK (ENTER) dials. */
	sink.on(lv.EVENT_CLICKED, dial);

	redraw();

	return {
		obj,
		group,
		dial,
		/* The digits typed so far, so the panel can hand them to uvoice if
		   the user lifts the handset instead of pressing Call. */
		number: function() { return digits; },
		key: function(code) {
			if (code == KEY_S1) {
				del();

				return true;
			}

			if (code == KEY_S4) {
				dial();

				return true;
			}

			return false;
		}
	};
};
