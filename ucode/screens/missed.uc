'use strict';

import * as lv from 'lv';
import { keylist_new } from 'lvgl.component.keylist';
import { FONT_REG_20, FONT_SEMI_21 } from 'lvgl.assets';
import { C_TXT, C_OK, W, SEP_H } from 'lvgl.theme';
import { screen_new, softbar_new, title_new, BODY_Y, KEY_S1, KEY_S2,
	 KEY_S4 } from '../lib/ui.uc';
import { party_name } from '../lib/party.uc';

const LIST_Y = BODY_Y + 14;
const ROW_H = 52;
const ROWS_SHOWN = 3;

function when_text(start) {
	if (!start)
		return '';

	let t = localtime(start);
	let now = localtime(time());

	if (t.year == now.year && t.mon == now.mon && t.mday == now.mday)
		return sprintf('%02d:%02d', t.hour, t.min);

	return sprintf('%02d.%02d. %02d:%02d', t.mday, t.mon, t.hour, t.min);
}

/**
 * missed_new - the list of missed calls, to call one back
 * @ctx: voice, nav, card_opa
 *
 * Up and down move through the calls, three at a time, and OK selects one.
 * Lifting the handset, the speaker or headset key, or the Call soft key then
 * calls it back; the handset and the path keys reach the panel as the pre-dial
 * handoff, which reads number(). Opening the list marks every missed call as
 * seen, and Clear drops them all from the list.
 *
 * Return: a keynav entry.
 */
export function missed_new(ctx) {
	let obj = screen_new();
	let group = lv.group();
	let calls;
	let focused = 0;
	let selected;

	let title = title_new(obj, 'Missed calls');

	let none = lv.label(obj);

	none.text('No missed calls');
	none.style({ text_color: C_TXT, text_font: FONT_REG_20 });
	none.set({ x: 0, y: BODY_Y + 60, w: W });
	none.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let list = keylist_new(obj, group, {
		y: LIST_Y, h: ROWS_SHOWN * ROW_H + (ROWS_SHOWN - 1) * SEP_H,
		opacity: ctx.card_opa, row_h: ROW_H, font: FONT_SEMI_21,
		sub_font: FONT_REG_20, sub_colour: C_TXT
	});

	let bar = softbar_new(obj, [ 'Back', 'Clear', null, null ], ctx.card_opa);

	function select(idx, label) {
		selected = idx;
		title.text(label);
		title.style({ text_color: C_OK });
	}

	function render() {
		let items = [];

		calls = ctx.voice.missed_list();
		focused = 0;
		selected = null;
		title.text('Missed calls');
		title.style({ text_color: C_TXT });

		for (let i = 0; i < length(calls); i++) {
			let c = calls[i];
			let name = party_name({ name: c.name, number: c.number,
						direction: 'in' });

			push(items, {
				label: sprintf('%d. %s', i + 1, name),
				secondary: trim(sprintf('%s  %s', c.number,
							when_text(c.start))),
				on_ok: ((idx, label) => function() {
					select(idx, label);
				})(i, name)
			});
		}

		list.set(items);

		for (let i = 0; i < length(list.rows); i++)
			list.rows[i].on(lv.EVENT_FOCUSED, ((idx) => function() {
				focused = idx;
			})(i));

		none.hidden(length(calls) > 0);
		list.obj.hidden(!length(calls));
		bar.set(1, length(calls) ? 'Clear' : '');
		bar.set(3, length(calls) ? { text: 'Call', colour: C_OK } : '');
	}

	function number() {
		return calls[selected ?? focused]?.number ?? '';
	}

	render();

	return {
		obj,
		group,
		number,
		enter: function() {
			ctx.voice.missed_clear();
		},
		key: function(code) {
			if (code == KEY_S1) {
				ctx.nav.back();

				return true;
			}

			if (code == KEY_S2 && length(calls)) {
				ctx.voice.missed_wipe();
				render();

				return true;
			}

			if (code == KEY_S4 && number() != '') {
				ctx.voice.dial(number());

				return true;
			}

			return false;
		}
	};
};
