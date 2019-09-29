# Copyright 2018 The Ceph-CSI Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.PHONY: all cephcsi-amd64

CONTAINER_CMD?=docker

CSI_IMAGE_NAME=$(if $(ENV_CSI_IMAGE_NAME),$(ENV_CSI_IMAGE_NAME),lstiebel/cephcsi)
CSI_IMAGE_VERSION=$(if $(ENV_CSI_IMAGE_VERSION),$(ENV_CSI_IMAGE_VERSION),latest)

$(info cephcsi image settings: $(CSI_IMAGE_NAME) version $(CSI_IMAGE_VERSION))

GIT_COMMIT=$(shell git rev-list -1 HEAD)

GO_PROJECT=github.com/ceph/ceph-csi

# go build flags
LDFLAGS ?=
LDFLAGS += -X $(GO_PROJECT)/pkg/util.GitCommit=$(GIT_COMMIT)
# CSI_IMAGE_VERSION will be considered as the driver version
LDFLAGS += -X $(GO_PROJECT)/pkg/util.DriverVersion=$(CSI_IMAGE_VERSION)

all: cephcsi-amd64 image-cephcsi-amd64 push-image-cephcsi-amd64 clean cephcsi-arm64 image-cephcsi-arm64 push-image-cephcsi-arm64  manifest clean

test: go-test static-check dep-check

go-test:
	./scripts/test-go.sh

dep-check:
	dep check

static-check:
	./scripts/lint-go.sh
	./scripts/lint-text.sh --require-all
	./scripts/gosec.sh

func-test:
	go test github.com/ceph/ceph-csi/e2e $(TESTOPTIONS)

.PHONY: cephcsi-amd64
cephcsi-amd64:
	if [ ! -d ./vendor ]; then dep ensure -vendor-only; fi
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -ldflags '$(LDFLAGS) -extldflags "-static"' -o  _output/cephcsi ./cmd/

cephcsi-arm64:
	if [ ! -d ./vendor ]; then dep ensure -vendor-only; fi
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -a -ldflags '$(LDFLAGS) -extldflags "-static"' -o  _output/cephcsi ./cmd/

image-cephcsi-amd64: cephcsi-amd64
	cp _output/cephcsi deploy/cephcsi/image/cephcsi
	$(CONTAINER_CMD) build -t $(CSI_IMAGE_NAME):$(CSI_IMAGE_VERSION)-amd64 deploy/cephcsi/image

push-image-cephcsi-amd64: image-cephcsi-amd64
	$(CONTAINER_CMD) push $(CSI_IMAGE_NAME):$(CSI_IMAGE_VERSION)-amd64

image-cephcsi-arm64: cephcsi-arm64
	cp _output/cephcsi deploy/cephcsi/image/cephcsi
	$(CONTAINER_CMD) build -t $(CSI_IMAGE_NAME):$(CSI_IMAGE_VERSION)-arm64 deploy/cephcsi/image

push-image-cephcsi-arm64: image-cephcsi-arm64
 	$(CONTAINER_CMD) push $(CSI_IMAGE_NAME):$(CSI_IMAGE_VERSION)-arm64

manifest:
	docker manifest create lstiebel/cephcsi:latest lstiebel/cephcsi:latest-amd64 lstiebel/cephcsi:latest-arm64 --amend

clean:
	go clean -r -x
	rm -f deploy/cephcsi/image/cephcsi
	rm -f _output/cephcsi
