'use strict';

import * as lv from 'lv';
import * as uloop from 'uloop';
import { FONT_SEMI_21, FONT_REG_20, FONT_REG_15, FONT_LIGHT_45 } from 'lvgl.assets';
import { C_TXT, C_TXT_DIM, C_OK, C_ALERT, C_WARN, W } from 'lvgl.theme';
import { screen_new, softbar_new, BODY_Y, KEY_S1, KEY_S2, KEY_S4 } from '../lib/ui.uc';
import { party_name, party_number } from '../lib/party.uc';

const STATE_BANNER = {
	dialling: 'Dialling',
	calling: 'Calling',
	ringback: 'Calling',
	connected: 'Connected',
	held: 'On hold',
	held_remote: 'On hold',
	conference: 'Conference'
};

const REASON_BANNER = {
	busy: 'Busy',
	unavailable: 'Not available',
	rejected: 'Rejected',
	failed: 'Call failed',
	remote_bye: 'Call ended',
	local: 'Call ended',
	cancelled: 'Cancelled'
};

function elapsed(since) {
	let s = since ? time() - since : 0;

	if (s < 0)
		s = 0;

	if (s >= 3600)
		return sprintf('%d:%02d:%02d', int(s / 3600), int(s % 3600 / 60),
			       s % 60);

	return sprintf('%02d:%02d', int(s / 60), s % 60);
}

/**
 * active_new - the outgoing or connected call screen
 * @ctx: voice
 * @call: the call object, of name, number, state, connected and (second) waiting
 *
 * One screen for every non alerting call state. The state is a banner, the
 * duration runs from the first connect and keeps running through hold, and a
 * second call that rings during this one is offered on the soft keys.
 * call_update() keeps it in step so the screen is not rebuilt on every event.
 *
 * Return: a keynav entry.
 */
export function active_new(ctx, call) {
	let obj = screen_new();
	let timer;
	let connected;
	let running;
	let act = {};

	let banner = lv.label(obj);
	banner.style({ text_color: C_TXT, text_font: FONT_REG_20 });
	banner.set({ x: 0, y: 12, w: W });
	banner.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let who = lv.label(obj);
	who.style({ text_color: C_TXT, text_font: FONT_SEMI_21 });
	who.set({ x: 0, y: BODY_Y + 10, w: W });
	who.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let num = lv.label(obj);
	num.style({ text_color: C_TXT_DIM, text_font: FONT_REG_15 });
	num.set({ x: 0, y: BODY_Y + 36, w: W });
	num.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let clock = lv.label(obj);
	clock.style({ text_color: C_OK, text_font: FONT_LIGHT_45 });
	clock.set({ x: 0, y: BODY_Y + 64, w: W });
	clock.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let waiting = lv.label(obj);
	waiting.style({ text_color: C_WARN, text_font: FONT_REG_20 });
	waiting.set({ x: 0, y: BODY_Y + 120, w: W });
	waiting.style({ text_align: lv.TEXT_ALIGN_CENTER });

	let bar = softbar_new(obj, [ null, null, null, null ], ctx.card_opa);

	function render(c) {
		let w = ctx.voice.waiting();
		let muted = ctx.voice.device().mute;

		if (c.state == 'clearing')
			banner.text(REASON_BANNER[c.reason] ?? 'Call ended');
		else
			banner.text(STATE_BANNER[c.state] ?? '');

		who.text(party_name(c));
		num.text(party_number(c));

		connected = c.connected > 0 ? c.connected : null;
		/* The duration runs only while the call is up; on clearing it stays
		   frozen at the final value rather than counting the busy tone. */
		running = c.state == 'connected' || c.state == 'held' ||
			  c.state == 'held_remote' || c.state == 'conference';
		clock.hidden(connected == null);

		if (connected != null)
			clock.text(elapsed(connected));

		/* The soft keys and their actions depend on the state. */
		act = {};

		if (w) {
			waiting.text(sprintf('Waiting: %s', party_name(w)));
			bar.set(0, { text: 'Answer', colour: C_OK });
			bar.set(1, { text: 'Decline', colour: C_ALERT });
			bar.set(2, '');
			act.s1 = function() { ctx.voice.answer(w.call); };
			act.s2 = function() { ctx.voice.reject(w.call); };
		}
		else {
			waiting.text('');

			let live = c.state == 'connected' || c.state == 'conference';
			let held = c.state == 'held' || c.state == 'held_remote';

			bar.set(0, live || held
				   ? (muted ? { text: 'Unmute', colour: C_WARN } : 'Mute')
				   : '');
			bar.set(1, held ? 'Resume' : (live ? 'Hold' : ''));
			bar.set(2, '');

			if (live || held)
				act.s1 = function() { ctx.voice.mute(); render(ctx.voice.call()); };
			if (held)
				act.s2 = function() { ctx.voice.resume(c.call); };
			else if (live)
				act.s2 = function() { ctx.voice.hold(c.call); };
		}

		bar.set(3, { text: 'End', colour: C_ALERT });
		act.s4 = function() { ctx.voice.hangup(c.call); };
	}

	render(call);

	return {
		obj,
		group: null,
		call_update: render,
		enter: function() {
			timer = uloop.interval(1000, function() {
				if (running && connected != null)
					clock.text(elapsed(connected));
			});
		},
		leave: function() {
			if (timer)
				timer.cancel();
		},
		key: function(code) {
			if (code == KEY_S1 && act.s1) {
				act.s1();

				return true;
			}

			if (code == KEY_S2 && act.s2) {
				act.s2();

				return true;
			}

			if (code == KEY_S4 && act.s4) {
				act.s4();

				return true;
			}

			return false;
		}
	};
};
