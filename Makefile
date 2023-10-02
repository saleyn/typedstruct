all: deps check

deps:
	mix deps.get

check compile:
	mix $@

publish:
	VERBATIM_VERSION=1 mix hex.publish $(if $(replace),--replace)

.PHONY: deps
