BUILD_TAG ?= latest
BUILD_CACHE_TAG = latest-builder-cache
IMAGE_NAME = kubernetes-fluentd
ECR_URL = public.ecr.aws/u5z5f8z6
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

push:
	docker tag $(IMAGE_NAME):$(BUILD_CACHE_TAG) $(REPO_URL):$(BUILD_CACHE_TAG)
	docker push $(REPO_URL):$(BUILD_CACHE_TAG)
	docker tag $(IMAGE_NAME):$(BUILD_TAG) $(REPO_URL):$(BUILD_TAG)
	docker push $(REPO_URL):$(BUILD_TAG)

login:
	aws ecr-public get-login-password --region us-east-1 \
	| docker login --username AWS --password-stdin $(ECR_URL)

.PHONY: image-test
image-test:
	ruby test/test_docker.rb

.PHONY: test
test:
	( cd fluent-plugin-datapoint && bundle install && bundle exec rake )
	( cd fluent-plugin-enhance-k8s-metadata && bundle install && bundle exec rake )
	( cd fluent-plugin-events && bundle install && bundle exec rake )
	( cd fluent-plugin-kubernetes-metadata-filter && bundle install && bundle exec rake )
	( cd fluent-plugin-kubernetes-sumologic && bundle install && bundle exec rake )
	( cd fluent-plugin-prometheus-format && bundle install && bundle exec rake )
	( cd fluent-plugin-protobuf && bundle install && bundle exec rake )
