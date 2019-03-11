.PHONY: test lint analyze docs i

all: test lint docs analyze

lint:
	mix format
	mix credo

test:
	mix test --cover

analyze:
	mix dialyzer

docs:
	mix docs
