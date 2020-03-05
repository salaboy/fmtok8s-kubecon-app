CHART_REPO := http://jenkins-x-chartmuseum:8080
NAME := kubecon-app
OS := $(shell uname)

CHARTMUSEUM_CREDS_USR := $(shell cat /builder/home/basic-auth-user.json)
CHARTMUSEUM_CREDS_PSW := $(shell cat /builder/home/basic-auth-pass.json)

init:
	helm init --client-only

setup: init
	helm repo add jenkins-x http://chartmuseum.jenkins-x.io
	helm repo add zeebe http://helm.zeebe.io
	helm repo add releases ${CHART_REPO}
    helm repo update

build: clean setup
	helm dependency build kubecon-app
	helm lint kubecon-app

install: clean build
	helm upgrade ${NAME} kubecon-app --install

upgrade: clean build
	helm upgrade ${NAME} kubecon-app --install

delete:
	helm delete --purge ${NAME} kubecon-app

clean:
	rm -rf kubecon-app/charts
	rm -rf kubecon-app/${NAME}*.tgz
	rm -rf kubecon-app/requirements.lock

release: clean build
ifeq ($(OS),Darwin)
	sed -i "" -e "s/version:.*/version: $(VERSION)/" kubecon-app/Chart.yaml

else ifeq ($(OS),Linux)
	sed -i -e "s/version:.*/version: $(VERSION)/" kubecon-app/Chart.yaml
else
	exit -1
endif
	helm package kubecon-app
	curl --fail -u $(CHARTMUSEUM_CREDS_USR):$(CHARTMUSEUM_CREDS_PSW) --data-binary "@$(NAME)-$(VERSION).tgz" $(CHART_REPO)/api/charts
	rm -rf ${NAME}*.tgz
	jx step changelog  --verbose --version $(VERSION) --rev $(PULL_BASE_SHA)
