# Makefile for build Codestriker distribution.

# Path to utilities.
RM = /bin/rm
CP = /bin/cp
MKDIR = /bin/mkdir
RSYNC = rsync
ZIP = zip
TAR = /bin/tar

# Retrieve the current Codestriker version.
VERSION := $(shell cat lib/Codestriker.pm | perl -ne 'print $$1 if /Codestriker::VERSION\s*=\s*\"(.*)\"/')

# The build directory.
BUILD_DIR = build/codestriker-$(VERSION)

default: build-zip build-tar-gz

build-zip: build
	cd build ; \
	$(ZIP) -r -l codestriker-$(VERSION).zip codestriker-$(VERSION) -x *.png -x *.pdf ; \
	$(ZIP) -r codestriker-$(VERSION).zip codestriker-$(VERSION) -i *.pdf -i *.png

build-tar-gz: build
	cd build ; \
	$(TAR) zcvf codestriker-$(VERSION).tar.gz codestriker-$(VERSION)

build: build-docs
	$(RM) -fr $(BUILD_DIR)
	$(MKDIR) -p $(BUILD_DIR)
	$(RSYNC) -Cavz bin/ $(BUILD_DIR)/bin/ 
	$(RSYNC) -Cavz lib/ $(BUILD_DIR)/lib/ 
	$(RSYNC) -Cavz html/ $(BUILD_DIR)/html/ 
	$(RSYNC) -Cavz cgi-bin/ $(BUILD_DIR)/cgi-bin/ 
	$(RSYNC) -Cavz template/ $(BUILD_DIR)/template
	$(CP) codestriker.conf README CHANGELOG HACKING LICENSE $(BUILD_DIR)

build-docs:
	cd doc ; $(MAKE)

clean:
	cd doc ; $(MAKE) clean
	$(RM) -fr build
	$(RM) -f html/*.html html/*.pdf html/*.rtf html/*.png
