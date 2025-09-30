all: clean test examples build

build:
	@zig build

test:
	@zig build test --summary all

examples:
	@mkdir -p tmp
	@echo "Running all Flow examples..."
	@for example in examples/*.flow; do \
		echo "Testing $$example..."; \
		zig build flow -- $$example > /dev/null 2>&1 || { echo "FAILED: $$example"; exit 1; }; \
	done
	@echo "All examples passed!"

.PHONY: all build test examples clean coverage

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
	@find tmp -type f ! -name 'test.txt' -delete 2>/dev/null || true
	@mkdir -p tmp
