K3D_KUBECONFIG_PATH?=./integration.yaml
MANIFEST_PATH?=./manifest/all-in-one.yaml
CLUSTER_NAME=bonny-ex

.PHONY: test lint analyze docs i

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

lint:
	mix format
	mix credo

test:
	mix test --cover

analyze:
	mix dialyzer

docs:
	mix docs
