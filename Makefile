.PHONY: rel deps

all: deps
	@rebar compile

build:
	@rebar compile

distclean: clean
	./rebar delete-deps

deps:
	@rebar get-deps

clean:
	@rebar clean
