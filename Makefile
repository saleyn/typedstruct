all: deps check

deps:
	mix deps.get

check compile:
	mix $@

publish:
	HEX_PUBLISH=1 mix hex.publish $(if $(replace),--replace)

.PHONY: deps
