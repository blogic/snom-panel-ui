'use strict';

import * as lv from 'lv';
import { FONT_SEMI_21, FONT_REG_20 } from 'lvgl.assets';
import { C_TXT, C_TXT_DIM, C_WARN, W, RULE_PAD } from 'lvgl.theme';
import { screen_new, BODY_Y } from '../lib/ui.uc';

/**
 * firmware_new - the screen shown while the voice firmware is not installed
 * @ctx: unused, kept for the common screen signature
 *
 * The D735 ships without the CSS voice firmware. On the first boot the
 * dvf99-css-firmware package downloads and installs it over the WAN port, then
 * reboots the phone. While /lib/firmware/css-loader is absent uvoiced does not
 * start, so the voice object never appears and the panel shows this screen and
 * swallows every key. wan_set switches between the install in progress and a
 * request for the WAN cable, because the install needs the WAN port.
 *
 * Return: a keynav entry with no focus group, carrying wan_set(up).
 */
export function firmware_new(ctx) {
	let obj = screen_new();

	let banner = lv.label(obj);
	banner.style({ text_font: FONT_SEMI_21 });
	banner.set({ x: 0, y: BODY_Y + 50, w: W });
	banner.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let hint = lv.label(obj);
	hint.style({ text_color: C_TXT_DIM, text_font: FONT_REG_20 });
	hint.set({ x: RULE_PAD, y: BODY_Y + 90, w: W - 2 * RULE_PAD });
	hint.style({ text_align: lv.TEXT_ALIGN_CENTER });

	function wan_set(up) {
		banner.text(up ? 'Installing voice firmware' : 'No network');
		banner.style({ text_color: up ? C_TXT : C_WARN });
		hint.text(up ? 'The phone restarts when it is ready.'
			     : 'Connect the WAN port to install the voice firmware.');
	}

	wan_set(true);

	return {
		obj,
		group: null,
		wan_set,
		key: function(code) {
			return true;
		}
	};
};
