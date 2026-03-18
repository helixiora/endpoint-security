SHELL := /bin/bash

FLUTTER ?= flutter
DART ?= dart
NODE ?= node

.PHONY: help bootstrap format format-check analyze test apps-script-check check pre-commit hooks-install

help:
	@printf '%s\n' \
		'bootstrap         Install Flutter dependencies' \
		'format            Format Dart sources' \
		'format-check      Verify Dart formatting' \
		'analyze           Run flutter analyze' \
		'test              Run flutter test' \
		'apps-script-check Validate backend/google-apps-script/Code.gs' \
		'check             Run all local quality checks' \
		'pre-commit        Alias for check' \
		'hooks-install     Configure Git to use .githooks/'

bootstrap:
	$(FLUTTER) pub get

format:
	$(DART) format lib test

format-check:
	$(DART) format --output=none --set-exit-if-changed lib test

analyze:
	$(FLUTTER) analyze

test:
	$(FLUTTER) test

apps-script-check:
	$(NODE) scripts/check-apps-script.mjs

check: format-check apps-script-check analyze test

pre-commit: check

hooks-install:
	git config core.hooksPath .githooks
