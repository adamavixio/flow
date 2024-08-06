all: clean test build 

build:
	@zig build

test:
	@zig build test --summary all

coverage: test
	@mkdir -p build/coverage
	for test_binary in .zig-cache/o/*/test; do \
	    kcov --include-pattern=flow build/coverage $$test_binary; \
	done
	@open build/coverage/index.html

clean:
	@rm -rf build
	@rm -rf zig-out
	@rm -rf .zig-cache
