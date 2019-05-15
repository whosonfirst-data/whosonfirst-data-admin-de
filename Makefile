# There are only two rules:
# 1. Variables at the top of the Makefile.
# 2. Targets are listed alphabetically. No, really.

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')

WHEREAMI = $(shell pwd)
WHOAMI = $(shell basename $(WHEREAMI))
WHATAMI = $(shell echo $(WHOAMI) | awk -F '-' '{print $$3}')
WHATAMI_REALLY = $(shell basename `pwd` | sed 's/whosonfirst-data-//')

YMD = $(shell date "+%Y%m%d")

archive: meta-scrub
	tar --exclude='.git*' --exclude='Makefile*' -cvjf $(dest)/$(WHOAMI)-$(YMD).tar.bz2 ./data ./meta ./LICENSE.md ./CONTRIBUTING.md ./README.md

concordances:
ifeq ($(OS),darwin)
	utils/$(OS)/wof-build-concordances
else ifeq ($(OS),linux)
	utils/$(OS)/wof-build-concordances
else ifeq ($(OS),windows)
	utils/$(OS)/wof-build-concordances
else
	echo "this OS is not supported yet"
	exit 1
endif

count:
	find ./data -name '*.geojson' -print | wc -l

githash:
	git log --pretty=format:'%H' -n 1

gitlf:
	if ! test -f .gitattributes; then touch .gitattributes; fi
ifeq ($(shell grep '*.geojson text eol=lf' .gitattributes | wc -l), 0)
	cp .gitattributes .gitattributes.tmp
	perl -pe 'chomp if eof' .gitattributes.tmp
	echo "*.geojson text eol=lf" >> .gitattributes.tmp
	mv .gitattributes.tmp .gitattributes
else
	@echo "Git linefeed hoohah already set"
endif

# https://internetarchive.readthedocs.org/en/latest/cli.html#upload
# https://internetarchive.readthedocs.org/en/latest/quickstart.html#configuring

ia:
	ia upload $(WHOAMI)-$(YMD) $(src)/$(WHOAMI)-$(YMD).tar.bz2 --metadata="title:$(WHOAMI)-$(YMD)" --metadata="licenseurl:http://creativecommons.org/licenses/by/4.0/" --metadata="date:$(YMD)" --metadata="subject:geo;mapzen;whosonfirst" --metadata="creator:Who's On First (Mapzen)"

install-hooks:
	if test ! -f .git/hooks/post-merge; then echo "#!/bin/sh" > .git/hooks/post-merge; chmod 755 .git/hooks/post-merge; fi
ifeq ($(shell grep 'whosonfirst-data post-merge hooks' .git/hooks/post-merge | wc -l), 0)
	echo "" >> .git/hooks/post-merge
	curl -s https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/meta/git/hooks/post-merge >> .git/hooks/post-merge
else
	@echo "whosonfirst-data post-merge hooks already installed"
endif
	curl -s -o .git/hooks/post-merge-whosonfirst https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/meta/git/hooks/post-merge-whosonfirst
	chmod 755 .git/hooks/post-merge-whosonfirst

internetarchive:
	$(MAKE) dest=$(src) archive
	$(MAKE) src=$(src) ia
	rm $(src)/$(WHOAMI)-$(YMD).tar.bz2

list-empty:
	find data -type d -empty -print

metafiles:
ifeq ($(OS),darwin)
	utils/$(OS)/wof-build-metafiles
else ifeq ($(OS),linux)
	utils/$(OS)/wof-build-metafiles
else ifeq ($(OS),windows)
	utils/$(OS)/wof-build-metafiles
else
	echo "this OS is not supported yet"
	exit 1
endif

prune:
	git gc --aggressive --prune

rm-empty:
	find data -type d -empty -print -delete

scrub: rm-empty prune

update-all: update-docs update-gitignore update-makefile

update-docs:
	curl -s -o LICENSE.md https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/master/docs/LICENSE-SHORT.md
	curl -s -o CONTRIBUTING.md https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/master/docs/CONTRIBUTING.md

update-gitignore:
	curl -s -o .gitignore https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/master/git/dot-gitignore
	curl -s -o meta/.gitignore https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/master/git/dot-gitignore-meta

update-makefile:
	curl -s -o Makefile https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/master/make/Makefile
ifeq ($(shell echo $(WHATAMI) | wc -l), 1)
	if test -f $(WHEREAMI)/Makefile.$(WHATAMI);then  echo "\n# appending Makefile.$(WHATAMI)\n\n" >> Makefile; cat $(WHEREAMI)/Makefile.$(WHATAMI) >> Makefile; fi
	if test -f $(WHEREAMI)/Makefile.$(WHATAMI).local;then  echo "\n# appending Makefile.$(WHATAMI).local\n\n" >> Makefile; cat $(WHEREAMI)/Makefile.$(WHATAMI).local >> Makefile; fi
endif
	if test -f $(WHEREAMI)/Makefile.local; then echo "\n# appending Makefile.local\n\n" >> Makefile; cat $(WHEREAMI)/Makefile.local >> Makefile; fi

update-meta:
	if test ! -d meta; then mkdir meta; fi
	rm -f meta/*.csv
	curl -s -o meta/README.md https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/master/meta/README.md
	curl -s -o meta/.gitignore https://raw.githubusercontent.com/whosonfirst/whosonfirst-data-utils/master/git/dot-gitignore-meta

update-utils:
	make utils-fetch TARGET=darwin
	make utils-verify TARGET=darwin
	make utils-fetch TARGET=linux
	make utils-verify TARGET=linux
	make utils-fetch TARGET=windows
	@echo "Skipping the SHA-256 verification, because Windows"

utils-fetch:
	mkdir -p utils/$(TARGET)
	cd utils/$(TARGET) && curl -s -O https://raw.githubusercontent.com/whosonfirst/go-whosonfirst-meta/master/dist/$(TARGET)/wof-build-metafiles
	cd utils/$(TARGET) && curl -s -O https://raw.githubusercontent.com/whosonfirst/go-whosonfirst-meta/master/dist/$(TARGET)/wof-build-metafiles.sha256
	cd utils/$(TARGET) && curl -s -O https://raw.githubusercontent.com/whosonfirst/go-whosonfirst-concordances/master/dist/$(TARGET)/wof-build-concordances
	cd utils/$(TARGET) && curl -s -O https://raw.githubusercontent.com/whosonfirst/go-whosonfirst-concordances/master/dist/$(TARGET)/wof-build-concordances.sha256

utils-verify:
	cd utils/$(TARGET) && shasum -a 256 -c wof-build-metafiles.sha256
	cd utils/$(TARGET) && shasum -a 256 -c wof-build-concordances.sha256
	chmod +x utils/$(TARGET)/wof-build-metafiles
	chmod +x utils/$(TARGET)/wof-build-concordances
	rm utils/$(TARGET)/wof-build-metafiles.sha256
	rm utils/$(TARGET)/wof-build-concordances.sha256

