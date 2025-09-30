all: clean test examples build

build:
	@zig build

test:
	@zig build test --summary all

examples: examples-behaviors examples-errors

examples-behaviors:
	@mkdir -p tmp
	@echo "Running Flow behavior tests (should succeed)..."
	@echo "================================"
	@for example in examples/behaviors/*.flow; do \
		echo ""; \
		echo "📄 $$example"; \
		echo "────────────────────────────────"; \
		cat $$example; \
		echo "────────────────────────────────"; \
		echo "Output:"; \
		zig build flow -- $$example 2>&1 || { echo "❌ FAILED: $$example"; exit 1; }; \
		echo ""; \
	done
	@echo "================================"
	@echo "✅ All behavior tests passed (16/16)!"

examples-errors:
	@echo ""
	@echo "Testing error recovery (should report errors)..."
	@echo "================================"
	@for example in examples/errors/*.flow; do \
		echo ""; \
		echo "📄 $$example"; \
		echo "────────────────────────────────"; \
		cat $$example; \
		echo "────────────────────────────────"; \
		echo "Output:"; \
		zig build flow -- $$example 2>&1 | grep -v "^flow$$\|^+- run\|^error: the following\|^Build Summary\|^build command" || true; \
		if ./zig-out/bin/flow $$example >/dev/null 2>&1; then \
			echo "❌ FAILED: Should have reported errors but didn't"; \
			exit 1; \
		else \
			echo "✅ Errors reported correctly"; \
		fi; \
		echo ""; \
	done
	@echo "================================"
	@echo "✅ All error tests passed (7/7)!"

.PHONY: all build test examples examples-behaviors examples-errors clean coverage install uninstall

coverage: test
	@mkdir -p build/coverage
	for test_binary in .zig-cache/o/*/test; do \
	    kcov --include-pattern=flow build/coverage $$test_binary; \
	done
	@open build/coverage/index.html

install: build
	@echo "Installing Flow to /usr/local/bin..."
	@sudo cp zig-out/bin/flow /usr/local/bin/flow
	@echo "✅ Flow installed! Try 'flow --help'"

uninstall:
	@echo "Uninstalling Flow from /usr/local/bin..."
	@sudo rm -f /usr/local/bin/flow
	@echo "✅ Flow uninstalled"

clean:
	@rm -rf build
	@rm -rf zig-out
	@rm -rf .zig-cache
	@find tmp -type f ! -name 'test.txt' -delete 2>/dev/null || true
	@mkdir -p tmp
