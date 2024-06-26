module main

fn test_readable_size() {
	assert readable_size(395, true) == '395'
	assert readable_size(395, false) == '395'

	assert readable_size(200_000, true) == '195.4k'
	assert readable_size(200_000, false) == '200.0kb'

	assert readable_size(100_000_000, true) == '95.4m'
	assert readable_size(100_000_000, false) == '100.0mb'

	assert readable_size(100_000_000_000, true) == '93.2g'
	assert readable_size(100_000_000_000, false) == '100.0gb'

	assert readable_size(100_000_000_000_000, true) == '91.0t'
	assert readable_size(100_000_000_000_000, false) == '100.0tb'

	assert readable_size(100_000_000_000_000_000, true) == '88.9p'
	assert readable_size(100_000_000_000_000_000, false) == '100.0pb'

	assert readable_size(8_000_000_000_000_000_000, true) == '7.0e'
	assert readable_size(8_000_000_000_000_000_000, false) == '8.0eb'
}
