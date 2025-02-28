all: deps check

deps:
	mix deps.get

check compile test:
	mix $@

publish:
	VERBATIM_VERSION=1 mix hex.publish $(if $(replace),--replace)

.PHONY: deps test
