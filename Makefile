.SILENT:
.SUFFIXES:
.SUFFIXES: .go .mod .sum .sql .yaml .json .toml .sh .md
.SHELLFLAGS: -ec
SHELL = /bin/sh
.DEFAULT_GOAL = help

##@ Options

INSTALL_PREFIX ?= $(CURDIR)/.local
RELEASE_TAG ?= $(shell bash build/gettag.sh)

export GOBIN := $(INSTALL_PREFIX)/bin
export PATH := $(GOBIN):$(PATH)
export MAC_CPU_BRAND=$(sysctl -n machdep.cpu.brand_string)

ifeq ($(findstring Apple,$(MAC_CPU_BRAND)),APPLE)
	export IS_APPLE_SILICON=true
else
	export IS_APPLE_SILICON=false
endif

ifeq ($(IS_APPLE_SILICON),true)
	export SKAFFOLD_URL=https://storage.googleapis.com/skaffold/releases/latest/skaffold-darwin-arm64
else
	export SKAFFOLD_URL=https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
endif

ifeq ($(IS_APPLE_SILICON),true)
	export SQLC_URL=https://downloads.sqlc.dev/sqlc_1.25.0_darwin_arm64.tar.gz
else
	export SQLC_URL=https://downloads.sqlc.dev/sqlc_1.25.0_linux_amd64.tar.gz
endif

ifeq ($(IS_APPLE_SILICON),true)
	export SWAG_URL=https://github.com/swaggo/swag/releases/download/v1.16.2/swag_1.16.2_Darwin_arm64.tar.gz
else
	export SWAG_URL=https://github.com/swaggo/swag/releases/download/v1.16.2/swag_1.16.2_Linux_x86_64.tar.gz
endif

##@ Commands

help: $(GOBIN)/makehelp ## Show this help
	$(GOBIN)/makehelp $(MAKEFILE_LIST)

info: ## Show build info
	@echo "INSTALL_PREFIX: $(INSTALL_PREFIX)"
	@echo "RELEASE_TAG: $(RELEASE_TAG)"

###@ Development

generate: $(GOBIN)/sqlc $(GOBIN)/swag ## Generate code
	go generate ./...

e2e: testinfra deploy ## Deploy the end-to-end setup

testinfra: $(GOBIN)/skaffold ## Create test infrastructure
	bash -x e2e/kind/up.sh
	skaffold run -f e2e/skaffold.yaml -p testinfra

deploy: $(GOBIN)/skaffold ## Deploy kobold, in dev mode, to k8s
	skaffold run -f e2e/skaffold.yaml -p kobold

###@ Checks

checks: ## Run all checks
	$(MAKE) lint test

test: ## Run tests
	go test -cover ./...

lint: $(GOBIN)/golangci-lint ## Run linter
	golangci-lint run --timeout 5m

diff: generate ## Check if code is up to date
	git diff --exit-code

###@ Release

release: dockerlogin artifacts ## Create a release
	$(MAKE) dockerpush upload

artifacts: ## Build all release assets to .artifacts
	bash build/artifacts.sh

upload: ## Upload release assets to github
	gh release upload $(RELEASE_TAG) .artifacts/*

dockerlogin: ## Login to dockerhub
	docker login --username bluebrown --password $(DOCKERHUB_TOKEN)

dockerimage: ## Build the docker image
	bash build/image.sh

dockerpush: ## Push docker images to the container registry
	docker push docker.io/bluebrown/kobold --all-tags

## Dependencies

$(GOBIN):
	mkdir -p $(GOBIN)

$(GOBIN)/makehelp: | $(GOBIN)
	curl -fsSL https://gist.githubusercontent.com/bluebrown/2ec155902622b5e46e2bfcbaff342eb9/raw/Makehelp.awk \
	| install /dev/stdin $(GOBIN)/makehelp

$(GOBIN)/skaffold: | $(GOBIN)
	curl -fsSL $(SKAFFOLD_URL) \
	| install /dev/stdin $(GOBIN)/skaffold

$(GOBIN)/golangci-lint: | $(GOBIN)
	curl -sfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh \
	| sh -s -- -b $(GOBIN) v1.55.2

$(GOBIN)/sqlc: | $(GOBIN)
	curl -fsSL $(SQLC_URL) \
	| tar -C $(GOBIN) -xzf - sqlc

$(GOBIN)/swag: | $(GOBIN)
	curl -fsSL $(SWAG_URL) \
	| tar -C $(GOBIN) -xzf - swag

$(GOBIN)/sqlite3: | $(GOBIN)
	bash build/sqlite3.sh $(INSTALL_PREFIX)
