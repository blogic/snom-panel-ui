'use strict';

import { readfile } from 'fs';

const PHONEBOOK = '/etc/voice/phonebook.json';

function number_clean(s) {
	let digits = replace(s ?? '', /[^0-9]/g, '');

	if (substr(s ?? '', 0, 1) == '+')
		return '+' + digits;

	if (substr(digits, 0, 2) == '00')
		return '+' + substr(digits, 2);

	return digits;
}

function number_same(a, b) {
	if (a == '' || b == '')
		return false;

	if (a == b)
		return true;

	if (substr(a, 0, 1) == '+' && substr(b, 0, 1) == '0')
		return substr(a, -(length(b) - 1)) == substr(b, 1);

	if (substr(b, 0, 1) == '+' && substr(a, 0, 1) == '0')
		return substr(b, -(length(a) - 1)) == substr(a, 1);

	return false;
}

function phonebook_name(number) {
	let want = number_clean(number);
	let entries;

	if (want == '')
		return null;

	try {
		entries = json(readfile(PHONEBOOK) ?? '[]');
	}
	catch (e) {
		return null;
	}

	if (type(entries) != 'array')
		return null;

	for (let e in entries)
		if (type(e?.name) == 'string' && e.name != '' &&
		    number_same(number_clean(e.number), want))
			return e.name;

	return null;
}

function has_number(c) {
	return c.number != '' && c.number != null;
}

/**
 * party_name - the name the screen shows for the far end of a call
 * @c: the call object, of name, number and direction
 *
 * The phone book name of the number comes first, then a name from the network
 * that is not the number itself. An inbound number with neither is "Unknown",
 * and an inbound call without a number is "Withheld". An outbound call without
 * a name shows its number, and is blank while nothing is dialled.
 *
 * Return: a string.
 */
export function party_name(c) {
	let name = has_number(c) ? phonebook_name(c.number) : null;

	if (name)
		return name;

	if (c.name != '' && c.name != null && c.name != c.number)
		return c.name;

	if (c.direction != 'in')
		return c.number ?? '';

	return has_number(c) ? 'Unknown' : 'Withheld';
};

/**
 * party_number - the number the screen shows below the name
 * @c: the call object, of name, number and direction
 *
 * Return: the number, or "" when party_name() already shows it.
 */
export function party_number(c) {
	if (!has_number(c))
		return '';

	return party_name(c) == c.number ? '' : c.number;
};
