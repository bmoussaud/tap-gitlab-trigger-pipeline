task: check-carvel
	kbld -f k8s/task.yaml | kubectl apply -f - 	

taskrun: task
	envsubst < k8s/taskrun.yaml | kubectl apply -f -

apply: taskrun

describe:
	kubectl describe taskrun.tekton.dev trigger-gitlab-pipeline-run -n tap-tasks

get:
	kubectl get tasks.tekton.dev -n tap-tasks trigger-gitlab-pipeline
	kubectl get taskrun.tekton.dev trigger-gitlab-pipeline-run -n tap-tasks

logs:
	kubectl logs -n tap-tasks trigger-gitlab-pipeline-run-pod -f

clean:
	kubectl delete -f k8s/taskrun.yaml
	kubectl delete tasks.tekton.dev -n tap-tasks trigger-gitlab-pipeline


build-image:
	./build-alpine-image.sh

push-image: build-image
	docker tag org.bmoussaud/alpine-gitlab-cli-11:latest akseutap8registry.azurecr.io/tanzu-application-platform/alpine-gitlab-cli-11:latest
	docker push akseutap8registry.azurecr.io/tanzu-application-platform/alpine-gitlab-cli-11:latest

check-carvel:
	$(foreach exec,$(CARVEL_BINARIES),\
		$(if $(shell which $(exec)),,$(error "'$(exec)' not found. Carvel toolset is required. See instructions at https://carvel.dev/#install")))

