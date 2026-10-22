'use strict';

import * as lv from 'lv';
import { FONT_REG_20, FONT_REG_15 } from 'lvgl.assets';
import { C_TXT, C_TXT_DIM, C_SURFACE, C_IDLE, C_OK, C_WARN, C_ALERT, W,
	 GROUP_X, GROUP_W, SEP_H } from 'lvgl.theme';
import { threshold_colour } from 'lvgl.threshold';
import { screen_new, title_new, BODY_Y } from '../lib/ui.uc';

function net_info() {
	let out = { ip: '-', mac: '-' };

	return out;
}

function row_new(parent, y, caption) {
	let cap = lv.label(parent);
	cap.text(caption);
	cap.style({ text_color: C_TXT_DIM, text_font: FONT_REG_20 });
	cap.set({ x: GROUP_X + 11, y });

	let val = lv.label(parent);
	val.style({ text_color: C_TXT, text_font: FONT_REG_20 });
	val.set({ x: GROUP_X, y, w: GROUP_W - 11 });
	val.style({ text_align: lv.TEXT_ALIGN_RIGHT });

	return val;
}

/**
 * system_new - model, firmware, address and the live cpu and memory bars
 * @ctx: state (sampler), subscribe, release, board
 *
 * Return: a keynav entry.
 */
export function system_new(ctx) {
	let obj = screen_new();
	let state = ctx.state;

	title_new(obj, 'System');

	let card = lv.obj(obj);
	card.set({ x: GROUP_X, y: BODY_Y + 2, w: GROUP_W, h: 104 });
	card.style({ bg_color: C_SURFACE, bg_opa: ctx.card_opa ?? lv.OPA_COVER,
		     radius: 9, border_width: 0, pad_all: 0 });
	card.scrollable(false);
	card.clickable(false);

	let fw = row_new(card, 12, 'Firmware');
	fw.text(ctx.board.firmware ?? 'OpenWrt');
	let ip = row_new(card, 44, 'IP address');
	ip.text(ctx.board.ip ?? '-');
	let mac = row_new(card, 76, 'MAC');
	mac.text(ctx.board.mac ?? '-');

	function meter(x, caption) {
		let m = {};
		let cap = lv.label(obj);
		cap.text(caption);
		cap.style({ text_color: C_TXT_DIM, text_font: FONT_REG_15 });
		cap.set({ x, y: BODY_Y + 112 });

		m.val = lv.label(obj);
		m.val.style({ text_color: C_TXT_DIM, text_font: FONT_REG_15 });
		m.val.set({ x, y: BODY_Y + 112, w: 140 });
		m.val.style({ text_align: lv.TEXT_ALIGN_RIGHT });

		let track = lv.obj(obj);
		track.set({ x, y: BODY_Y + 130, w: 140, h: 5 });
		track.style({ bg_color: C_IDLE, bg_opa: lv.OPA_COVER, radius: 3,
			      border_width: 0, pad_all: 0 });
		track.scrollable(false);
		track.clickable(false);

		m.fill = lv.obj(track);
		m.fill.set({ x: 0, y: 0, w: 0, h: 5 });
		m.fill.style({ radius: 3, border_width: 0, pad_all: 0,
			       bg_color: C_OK, bg_opa: lv.OPA_COVER });
		m.fill.clickable(false);
		m.fill.scrollable(false);

		m.set = function(pct) {
			m.val.text(sprintf('%d%%', pct));
			m.fill.set({ w: int(140 * pct / 100) });
			m.fill.style({ bg_color: threshold_colour(pct) });
		};

		return m;
	}

	let cpu = meter(GROUP_X, 'CPU');
	let mem = meter(GROUP_X + 150, 'Memory');

	function refresh() {
		cpu.set(state.cpu ?? 0);
		mem.set(state.mem ?? 0);
	}

	return {
		obj,
		group: null,
		needs: [ 'cpu', 'sysinfo' ],
		update: refresh,
		enter: function() {
			ctx.subscribe([ 'cpu', 'sysinfo' ]);
			refresh();
		},
		leave: function() {
			ctx.release([ 'cpu', 'sysinfo' ]);
		}
	};
};
