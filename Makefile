.PHONY: rel deps

all: 
	@rebar compile

deps:
	@rebar get-deps

clean:
	@rebar clean
