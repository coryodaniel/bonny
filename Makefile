KUBECONFIG_PATH?=./integration.yaml
CLUSTER_NAME=bonny-ex

.PHONY: help
help: ## Show this help
help:
	@grep -E '^[\/a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: test lint docs analyze

integration.yaml: ## Create a kind cluster
	$(MAKE) cluster.delete cluster.create
	kind export kubeconfig --kubeconfig ${KUBECONFIG_PATH} --name "${CLUSTER_NAME}" 

.PHONY: test.integration
test.integration: integration.yaml
test.integration: ## Run integration
	kubectl config use-context kind-${CLUSTER_NAME} tests using kind `make cluster`
	MIX_ENV=test mix compile
	MIX_ENV=test mix bonny.gen.manifest -o - | kubectl apply -f -
	TEST_KUBECONFIG=${KUBECONFIG_PATH} mix test --only integration

.PHONY: cluster.delete
cluster.delete: ## Delete kind cluster
	- kind delete cluster --kubeconfig ${KUBECONFIG_PATH} --name "${CLUSTER_NAME}"
	rm -f ${KUBECONFIG_PATH}

.PHONY: cluster.create
cluster.create: ## Created kind cluster
	kind create cluster --wait 600s --name "${CLUSTER_NAME}"

.PHONY: lint
lint:
	mix format
	mix credo

.PHONY: test
test: integration.yaml
test:
	kubectl config use-context kind-${CLUSTER_NAME}
	MIX_ENV=test mix compile
	MIX_ENV=test mix bonny.gen.manifest -o - | kubectl apply -f -
	TEST_KUBECONFIG=${KUBECONFIG_PATH} mix test --include integration --cover

.PHONY: test.watch
test.watch: integration.yaml
test.watch: ## Run all tests with mix.watch
	kubectl config use-context kind-${CLUSTER_NAME}
	MIX_ENV=test mix compile
	MIX_ENV=test mix bonny.gen.manifest -o - | kubectl apply -f -
	TEST_KUBECONFIG=${KUBECONFIG_PATH} mix test.watch --include integration

.PHONY: analyze
analyze:
	mix dialyzer

.PHONY: docs
docs:
	mix docs
