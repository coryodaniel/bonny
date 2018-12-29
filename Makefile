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

i:
	BONNY_CONFIG_FILE=~/.kube/config MIX_ENV=test iex -S mix
