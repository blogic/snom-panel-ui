'use strict';

import * as lv from 'lv';
import * as ubus from 'ubus';
import * as uci from 'uci';
import * as uloop from 'uloop';
import { readfile, writefile, glob, access } from 'fs';
import { background_set } from './lib/ui.uc';
import { state, sampler_init, sampler_awake, source_watch, source_subscribe,
	 source_release, source_seed } from 'lvgl.sampler';
import { sources_new, DEFAULTS } from 'lvgl.sources';
import { nav_init, nav_push, nav_pop, nav_replace, nav_reset,
	 nav_top } from 'lvgl.keynav';
import { voice_init, voice_dial, voice_dialing, voice_answer, voice_reject,
	 voice_hangup, voice_hold, voice_resume, voice_mute, voice_call,
	 voice_waiting, voice_device, voice_mwi, voice_missed,
	 voice_missed_refresh, voice_missed_clear, voice_missed_wipe, voice_missed_list,
	 voice_account } from './lib/voice.uc';
import { idle_new } from './screens/idle.uc';
import { dial_new } from './screens/dial.uc';
import { incoming_new } from './screens/incoming.uc';
import { active_new } from './screens/active.uc';
import { ended_new } from './screens/ended.uc';
import { firmware_new } from './screens/firmware.uc';
import { menu_new } from './screens/menu.uc';
import { missed_new } from './screens/missed.uc';
import { system_new } from './screens/system.uc';
import { brightness_new } from './screens/brightness.uc';

/* Input event codes handled raw, before the keymap. */
const KEY_ESC		= 1;
const KEY_PHONE		= 169;
const KEY_VOLUMEDOWN	= 114;
const KEY_VOLUMEUP	= 115;
const KEY_MESSENGER	= 0x1ae;

const KEY_UP		= 103;
const KEY_LEFT		= 105;
const KEY_RIGHT		= 106;
const KEY_DOWN		= 108;
const KEY_OK		= 0x160;
const KEY_NUMERIC_0	= 0x200;
const KEY_NUMERIC_STAR	= 0x20a;
const KEY_NUMERIC_POUND	= 0x20b;

const TICK_MIN		= 5;
const TICK_MAX		= 200;

const CSS_LOADER	= '/lib/firmware/css-loader';
const WAN_POLL_MS	= 2000;

const BG_DIR	= '/usr/share/snom-panel-ui/backgrounds';
const BG_DEFAULT = 7;
const CARD_OPA	= 108;	/* translucent, so the gradient shows through a card */

const BACKGROUNDS = [
	'bg-1-vert-lines', 'bg-2-horiz-lines', 'bg-3-vert-waves',
	'bg-4-horiz-waves', 'bg-5-diag-steep', 'bg-6-diag-shallow',
	'bg-7-diag-waves-steep', 'bg-8-diag-waves-shallow'
];

function background_load() {
	let which = BG_DEFAULT;

	let cursor = uci.cursor();

	if (cursor.load('snom_panel')) {
		let opt = cursor.get('snom_panel', '@panel[0]', 'background');

		if (opt != null && opt != '')
			which = +opt;
	}

	if (!which || which > length(BACKGROUNDS))
		return null;

	return lv.image_load(sprintf('%s/%s.png', BG_DIR, BACKGROUNDS[which - 1]));
}

function keymap_build() {
	let map = {
		[KEY_UP]: lv.KEY_PREV,
		[KEY_DOWN]: lv.KEY_NEXT,
		[KEY_LEFT]: lv.KEY_LEFT,
		[KEY_RIGHT]: lv.KEY_RIGHT,
		[KEY_OK]: lv.KEY_ENTER,
		[KEY_NUMERIC_STAR]: ord('*'),
		[KEY_NUMERIC_POUND]: ord('#')
	};

	for (let i = 0; i <= 9; i++)
		map[KEY_NUMERIC_0 + i] = ord('0') + i;

	return map;
}

let backlight = { path: null, max: 0 };
let level = 100;

function backlight_init() {
	let found = glob('/sys/class/backlight/*');

	if (!length(found))
		return;

	let max = readfile(found[0] + '/max_brightness');

	if (max == null)
		return;

	backlight.path = found[0] + '/brightness';
	backlight.max = +trim(max);
}

function backlight_apply() {
	if (!backlight.path)
		return;

	let raw = int(level * backlight.max / 100);

	writefile(backlight.path, sprintf('%d', raw > 0 ? raw : 1));
}

function board_read() {
	let board = {};

	try {
		let info = ubus.call({ object: 'system', method: 'board', data: {} });

		board.firmware = info?.release?.version ??
				 info?.release?.description ?? 'OpenWrt';
	}
	catch (e) {
		board.firmware = 'OpenWrt';
	}

	board.mac = trim(readfile('/sys/class/net/eth0/address') ?? '') || '-';

	try {
		let lan = ubus.call({ object: 'network.interface.lan',
				      method: 'status', data: {} });

		board.ip = lan?.['ipv4-address']?.[0]?.address ?? '-';
	}
	catch (e) {
		board.ip = '-';
	}

	return board;
}

function css_installed() {
	return access(CSS_LOADER, 'r');
}

function wan_up() {
	try {
		let s = ubus.call({ object: 'network.interface.wan',
				    method: 'status', data: {} });

		return !!s?.up;
	}
	catch (e) {
		return false;
	}
}

if (!lv.init())
	die('cannot initialise LVGL');

if (!lv.display_drm(getenv('PANEL_DRM_DEVICE') ?? '/dev/dri/card0', -1))
	die('cannot open the DRM display');

for (let path in [ '/dev/input/event0', '/dev/input/event1' ])
	lv.indev_keypad(path, keymap_build());

backlight_init();

let bg = background_load();

background_set(bg);

uloop.init();
sampler_init([ ...sources_new({ config: 'snom_panel' }) ], DEFAULTS);

const BOARD = board_read();

let ctx;

ctx = {
	state,
	board: BOARD,
	card_opa: bg != null ? CARD_OPA : lv.OPA_COVER,
	subscribe: source_subscribe,
	release: source_release,
	voice: {
		account: voice_account,
		call: voice_call,
		waiting: voice_waiting,
		device: voice_device,
		mwi: voice_mwi,
		dial: voice_dial,
		answer: voice_answer,
		reject: voice_reject,
		hangup: voice_hangup,
		hold: voice_hold,
		resume: voice_resume,
		mute: voice_mute,
		missed: voice_missed,
		missed_refresh: voice_missed_refresh,
		missed_clear: voice_missed_clear,
		missed_wipe: voice_missed_wipe,
		missed_list: voice_missed_list
	},
	brightness: {
		get: function() { return level; },
		set: function(pct) { level = pct; backlight_apply(); },
		save: function() {}
	},
	nav: {
		dial: function(seed) { nav_push(dial_new(ctx, seed)); },
		menu: function() { nav_push(menu_new(ctx)); },
		missed: function() { nav_push(missed_new(ctx)); },
		system: function() { nav_push(system_new(ctx)); },
		brightness: function() { nav_push(brightness_new(ctx)); },
		back: function() { nav_pop(); }
	}
};

let cur_kind;

/*
 * uvoice drives the call and device screens, and screen_sync picks the screen
 * from the current call and device state. A ringing incoming call shows the
 * incoming screen; every other live call state (dialling, calling, connected,
 * held, conference, clearing) shows the active screen, which renders the state
 * itself. With no call, the device state "ended" shows the hang-up screen, held
 * until the handset goes down; anything else returns to idle. The call and the
 * device notification both call screen_sync.
 */
function screen_sync() {
	let call = voice_call();
	let dev = voice_device();
	let kind;

	if (call)
		kind = call.state == 'ringing' ? 'in' : 'active';
	else if (dev.state == 'ended')
		kind = 'ended';
	else
		kind = null;

	/* A ringing second call during a connected one keeps the active screen and
	   is offered there, not as a new incoming screen. */
	if (kind == 'in' && cur_kind == 'active' && call?.state != 'ringing')
		kind = 'active';

	if (kind == cur_kind) {
		let top = nav_top();

		if ((kind == 'active' || kind == 'in') && top?.call_update)
			top.call_update(call);

		return;
	}

	if (kind == null) {
		cur_kind = null;
		nav_reset();

		return;
	}

	if (kind == 'ended') {
		let entry = ended_new(ctx);

		if (cur_kind == null)
			nav_push(entry);
		else
			nav_replace(entry);

		cur_kind = 'ended';

		return;
	}

	/* Pre-dial handoff: the user typed a number on the dial screen and lifted
	   the handset, so uvoice made an empty dialling call. Send the held digits
	   with dial; uvoice reuses the same call on the open handset path. Skip it
	   when the panel's own dial is still in flight, or the empty record that
	   dial creates would be dialled a second time. */
	if (kind == 'active' && call.state == 'dialling' && !call.number &&
	    !voice_dialing()) {
		let top = nav_top();
		let held = top?.number ? top.number() : '';

		if (held != '')
			voice_dial(held);
	}

	let entry = kind == 'in' ? incoming_new(ctx, call)
				 : active_new(ctx, call);

	/* Push over whatever is on screen, so a call that arrives while the user is
	   in a menu returns there when it ends. Replace only another call screen. */
	if (cur_kind == null)
		nav_push(entry);
	else
		nav_replace(entry);

	cur_kind = kind;
}

function call_changed(call) {
	screen_sync();
}

function device_changed(dev) {
	let top = nav_top();

	if (top?.device_update)
		top.device_update(dev);

	screen_sync();
}

/*
 * The hook, the volume keys, mute, speaker, headset and the digits during a
 * call all belong to uvoice, which reads the keypad itself, so the panel does
 * not touch them. It handles the cancel key, and the message key, which opens
 * the missed calls outside a call; the navigation keys and the soft keys reach
 * the screens through the keymap and the screen key handler.
 */
function global_key(code, value) {
	if (value != 1)
		return false;

	/* While uvoice holds the device in the ended state, every key is refused
	   until the handset goes down. Only an incoming call leaves the state, and
	   it does so through a device and call event, not a key. */
	if (cur_kind == 'ended' || cur_kind == 'firmware')
		return true;

	/* Cancel does not leave a call screen, or later events would update a
	   screen that is no longer there. During a call it is ignored; End ends it. */
	if (code == KEY_ESC) {
		if (cur_kind == null)
			nav_pop();

		return true;
	}

	if (code == KEY_MESSENGER) {
		if (cur_kind == null && !nav_top()?.number)
			ctx.nav.missed();

		return true;
	}

	return false;
}

voice_init({ on_change: call_changed, on_device: device_changed });

/* A control object, so a test can drive and look at the panel over ubus. */
const UI_OBJ = ubus.publish('snom_panel', {
	screenshot: {
		call: function(req) {
			let path = req.args?.path ?? '/tmp/snom-shot.png';

			lv.refresh();

			if (!lv.screenshot(path))
				return ubus.STATUS_UNKNOWN_ERROR;

			return { path };
		},
		args: { path: '' }
	},
	goto: {
		call: function(req) {
			let to = req.args?.screen;

			nav_reset();

			if (to == 'dial')
				ctx.nav.dial();
			else if (to == 'menu')
				ctx.nav.menu();
			else if (to == 'system')
				ctx.nav.system();
			else if (to == 'brightness')
				ctx.nav.brightness();
			else if (to == 'missed')
				ctx.nav.missed();

			lv.refresh();

			return { ok: true };
		},
		args: { screen: '' }
	}
});

source_watch(function(name, broadcast) {
	let top = nav_top();

	if (top?.update && index(top.needs ?? [], name) >= 0)
		top.update(name);
});

sampler_awake(true);

const IDLE = idle_new(ctx);

nav_init(IDLE, { on_key: global_key });

source_seed([ 'clock' ]);
source_subscribe([ 'clock' ]);
IDLE.update();

let firmware_poll;

function firmware_sync() {
	let top = nav_top();

	if (top?.wan_set)
		top.wan_set(wan_up());

	firmware_poll.set(WAN_POLL_MS);
}

if (!css_installed()) {
	cur_kind = 'firmware';
	nav_push(firmware_new(ctx));
	firmware_poll = uloop.timer(WAN_POLL_MS, firmware_sync);
	firmware_sync();
}

lv.refresh();
backlight_apply();

let boot_pid = getenv('SNOM_PANEL_BOOT_PID');

if (boot_pid) {
	let pid = readfile(boot_pid);

	if (pid)
		system([ 'kill', trim(pid) ]);
}

let tick;

function tick_run() {
	let delay = lv.timer_handler();

	if (delay == null) {
		uloop.end();

		return;
	}

	tick.set(min(max(delay, TICK_MIN), TICK_MAX));
}

tick = uloop.timer(TICK_MIN, tick_run);

uloop.signal('SIGTERM', function() { uloop.end(); });

uloop.run();
