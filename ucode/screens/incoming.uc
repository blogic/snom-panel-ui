'use strict';

import * as lv from 'lv';
import { FONT_REG_20, FONT_REG_26 } from 'lvgl.assets';
import { C_TXT, C_OK, C_ALERT, W } from 'lvgl.theme';
import { screen_new, softbar_new, BODY_Y, KEY_S1, KEY_S4 } from '../lib/ui.uc';
import { party_name, party_number } from '../lib/party.uc';

/**
 * incoming_new - the alerting incoming call screen
 * @ctx: voice
 * @call: the call object, of name and number
 *
 * Return: a keynav entry.
 */
export function incoming_new(ctx, call) {
	let obj = screen_new();
	let number = party_number(call);

	let banner = lv.label(obj);
	banner.text('Incoming call');
	banner.style({ text_color: C_TXT, text_font: FONT_REG_20 });
	banner.set({ x: 0, y: 12, w: W });
	banner.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let who = lv.label(obj);
	who.text(party_name(call));
	who.style({ text_color: C_TXT, text_font: FONT_REG_26 });
	who.set({ x: 8, y: BODY_Y + 40, w: W - 16 });
	who.style({ text_align: lv.TEXT_ALIGN_CENTER });
	who.long_mode(lv.LABEL_LONG_DOTS);

	if (number != '') {
		let num = lv.label(obj);
		num.text(number);
		num.style({ text_color: C_TXT, text_font: FONT_REG_26 });
		num.set({ x: 8, y: BODY_Y + 84, w: W - 16 });
		num.style({ text_align: lv.TEXT_ALIGN_CENTER });
		num.long_mode(lv.LABEL_LONG_DOTS);
	}

	softbar_new(obj, [ { text: 'Answer', colour: C_OK }, null, null,
			   { text: 'Decline', colour: C_ALERT } ], ctx.card_opa);

	return {
		obj,
		group: null,
		key: function(code) {
			if (code == KEY_S1) {
				ctx.voice.answer(call.call);

				return true;
			}

			if (code == KEY_S4) {
				ctx.voice.reject(call.call);

				return true;
			}

			return false;
		}
	};
};
