IMAGE_REGISTRY ?= joshgav
IMAGE_NAME ?= functions-runtime-go-sample
IMAGE_VERSION ?= latest

plugins = grpc
target = go
proto_location = ./proto/
proto_source = https://raw.githubusercontent.com/Azure/azure-functions-host/dev/src/WebJobs.Script.Grpc/azure-functions-language-worker-protobuf/src/proto/FunctionRpc.proto
proto_out_dir = rpc/

protoc_version = 3.5.1
protoc_plat = linux
protoc_arch = x86_64
protoc_dl_root = https://github.com/google/protobuf/releases/download
protoc_zip_name = protoc-$(protoc_version)-$(protoc_plat)-$(protoc_arch).zip

GOLANG_WORKER_BINARY = go-worker
SAMPLES := $(wildcard sample/*)

runtime:
	docker build \
		--tag "$(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_VERSION)" \
		--file "./Dockerfile" \
		.

go-worker: dep
	GOOS=linux go build -o $(GOLANG_WORKER_BINARY)

dep:
	go get -u github.com/golang/dep/... && \
		dep ensure

grpc: 
	mkdir $(proto_location) || true
	curl -sSL -o $(proto_location)/FunctionRpc.proto $(proto_source)
	go get -u github.com/golang/protobuf/proto
	go get -u github.com/golang/protobuf/protoc-gen-go
	go get -u google.golang.org/grpc
	curl -sSLO \
		$(protoc_dl_root)/v$(protoc_version)/$(protoc_zip_name)
	unzip -q -u $(protoc_zip_name) -d $(proto_location)
	rm $(protoc_zip_name)
	./proto/bin/protoc -I $(proto_location) \
		--$(target)_out=plugins=$(plugins):$(proto_out_dir) \
		$(proto_location)*.proto

samples : $(SAMPLES)

$(SAMPLES) :
	cd $@ && \
		go build -buildmode=plugin

.PHONY: go-worker grpc dep samples $(SAMPLES)
