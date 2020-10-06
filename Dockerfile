FROM node:12.13-stretch-slim

# following are labels to be carried with the image's manifest so they are discoverable in running environment not just in container registry
# source of container image (regardless of mirroring that occurs)
ARG IMAGE_SRC=unspecified
LABEL image_src=${IMAGE_SRC}
# traceability info about where the build occurred
ARG BUILT_BY=unspecified
LABEL built_by=${BUILT_BY}
# semver string
ARG SEMVER=unspecified
LABEL semver=${SEMVER}
# git repo built from
ARG GIT_REPO=unspecified
LABEL git_repo=${GIT_REPO}
# git branch built from
ARG GIT_BRANCH=unspecified
LABEL git_branch=${GIT_BRANCH}
# git commit id
ARG GIT_COMMIT=unspecified
LABEL git_commit=${GIT_COMMIT}
# short description of any changes present in git repo clone - helps us ensure pipeline builds are not dirty and gives some traceability in local builds
ARG GIT_STATUS=unspecified
LABEL git_status=${GIT_STATUS}

RUN apt-get update && apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  --no-install-recommends \
  && curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
  && apt-get update \
  && apt-get install -y \
  google-chrome-stable \
  fonts-ipafont-gothic \
  fonts-wqy-zenhei \
  fonts-thai-tlwg \
  fonts-kacst \
  ttf-freefont \
  dumb-init \
  git \
  jq \
  --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get purge --auto-remove -y curl \
  && rm -rf /src/*.deb

# below is copied from https://github.com/docker-library/golang/blob/ee2d52a7ad3e077af02313cd4cd87fd39837412c/1.14/stretch/Dockerfile
# only change is to set WORKDIR to $GOPATH

# gcc for cgo
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    gcc \
    libc6-dev \
    make \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

ENV PATH /usr/local/go/bin:$PATH

ENV GOLANG_VERSION 1.14.9

RUN set -eux; \
    \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
		'amd64') \
			arch='linux-amd64'; \
			url='https://storage.googleapis.com/golang/go1.14.9.linux-amd64.tar.gz'; \
			sha256='f0d26ff572c72c9823ae752d3c81819a81a60c753201f51f89637482531c110a'; \
			;; \
		'armhf') \
			arch='linux-armv6l'; \
			url='https://storage.googleapis.com/golang/go1.14.9.linux-armv6l.tar.gz'; \
			sha256='e85dc09608dc9fc245ebc5daea0826898ac0eb0d48ed24e2300427850876c442'; \
			;; \
		'arm64') \
			arch='linux-arm64'; \
			url='https://storage.googleapis.com/golang/go1.14.9.linux-arm64.tar.gz'; \
			sha256='65e6cef5c474a3514e754f6a7987c49388bb85a7b370370c1318087ac35427fa'; \
			;; \
		'i386') \
			arch='linux-386'; \
			url='https://storage.googleapis.com/golang/go1.14.9.linux-386.tar.gz'; \
			sha256='14982ef997ec323023a11cffe1a4afc3aacd1b5edebf70a00e17b67f888d8cdb'; \
			;; \
		'ppc64el') \
			arch='linux-ppc64le'; \
			url='https://storage.googleapis.com/golang/go1.14.9.linux-ppc64le.tar.gz'; \
			sha256='5880a37faf93b2396edc3ff231e0f8df14d0520505cc13d01116e24d7d1d0147'; \
			;; \
		's390x') \
			arch='linux-s390x'; \
			url='https://storage.googleapis.com/golang/go1.14.9.linux-s390x.tar.gz'; \
			sha256='381fc24aff153c4affcb00f4547683212157af29b8f9e3de5952d78ac35f5a0f'; \
			;; \
		*) \
# https://github.com/golang/go/issues/38536#issuecomment-616897960
			arch='src'; \
			url='https://storage.googleapis.com/golang/go1.14.9.src.tar.gz'; \
			sha256='c687c848cc09bcabf2b5e534c3fc4259abebbfc9014dd05a1a2dc6106f404554'; \
			echo >&2; \
			echo >&2 "warning: current architecture ($dpkgArch) does not have a corresponding Go binary release; will be building from source"; \
			echo >&2; \
			;; \
    esac; \
    \
	wget -O go.tgz.asc "$url.asc" --progress=dot:giga; \
	wget -O go.tgz "$url" --progress=dot:giga; \
	echo "$sha256 *go.tgz" | sha256sum --strict --check -; \
	\
# https://github.com/golang/go/issues/14739#issuecomment-324767697
	export GNUPGHOME="$(mktemp -d)"; \
# https://www.google.com/linuxrepositories/
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys 'EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796'; \
	gpg --batch --verify go.tgz.asc go.tgz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" go.tgz.asc; \
	\
    tar -C /usr/local -xzf go.tgz; \
    rm go.tgz; \
    \
	if [ "$arch" = 'src' ]; then \
		savedAptMark="$(apt-mark showmanual)"; \
		apt-get update; \
		apt-get install -y --no-install-recommends golang-go; \
		\
		goEnv="$(go env | sed -rn -e '/^GO(OS|ARCH|ARM|386)=/s//export \0/p')"; \
		eval "$goEnv"; \
		[ -n "$GOOS" ]; \
		[ -n "$GOARCH" ]; \
		( \
			cd /usr/local/go/src; \
			./make.bash; \
		); \
		\
		apt-mark auto '.*' > /dev/null; \
		apt-mark manual $savedAptMark > /dev/null; \
		apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
		rm -rf /var/lib/apt/lists/*; \
		\
# pre-compile the standard library, just like the official binary release tarballs do
		go install std; \
# go install: -race is only supported on linux/amd64, linux/ppc64le, linux/arm64, freebsd/amd64, netbsd/amd64, darwin/amd64 and windows/amd64
#		go install -race std; \
		\
# remove a few intermediate / bootstrapping files the official binary release tarballs do not contain
		rm -rf \
			/usr/local/go/pkg/*/cmd \
			/usr/local/go/pkg/bootstrap \
			/usr/local/go/pkg/obj \
			/usr/local/go/pkg/tool/*/api \
			/usr/local/go/pkg/tool/*/go_bootstrap \
			/usr/local/go/src/cmd/dist/dist \
		; \
    fi; \
    \
    go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# add yq using the go tools
RUN go get -u github.com/mikefarah/yq

# add ginkgo & gomega
RUN go get -u github.com/onsi/ginkgo/ginkgo && go get -u github.com/onsi/gomega

WORKDIR /opt/github/lukesiler/contapp

# NOTE: create "Container App" group and user - include audio & video group membership as required for chrome.  Without this, chrome will complain about being run as root.
RUN groupadd -r contappg \
  && useradd -r -g contappg -G audio,video contappu \
  && mkdir -p /home/contappu/Downloads \
  && chown -R contappu:contappg /home/contappu \
  && chown -R contappu:contappg /usr/local/bin \
  && chown -R contappu:contappg /opt/github/lukesiler/contapp \
  && chown -R contappu:contappg /usr/local/lib/node_modules

USER contappu
