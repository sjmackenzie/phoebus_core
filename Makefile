.PHONY: rel deps

all: deps
	@rebar compile

compile:
	@rebar compile

distclean: clean
	./rebar delete-deps

deps:
	@rebar get-deps

clean:
	@rebar clean

dialyzer: compile
	@dialyzer -Wno_return -c apps/phoebus_core/ebin
