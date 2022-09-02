K3D_KUBECONFIG_PATH?=./integration.yaml
MANIFEST_PATH?=./manifest/all-in-one.yaml
CLUSTER_NAME=bonny-ex

.PHONY: help
help: ## Show this help
help:
	@grep -E '^[\/a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: test lint docs analyze

integration.yaml: ## Create a k3d cluster
	- k3d cluster delete ${CLUSTER_NAME}
	k3d cluster create ${CLUSTER_NAME} --servers 1 --wait
	k3d kubeconfig get ${CLUSTER_NAME} > ${K3D_KUBECONFIG_PATH}
	sleep 5

.PHONY: test.integration
test.integration: integration.yaml
test.integration: ## Run integration tests using k3d `make cluster`
	MIX_ENV=test mix bonny.gen.manifest --out ${MANIFEST_PATH}
	kubectl config use-context k3d-${CLUSTER_NAME}
	kubectl apply -f ${MANIFEST_PATH} 
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --only integration

.PHONY: k3d.delete
k3d.delete: ## Delete k3d cluster
	- k3d cluster delete ${CLUSTER_NAME}
	rm ${K3D_KUBECONFIG_PATH}

.PHONY: k3d.create
k3d.create: ## Created k3d cluster
	k3d cluster create ${CLUSTER_NAME} --servers 1 --wait

.PHONY: lint
lint:
	mix format
	mix credo

.PHONY: test
test:
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test --include integration --cover

.PHONY: test.watch
test.watch: integration.yaml
test.watch: ## Run all tests with mix.watch
	TEST_KUBECONFIG=${K3D_KUBECONFIG_PATH} mix test.watch --include integration

.PHONY: analyze
analyze:
	mix dialyzer

.PHONY: docs
docs:
	mix docs
