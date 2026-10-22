'use strict';

import * as lv from 'lv';
import { FONT_SEMI_21, FONT_REG_20 } from 'lvgl.assets';
import { C_TXT, C_ALERT, W } from 'lvgl.theme';
import { screen_new, BODY_Y } from '../lib/ui.uc';

/**
 * ended_new - the screen shown while the handset is off hook after the last call
 * @ctx: unused, kept for the common screen signature
 *
 * uvoice holds the device in the "ended" state, silent, after the last call
 * ends with the handset still up, and refuses dial, digits and the audio keys
 * until the handset goes down. The panel shows this screen and swallows every
 * key, so the only way out is to hang up, which uvoice reports as a device state
 * change back to idle.
 *
 * Return: a keynav entry with no focus group.
 */
export function ended_new(ctx) {
	let obj = screen_new();

	let banner = lv.label(obj);
	banner.text('Call ended');
	banner.style({ text_color: C_ALERT, text_font: FONT_SEMI_21 });
	banner.set({ x: 0, y: BODY_Y + 50, w: W });
	banner.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let hint = lv.label(obj);
	hint.text('Please hang up');
	hint.style({ text_color: C_TXT, text_font: FONT_REG_20 });
	hint.set({ x: 0, y: BODY_Y + 90, w: W });
	hint.style({ text_align: lv.TEXT_ALIGN_CENTER });

	return {
		obj,
		group: null,
		key: function(code) {
			return true;
		}
	};
};
