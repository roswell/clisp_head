-include .env
export $(shell sed 's/=.*//' .env)

VERSION ?= $(shell date +%y.%-m.%-d)
ORIGIN_URI=https://github.com/roswell/clisp
ORIGIN_REF=master
GITHUB=https://github.com/roswell/clisp_head
TSV_FILE ?= clisp-bin_uri.tsv

SIGSEGV_VERSION ?= 2.14
FFCALL_VERSION ?= 2.5
RELEASE_DATE ?= $(shell date +%F)

OS ?= $(shell ros roswell-internal-use uname)
CPU ?= $(shell ros roswell-internal-use uname -m)
VARIANT ?=
CLISP_LDFLAGS ?=
DOCKER_REPO ?= docker.pkg.github.com/roswell/clisp_bin
DOCKER_PLATFORM ?= linux/amd64
DOCKER_ACTION ?= docker-default-action

PACK=clisp-$(VERSION)-$(CPU)-$(OS)$(VARIANT)
LAST_VERSION=$(shell ros web.ros version)

hash:
	git ls-remote --heads $(ORIGIN_URI) $(ORIGIN_REF) |sed -E "s/^([0-9a-fA-F]*).*/\1/" > hash

lasthash: web.ros
	curl -sfSL -o lasthash $(GITHUB)/releases/download/files/hash || touch lasthash

latest-version: lasthash version
	$(eval VERSION := $(shell cat version))
	$(eval HASH := $(shell cat lasthash))
	@echo "set version $(VERSION):$(HASH)"

download: lasthash libsigsegv-$(SIGSEGV_VERSION).tar.gz libffcall-$(FFCALL_VERSION).tar.gz

tag: hash web.ros
	($(MAKE) lasthash  && diff -u hash lasthash) || \
	( VERSION=$(VERSION) ros web.ros upload-hash; \
	  VERSION=$(VERSION) ros web.ros upload-hash; \
	  VERSION=files ros web.ros upload-hash)

tsv: web.ros
	TSV_FILE=$(TSV_FILE) ros web.ros tsv

upload-tsv: web.ros
	TSV_FILE=$(TSV_FILE) VERSION=$(VERSION) ros web.ros upload-tsv

download-tsv:
	TSV_FILE=$(TSV_FILE) VERSION=$(VERSION) ros web.ros get-tsv

version: web.ros
	@echo $(LAST_VERSION) > version

web.ros:
	curl -L -O https://raw.githubusercontent.com/roswell/sbcl_bin/master/web.ros

show:
	@echo PACK=$(PACK) CC=$(CC)

libsigsegv-$(SIGSEGV_VERSION).tar.gz:
	curl -O https://ftp.gnu.org/gnu/libsigsegv/libsigsegv-$(SIGSEGV_VERSION).tar.gz

sigsegv: libsigsegv-$(SIGSEGV_VERSION).tar.gz
	tar xfz libsigsegv-$(SIGSEGV_VERSION).tar.gz
	cd libsigsegv-$(SIGSEGV_VERSION);CC='$(CC)' ./configure --prefix=`pwd`/../sigsegv;make;make check;make install
	rm -rf libsigsegv-$(SIGSEGV_VERSION)

libffcall-$(FFCALL_VERSION).tar.gz:
	curl -O https://ftp.gnu.org/gnu/libffcall/libffcall-$(FFCALL_VERSION).tar.gz

ffcall: libffcall-$(FFCALL_VERSION).tar.gz
	tar xfz libffcall-$(FFCALL_VERSION).tar.gz
	cd libffcall-$(FFCALL_VERSION);CC='$(CC)' ./configure --prefix=`pwd`/../ffcall --disable-shared;make;make check;make install
	rm -rf libffcall-$(FFCALL_VERSION)

clisp: download lasthash
	git clone --depth 100 $(ORIGIN_URI) || true
	cd clisp;git checkout `cat ../lasthash`
	cd clisp; \
	git init; \
	git remote add origin $(ORIGIN_URI); \
	git fetch --depth=1 origin $(shell cat lasthash); \
	git reset --hard FETCH_HEAD

clisp/version.sh: clisp
	echo VERSION_NUMBER=$(VERSION) > clisp/version.sh
	echo RELEASE_DATE=$(RELEASE_DATE) >> clisp/version.sh
	cd clisp/src; \
		autoconf; \
		autoheader

compile: show sigsegv ffcall clisp
	rm -f clisp/version.sh; $(MAKE) clisp/version.sh
	cd clisp; \
	CC='$(CC)' \
	LDFLAGS='$(CLISP_LDFLAGS)' \
	FORCE_UNSAFE_CONFIGURE=1 \
	./configure \
		--with-libsigsegv-prefix=`pwd`/../sigsegv \
		--with-libffcall-prefix=`pwd`/../ffcall \
		--prefix=`pwd`/../$(PACK)
	cd clisp/src; \
	make; \
	make install

archive: show
	tar cjvf $(PACK)-binary.tar.bz2 $(PACK)
	bash -c "cd clisp/src;make distrib;mv clisp-*.gz ../.."
	mv clisp-*.gz $(PACK)-distribute.tar.gz

upload-archive-p:
	curl -I -f https://github.com/roswell/clisp_head/releases/download/$(VERSION)/$(PACK)-binary.tar.bz2 > /dev/null

upload-archive: show
	VERSION=$(VERSION) TARGET=$(ARCH) SUFFIX=$(SUFFIX) ros web.ros upload-archive

debug-docker:
	docker run \
		--rm \
		-it \
		--platform $(DOCKER_PLATFORM) \
		-v `pwd`:/tmp \
		$(DOCKER_REPO)/$$(cat ./tools-for-build/$(IMAGE)/Name)$(DOCKER_IMAGE_SUFFIX) \
		bash

build-docker:
	docker build --platform $(DOCKER_PLATFORM) -t $(DOCKER_REPO)/$$(cat ./tools-for-build/$(IMAGE)/Name)$(DOCKER_IMAGE_SUFFIX) $(DOCKER_BUILD_OPTIONS) ./tools-for-build/$(IMAGE)
push-docker:
	docker push $(DOCKER_REPO)/$$(cat ./tools-for-build/$(IMAGE)/Name)$(DOCKER_IMAGE_SUFFIX);
pull-docker:
	docker pull $(DOCKER_REPO)/$$(cat ./tools-for-build/$(IMAGE)/Name)$(DOCKER_IMAGE_SUFFIX);

pull-docker-old:
	docker pull $(DOCKER_REPO)/$(IMAGE);

docker:
	docker run \
		--rm \
		--platform $(DOCKER_PLATFORM) \
		-v `pwd`:/tmp \
		-e VERSION=$(VERSION) \
		-e CPU=$(CPU) \
		-e OS=$(OS) \
		-e CC='$(CC)' \
		-e CLISP_LDFLAGS='$(CLISP_LDFLAGS)' \
		-e VARIANT=$(VARIANT) \
		-e CFLAGS=$(CFLAGS) \
		-e LINKFLAGS=$(LINKFLAGS) \
		$(DOCKER_REPO)/$$(cat ./tools-for-build/$(IMAGE)/Name)$(DOCKER_IMAGE_SUFFIX) \
		bash \
		-c "cd /tmp;bash ./tools-for-build/$(IMAGE)/setup;make $(DOCKER_ACTION)"

docker-default-action: compile archive

clean:
	rm -rf sigsegv ffcall clisp
	rm -f lib*.gz
	rm -rf $(PACK)
	rm -f hash lasthash version
	#rm -f clisp*.tar.bz2

table: web.ros
	ros web.ros table
