subdirs ?= all norm norm+clean expand expand+clean
TARGETS ?= $(patsubst %,%/build.stamp,$(subdirs))

all: $(TARGETS)

%/build.stamp: %/src.prl
	$(MAKE) -C $*
	touch $@

%/clean.stamp:
	-$(MAKE) -C $* clean
	rm -f $*/build.stamp

clean: $(TARGETS:build.stamp=clean.stamp)
