# more info: https://github.com/casey/just

lint:
	cargo fmt -- --check
	cargo clippy -- -D warnings

sec:
	cargo audit

test:
	cargo test

dev:
	cargo watch -x check -x test -x run
