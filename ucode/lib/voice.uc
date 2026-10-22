'use strict';

import * as ubus from 'ubus';

/*
 * The panel's view of the uvoice daemon.
 *
 * uvoice owns the call state and publishes the `voice` ubus object: the verbs
 * dial, answer, reject, hangup, hold, resume, mute, audio and volume, and the
 * notifications call, device, registration and mwi. The API is UVOICE-D735.md
 * section 5.8. This client subscribes to `voice` for the notifications and calls
 * the verbs.
 *
 * Call states (string): dialling, calling, ringback, ringing, connected, held,
 * held_remote, conference, clearing, idle. idle is the last event of a call,
 * after which the id is gone. name and number are "" when unknown or withheld.
 */

/* How active a state is, for picking the call the screen shows. */
const RANK = {
	connected: 7, conference: 7, held: 6, held_remote: 6,
	clearing: 5, calling: 4, ringback: 4, dialling: 3, ringing: 2
};

let on_change;
let on_device;
let sub;
let listener;

let accounts = [];
let device = { path: 'none', mute: false, volume: 5, dnd: false };
let calls = {};
let mwi = {};
let missed = 0;
let missed_pushed;
let seen_seq = 0;
let cleared_seq = 0;
let dial_inflight;

function voice_cmd(method, args) {
	try {
		return ubus.call({ object: 'voice', method, data: args ?? {} });
	}
	catch (e) {
		return null;
	}
}

/**
 * voice_call - the call the screen shows
 *
 * The focused call, else the most active one.
 *
 * Return: a call object, or null.
 */
export function voice_call() {
	let best;

	for (let id, c in calls) {
		if (c.focused)
			return c;

		if (!best || (RANK[c.state] ?? 0) > (RANK[best.state] ?? 0))
			best = c;
	}

	return best;
};

/**
 * voice_waiting - a second call ringing while another is current
 *
 * Return: the ringing call that is not the current one, or null.
 */
export function voice_waiting() {
	let cur = voice_call();

	for (let id, c in calls)
		if (c != cur && c.state == 'ringing')
			return c;

	return null;
};

/**
 * voice_count - how many calls exist
 */
export function voice_count() {
	return length(calls);
};

/**
 * voice_device - the audio device state: path, mute, volume, dnd
 */
export function voice_device() {
	return device;
};

/**
 * voice_mwi - whether any line has a waiting message
 */
export function voice_mwi() {
	for (let line, m in mwi)
		if (m?.waiting)
			return true;

	return false;
};

/*
 * Missed calls come from uvoice's call log, not from counting events: a missed
 * call is an inbound record that was not answered. The count is the records
 * past the highest sequence the user has seen, and the list is the records past
 * the highest sequence the user cleared.
 *
 * uvoice keeps the log in memory and its sequence restarts at 1 when uvoiced
 * restarts, so a mark from the previous uvoiced would hide every new record.
 * When the highest sequence in the log is below a mark, the sequence space
 * restarted, so the mark is dropped.
 */
function cdr_records() {
	let r = voice_cmd('cdr');

	return type(r?.cdr) == 'array' ? r.cdr : [];
}

function missed_push() {
	let on = missed > 0;

	if (on === missed_pushed)
		return;

	voice_cmd('missed', { on });
	missed_pushed = on;
}

function missed_recount() {
	let records = cdr_records();
	let high = 0;

	for (let e in records)
		if ((e.seq ?? 0) > high)
			high = e.seq;

	if (high < seen_seq)
		seen_seq = 0;

	if (high < cleared_seq)
		cleared_seq = 0;

	let n = 0;

	for (let e in records)
		if (e.inbound && !e.answered && (e.seq ?? 0) > seen_seq)
			n++;

	missed = n;
	missed_push();
}

/**
 * voice_missed - the count of missed calls newer than the last seen
 */
export function voice_missed() {
	return missed;
};

/**
 * voice_missed_refresh - recount missed calls from the call log
 *
 * uvoice sends a cdr notification once a record is readable, and the recount
 * follows that event. The idle screen calls this on entry so the count is right
 * at start up and after a resubscribe, when no event was seen.
 */
export function voice_missed_refresh() {
	missed_recount();
};

/**
 * voice_missed_clear - mark every missed call as seen
 */
export function voice_missed_clear() {
	for (let e in cdr_records())
		if ((e.seq ?? 0) > seen_seq)
			seen_seq = e.seq;

	missed = 0;
	missed_push();
};

/**
 * voice_missed_wipe - drop every missed call from the list
 *
 * uvoice keeps its call log; the panel stops listing the records it holds now.
 */
export function voice_missed_wipe() {
	voice_missed_clear();
	cleared_seq = seen_seq;
};

/**
 * voice_missed_list - the missed calls in the call log, newest first
 *
 * Return: an array of objects of number, name and start.
 */
export function voice_missed_list() {
	let list = [];

	for (let e in cdr_records())
		if (e.inbound && !e.answered && (e.seq ?? 0) > cleared_seq)
			unshift(list, { number: e.remote ?? '', name: e.name ?? '',
					start: e.start });

	return list;
};

/**
 * voice_account - the account the idle screen shows
 *
 * Return: label, number and registered.
 */
export function voice_account() {
	let a = accounts[0];

	if (a)
		return { label: a.label, number: a.user, registered: a.registered };

	return { label: '', number: '', registered: false };
};

function emit() {
	if (on_change)
		on_change(voice_call());
}

function default_line() {
	return accounts[0]?.line ?? 0;
}

function call_id(id) {
	if (id != null)
		return id;

	let c = voice_call();

	return c ? c.call : null;
}

/**
 * voice_dial - place an outgoing call
 * @number: the digits dialled
 */
export function voice_dial(number) {
	if (!number)
		return;

	/* The next empty dialling event is this dial's own, not a hook-up, so the
	   pre-dial handoff must not dial it again. */
	dial_inflight = true;

	voice_missed_clear();

	voice_cmd('dial', { line: default_line(), number });
};

/**
 * voice_dialing - whether a dial the panel sent is still in flight
 */
export function voice_dialing() {
	return !!dial_inflight;
};

/**
 * voice_answer - answer a ringing call
 * @id: the call, or null for the current one
 */
export function voice_answer(id) {
	let c = call_id(id);

	if (c == null)
		return;

	voice_missed_clear();

	voice_cmd('answer', { call: c });
};

/**
 * voice_reject - decline a ringing call
 * @id: the call, or null for the current one
 */
export function voice_reject(id) {
	let c = call_id(id);

	if (c != null)
		voice_cmd('reject', { call: c });
};

/**
 * voice_hangup - end a call
 * @id: the call, or null for the current one
 */
export function voice_hangup(id) {
	let c = call_id(id);

	if (c != null)
		voice_cmd('hangup', { call: c });
};

/**
 * voice_hold - put a call on hold
 * @id: the call, or null for the current one
 */
export function voice_hold(id) {
	let c = call_id(id);

	if (c != null)
		voice_cmd('hold', { call: c });
};

/**
 * voice_resume - take a call off hold
 * @id: the call, or null for the current one
 */
export function voice_resume(id) {
	let c = call_id(id);

	if (c != null)
		voice_cmd('resume', { call: c });
};

/**
 * voice_mute - mute or unmute the microphone
 * @on: true to mute, or null to toggle
 *
 * Return: the requested mute state.
 */
export function voice_mute(on) {
	let want = on ?? !device.mute;

	voice_cmd('mute', { on: want });

	return want;
};

function state_read() {
	let a = voice_cmd('accounts');

	if (type(a?.accounts) == 'array')
		accounts = a.accounts;

	let c = voice_cmd('calls');

	if (!c)
		return;

	calls = {};

	for (let entry in c.calls ?? [])
		if (entry?.call != null)
			calls[entry.call] = entry;

	if (c.device)
		device = c.device;

	missed_recount();
}

function call_notify(data) {
	if (data?.call == null)
		return;

	/* A calling, connected or ended event settles our own dial. */
	if (data.state == 'calling' || data.state == 'connected' ||
	    data.state == 'idle')
		dial_inflight = false;

	if (data.state == 'idle') {
		delete calls[data.call];
		emit();

		return;
	}

	/* uvoice moves focus without an event for the call that loses it, so clear
	   the stale flag on the others when a focused call arrives. */
	if (data.focused)
		for (let id, c in calls)
			if (id != `${data.call}`)
				c.focused = false;

	calls[data.call] = data;

	emit();
}

function reg_notify(data) {
	for (let a in accounts)
		if (a.line == data?.line) {
			a.registered = (data.state == 'registered');

			if (data.label)
				a.label = data.label;
		}

	emit();
}

function notify(req) {
	if (req.type == 'call')
		call_notify(req.data);
	else if (req.type == 'device') {
		device = req.data ?? device;

		if (on_device)
			on_device(device);

		emit();
	}
	else if (req.type == 'registration')
		reg_notify(req.data);
	else if (req.type == 'mwi' && req.data?.line != null)
		mwi[req.data.line] = req.data;
	else if (req.type == 'cdr')
		missed_recount();
}

function present() {
	try {
		for (let obj in ubus.list() ?? [])
			if (obj == 'voice')
				return true;
	}
	catch (e) {}

	return false;
}

function voice_gone(id) {
	calls = {};
	device = { path: 'none', mute: false, volume: 5, dnd: false };

	for (let a in accounts)
		a.registered = false;

	emit();
}

function attach() {
	missed_pushed = null;

	try {
		sub.subscribe('voice');
	}
	catch (e) {}

	state_read();
	emit();
}

/**
 * voice_init - subscribe to uvoice and read the current state
 * @opts: on_change, called with the focused call whenever a call changes;
 *	  on_device, called with the device whenever it changes
 *
 * uvoiced may start after the panel, and procd respawns it after a crash. A
 * restart gives the voice object a new id and drops the subscription, so the
 * panel re-subscribes and re-reads whenever the object reappears, and clears the
 * call when it goes.
 *
 * Return: whether the voice object was on the bus at start up.
 */
export function voice_init(opts) {
	on_change = opts?.on_change;
	on_device = opts?.on_device;

	sub = ubus.subscriber(notify, voice_gone);

	listener = ubus.listener('ubus.object.add', function(type, data) {
		if (data?.path == 'voice')
			attach();
	});

	let found = present();

	if (found)
		attach();
	else
		warn('snom-panel: waiting for the voice object\n');

	return found;
};
