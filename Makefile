.PHONY: rel deps

all: deps
	@rebar compile

build:
	@rebar compile

deps:
	@rebar get-deps

clean:
	@rebar clean
