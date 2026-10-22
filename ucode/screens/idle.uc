'use strict';

import * as lv from 'lv';
import { FONT_THIN_112, FONT_REG_20, FONT_REG_15 } from 'lvgl.assets';
import { C_TXT, C_TXT_DIM, C_OK, C_WARN, C_ALERT, W } from 'lvgl.theme';
import { screen_new, softbar_new, BODY_Y, KEY_S1, KEY_S4 } from '../lib/ui.uc';

/**
 * idle_new - the idle screen: clock, account, missed calls and status badges
 * @ctx: state (sampler), voice, nav, subscribe, release
 *
 * Return: a keynav root entry.
 */
export function idle_new(ctx) {
	let obj = screen_new();
	let state = ctx.state;
	let group = lv.group();

	let dot = lv.obj(obj);
	dot.set({ x: 8, y: 10, w: 9, h: 9 });
	dot.style({ radius: 5, border_width: 0, pad_all: 0,
		    bg_color: C_OK, bg_opa: lv.OPA_COVER });
	dot.clickable(false);
	dot.scrollable(false);

	let reg = lv.label(obj);
	reg.text('Registered');
	reg.style({ text_color: C_TXT, text_font: FONT_REG_20 });
	reg.set({ x: 24, y: 2 });

	/* Status badges, right of the account line, shown only when active. */
	let badges = lv.label(obj);
	badges.style({ text_color: C_WARN, text_font: FONT_REG_15 });
	badges.set({ x: 0, y: 22, w: W - 12 });
	badges.style({ text_align: lv.TEXT_ALIGN_RIGHT });

	/* A focusable sink so a digit pressed on idle starts a call. */
	let sink = lv.obj(obj);
	sink.set({ x: 0, y: BODY_Y, w: 1, h: 1 });
	sink.style({ bg_opa: lv.OPA_TRANSP, border_width: 0, pad_all: 0 });
	group.add(sink);

	sink.on(lv.EVENT_KEY, function(code, key) {
		if ((key >= 48 && key <= 57) || key == 42 || key == 35)
			ctx.nav.dial(chr(key));
	});

	let clock = lv.label(obj);
	clock.style({ text_color: C_TXT, text_font: FONT_THIN_112 });
	clock.set({ x: 0, y: BODY_Y + 24, w: W });
	clock.style({ text_align: lv.TEXT_ALIGN_CENTER });
	clock.text('00:00');

	let date = lv.label(obj);
	date.style({ text_color: C_TXT_DIM, text_font: FONT_REG_20 });
	date.set({ x: 0, y: BODY_Y + 116, w: W });
	date.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let missed = lv.label(obj);
	missed.style({ text_color: C_ALERT, text_font: FONT_REG_20 });
	missed.set({ x: 0, y: BODY_Y + 150, w: W });
	missed.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let acct = lv.label(obj);
	acct.style({ text_color: C_TXT_DIM, text_font: FONT_REG_15 });
	acct.set({ x: 0, y: 2, w: W - 12 });
	acct.style({ text_align: lv.TEXT_ALIGN_RIGHT });

	softbar_new(obj, [ 'Dial', null, null, 'Menu' ], ctx.card_opa);

	function refresh() {
		clock.text(state.clock_24 ?? '00:00');
		date.text(state.date ?? '');

		let n = ctx.voice.missed();
		missed.text(n > 0 ? sprintf('%d missed %s', n,
					    n == 1 ? 'call' : 'calls') : '');

		let a = ctx.voice.account();
		/* The account's own number is not worth screen space. Show the
		   label only when it is a real name, not a copy of the number. */
		acct.text(a.label && a.label != a.number ? a.label : '');
		reg.text(a.registered ? 'Registered' : 'Not registered');
		dot.style({ bg_color: a.registered ? C_OK : C_ALERT });

		let marks = [];

		if (ctx.voice.device().dnd)
			push(marks, 'DND');
		if (ctx.voice.mwi())
			push(marks, 'Voicemail');

		badges.text(join('  ·  ', marks));
	}

	return {
		obj,
		group,
		root: true,
		needs: [ 'clock' ],
		update: refresh,
		device_update: refresh,
		enter: function() {
			ctx.subscribe([ 'clock' ]);
			/* The cdr notification keeps the count current; recount here too
			   for start up and after a resubscribe, when no event was seen. */
			ctx.voice.missed_refresh();
			refresh();
		},
		leave: function() {
			ctx.release([ 'clock' ]);
		},
		key: function(code) {
			if (code == KEY_S1) {
				ctx.nav.dial();

				return true;
			}

			if (code == KEY_S4) {
				ctx.nav.menu();

				return true;
			}

			return false;
		}
	};
};
