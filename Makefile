BUILD_TAG ?= latest
BUILD_TAG_ALPINE ?= latest-alpine
BUILD_CACHE_TAG = latest-builder-cache
IMAGE_NAME = kubernetes-fluentd
ECR_URL = public.ecr.aws/sumologic
REPO_URL = $(ECR_URL)/$(IMAGE_NAME)

build:
	DOCKER_BUILDKIT=1 docker build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--cache-from $(REPO_URL):$(BUILD_CACHE_TAG) \
		--target builder \
		--tag $(IMAGE_NAME):$(BUILD_CACHE_TAG) \
		.

	DOCKER_BUILDKIT=1 docker build \
		--build-arg BUILD_TAG=$(BUILD_TAG) \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--cache-from $(REPO_URL):$(BUILD_CACHE_TAG) \
		--cache-from $(REPO_URL):latest \
		--tag $(IMAGE_NAME):$(BUILD_TAG) \
		.

build-alpine:
	docker build \
		--build-arg BUILD_TAG=$(BUILD_TAG_ALPINE) \
		--tag $(IMAGE_NAME):$(BUILD_TAG_ALPINE) \
		--file alpine.Dockerfile \
		.

push:
	docker tag $(IMAGE_NAME):$(BUILD_CACHE_TAG) $(REPO_URL):$(BUILD_CACHE_TAG)
	docker push $(REPO_URL):$(BUILD_CACHE_TAG)
	docker tag $(IMAGE_NAME):$(BUILD_TAG) $(REPO_URL):$(BUILD_TAG)
	docker push $(REPO_URL):$(BUILD_TAG)

login:
	aws ecr-public get-login-password --region us-east-1 \
	| docker login --username AWS --password-stdin $(ECR_URL)

build-push-multiplatform:
	REPO_URL=$(REPO_URL) BUILD_TAG=$(BUILD_TAG) ./ci/build-push-multiplatform.sh

build-push-multiplatform-alpine:
	docker buildx build \
		--push \
		--platform linux/amd64,linux/arm/v7,linux/arm64 \
		--build-arg BUILD_TAG=$(BUILD_TAG)-alpine \
		--tag $(REPO_URL):$(BUILD_TAG)-alpine \
		--file alpine.Dockerfile \
		.

.PHONY: image-test
image-test:
	ruby test/test_docker.rb

.PHONY: image-test-alpine
image-test-alpine:
	IMAGE_NAME=$(IMAGE_NAME):$(BUILD_TAG_ALPINE) ruby test/test_docker.rb

.PHONY: test
test: test-fluent-plugin-datapoint test-fluent-plugin-enhance-k8s-metadata test-fluent-plugin-events test-fluent-plugin-kubernetes-metadata-filter test-fluent-plugin-kubernetes-sumologic test-fluent-plugin-prometheus-format test-fluent-plugin-protobuf

.PHONY: test-fluent-plugin-datapoint
test-fluent-plugin-datapoint:
	( cd fluent-plugin-datapoint && bundle install && bundle exec rake )

.PHONY: test-fluent-plugin-enhance-k8s-metadata
test-fluent-plugin-enhance-k8s-metadata:
	( cd fluent-plugin-enhance-k8s-metadata && bundle install && bundle exec rake )

.PHONY: test-fluent-plugin-events
test-fluent-plugin-events:
	( cd fluent-plugin-events && bundle install && bundle exec rake )

.PHONY: test-fluent-plugin-kubernetes-metadata-filter
test-fluent-plugin-kubernetes-metadata-filter:
	( cd fluent-plugin-kubernetes-metadata-filter && bundle install && bundle exec rake )

.PHONY: test-fluent-plugin-kubernetes-sumologic
test-fluent-plugin-kubernetes-sumologic:
	( cd fluent-plugin-kubernetes-sumologic && bundle install && bundle exec rake )

.PHONY: test-fluent-plugin-prometheus-format
test-fluent-plugin-prometheus-format:
	( cd fluent-plugin-prometheus-format && bundle install && bundle exec rake )

.PHONY: test-fluent-plugin-protobuf
test-fluent-plugin-protobuf:
	( cd fluent-plugin-protobuf && bundle install && bundle exec rake )
