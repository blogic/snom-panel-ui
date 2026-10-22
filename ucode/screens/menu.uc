'use strict';

import { keylist_new } from 'lvgl.component.keylist';
import { screen_new, title_new, BODY_Y, BODY_H } from '../lib/ui.uc';
import * as lv from 'lv';

/**
 * menu_new - the settings menu
 * @ctx: nav, card_opa
 *
 * Return: a keynav entry.
 */
export function menu_new(ctx) {
	let obj = screen_new();
	let group = lv.group();

	title_new(obj, 'Menu');

	let list = keylist_new(obj, group,
			       { y: BODY_Y + 2, opacity: ctx.card_opa });

	list.set([
		{ label: 'System', chevron: true,
		  on_ok: function() { ctx.nav.system(); } },
		{ label: 'Brightness', chevron: true,
		  on_ok: function() { ctx.nav.brightness(); } }
	]);

	return { obj, group };
};
