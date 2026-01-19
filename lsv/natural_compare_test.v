module main

fn test_numbers_embdded_in_text() {
	a := 'log10.txt'
	b := 'log9.txt'

	assert string_compare(b, a, false) > 0
	assert natural_compare(&b, &a, false) < 0

	assert string_compare(a, b, false) < 0
	assert natural_compare(&a, &b, false) > 0

	assert string_compare(a, a, false) == 0
	assert natural_compare(&a, &a, false) == 0

	assert string_compare(b, b, false) == 0
	assert natural_compare(&b, &b, false) == 0
}

fn test_numbers_two_embdded_in_text() {
	a := '0log10.txt'
	b := '1log9.txt'

	assert string_compare(a, b, false) < 0
	assert natural_compare(&a, &b, false) < 0

	assert string_compare(b, a, false) > 0
	assert natural_compare(&b, &a, false) > 0

	assert string_compare(a, a, false) == 0
	assert natural_compare(&b, &b, false) == 0

	assert string_compare(b, b, false) == 0
	assert natural_compare(&b, &b, false) == 0
}

fn test_no_numbers_in_text() {
	a := 'abc'
	b := 'bca'

	assert string_compare(a, b, false) < 0
	assert natural_compare(&a, &b, false) < 0

	assert string_compare(b, a, false) > 0
	assert natural_compare(&b, &a, false) > 0

	assert string_compare(a, a, false) == 0
	assert natural_compare(&b, &b, false) == 0

	assert string_compare(b, b, false) == 0
	assert natural_compare(&b, &b, false) == 0
}
