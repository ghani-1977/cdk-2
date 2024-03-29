#
# Makefile to build NEUTRINO
#
$(targetprefix)/var/etc/.version:
	echo "imagename=Neutrino" > $@
	echo "homepage=http://gitorious.org/open-duckbox-project-sh4" >> $@
	echo "creator=`id -un`" >> $@
	echo "docs=http://gitorious.org/open-duckbox-project-sh4/pages/Home" >> $@
	echo "forum=http://gitorious.org/open-duckbox-project-sh4" >> $@
	echo "version=0200`date +%Y%m%d%H%M`" >> $@
	echo "git=`git describe`" >> $@

NEUTRINO_DEPS  = bootstrap libcurl libpng libjpeg libgif libfreetype
NEUTRINO_DEPS += ffmpeg lua luaexpat luacurl libdvbsipp libsigc libopenthreads libusb libalsa
NEUTRINO_DEPS += $(EXTERNALLCD_DEP)

if ENABLE_WLANDRIVER
NEUTRINO_DEPS += wpa_supplicant wireless_tools
endif

NEUTRINO_DEPS2 = libid3tag libmad libvorbisidec

N_CFLAGS  = -Wall -W -Wshadow -g0 -pipe -Os -fno-strict-aliasing -DCPU_FREQ -ffunction-sections -fdata-sections

N_CPPFLAGS = -I$(driverdir)/bpamem
N_CPPFLAGS += -I$(targetprefix)/usr/include/
N_CPPFLAGS += -I$(buildprefix)/$(KERNEL_DIR)/include
N_CPPFLAGS += -D__STDC_CONSTANT_MACROS

if BOXTYPE_SPARK
N_CPPFLAGS += -I$(driverdir)/frontcontroller/aotom_spark
endif

if BOXTYPE_SPARK7162
N_CPPFLAGS += -I$(driverdir)/frontcontroller/aotom_spark
endif

N_CONFIG_OPTS = --enable-silent-rules --enable-freesatepg
# --enable-pip

if ENABLE_EXTERNALLCD
N_CONFIG_OPTS += --enable-graphlcd
endif

if ENABLE_MEDIAFWGSTREAMER
N_CONFIG_OPTS += --enable-gstreamer
else
N_CONFIG_OPTS += --enable-libeplayer3
endif

OBJDIR = $(buildtmp)
N_OBJDIR = $(OBJDIR)/neutrino-mp
LH_OBJDIR = $(OBJDIR)/libstb-hal

################################################################################
#
# fs-basis - libstb-hal-cst-next
#
LIBSTB_HAL_CST_NEXT_PATCHES =

$(D)/libstb-hal-cst-next.do_prepare:
	rm -rf $(sourcedir)/libstb-hal-cst-next
	rm -rf $(sourcedir)/libstb-hal-cst-next.org
	rm -rf $(LH_OBJDIR)
	[ -d "$(archivedir)/libstb-hal-cst-next.git" ] && \
	(cd $(archivedir)/libstb-hal-cst-next.git; git pull; cd "$(buildprefix)";); \
	[ -d "$(archivedir)/libstb-hal-cst-next.git" ] || \
	git clone https://github.com/fs-basis/libstb-hal-cst-next.git $(archivedir)/libstb-hal-cst-next.git; \
	cp -ra $(archivedir)/libstb-hal-cst-next.git $(sourcedir)/libstb-hal-cst-next;\
	cp -ra $(sourcedir)/libstb-hal-cst-next $(sourcedir)/libstb-hal-cst-next.org
	for i in $(LIBSTB_HAL_CST_NEXT_PATCHES); do \
		echo "==> Applying Patch: $(subst $(PATCHES)/,'',$$i)"; \
		set -e; cd $(sourcedir)/libstb-hal-cst-next && patch -p1 -i $$i; \
	done;
	touch $@

$(D)/libstb-hal-cst-next.config.status: | $(NEUTRINO_DEPS)
	rm -rf $(LH_OBJDIR) && \
	test -d $(LH_OBJDIR) || mkdir -p $(LH_OBJDIR) && \
	cd $(LH_OBJDIR) && \
		$(sourcedir)/libstb-hal-cst-next/autogen.sh && \
		$(BUILDENV) \
		$(sourcedir)/libstb-hal-cst-next/configure \
			--host=$(target) \
			--build=$(build) \
			--prefix= \
			--with-target=cdk \
			--with-boxtype=$(BOXTYPE) \
			PKG_CONFIG=$(hostprefix)/bin/$(target)-pkg-config \
			PKG_CONFIG_PATH=$(targetprefix)/usr/lib/pkgconfig \
			CFLAGS="$(N_CFLAGS)" CXXFLAGS="$(N_CFLAGS)" CPPFLAGS="$(N_CPPFLAGS)"

$(D)/libstb-hal-cst-next.do_compile: libstb-hal-cst-next.config.status
	cd $(sourcedir)/libstb-hal-cst-next && \
		$(MAKE) -C $(LH_OBJDIR)
	touch $@

$(D)/libstb-hal-cst-next: libstb-hal-cst-next.do_prepare libstb-hal-cst-next.do_compile
	$(MAKE) -C $(LH_OBJDIR) install DESTDIR=$(targetprefix)
	touch $@

libstb-hal-cst-next-clean:
	rm -f $(D)/libstb-hal-cst-next
	cd $(LH_OBJDIR) && \
		$(MAKE) -C $(LH_OBJDIR) distclean

libstb-hal-cst-next-distclean:
	rm -rf $(LH_OBJDIR)
	rm -f $(D)/libstb-hal-cst-next*

################################################################################
#
# yaud-neutrino-mp-cst-next
#
yaud-neutrino-mp-cst-next: yaud-none lirc \
		boot-elf neutrino-mp-cst-next release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

yaud-neutrino-mp-cst-next-plugins: yaud-none lirc \
		boot-elf neutrino-mp-cst-next neutrino-mp-plugins release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

yaud-neutrino-mp-cst-next-xupnpd: yaud-none lirc \
		boot-elf neutrino-mp-cst-next xupnpd release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

#
# fs-basis neutrino-mp-cst-next
#
NEUTRINO_MP_CST_NEXT_PATCHES =

$(D)/neutrino-mp-cst-next.do_prepare: | $(NEUTRINO_DEPS) libstb-hal-cst-next
	rm -rf $(sourcedir)/neutrino-mp-cst-next
	rm -rf $(sourcedir)/neutrino-mp-cst-next.org
	rm -rf $(N_OBJDIR)
	[ -d "$(archivedir)/neutrino-mp-cst-next.git" ] && \
	(cd $(archivedir)/neutrino-mp-cst-next.git; git pull; cd "$(buildprefix)";); \
	[ -d "$(archivedir)/neutrino-mp-cst-next.git" ] || \
	git clone https://github.com/fs-basis/neutrino-mp-cst-next.git $(archivedir)/neutrino-mp-cst-next.git; \
	cp -ra $(archivedir)/neutrino-mp-cst-next.git $(sourcedir)/neutrino-mp-cst-next; \
	cp -ra $(sourcedir)/neutrino-mp-cst-next $(sourcedir)/neutrino-mp-cst-next.org
	for i in $(NEUTRINO_MP_CST_NEXT_PATCHES); do \
		echo "==> Applying Patch: $(subst $(PATCHES)/,'',$$i)"; \
		set -e; cd $(sourcedir)/neutrino-mp-cst-next && patch -p1 -i $$i; \
	done;
	touch $@

$(D)/neutrino-mp-cst-next.config.status:
	rm -rf $(N_OBJDIR)
	test -d $(N_OBJDIR) || mkdir -p $(N_OBJDIR) && \
	cd $(N_OBJDIR) && \
		$(sourcedir)/neutrino-mp-cst-next/autogen.sh && \
		$(BUILDENV) \
		$(sourcedir)/neutrino-mp-cst-next/configure \
			--build=$(build) \
			--host=$(target) \
			$(N_CONFIG_OPTS) \
			--with-boxtype=$(BOXTYPE) \
			--disable-upnp \
			--disable-fastscan \
			--enable-ffmpegdec \
			--enable-giflib \
			--enable-lua \
			--with-tremor \
			--with-libdir=/usr/lib \
			--with-datadir=/usr/share/tuxbox \
			--with-fontdir=/usr/share/fonts \
			--with-configdir=/var/tuxbox/config \
			--with-gamesdir=/var/tuxbox/games \
			--with-plugindir=/var/tuxbox/plugins \
			--with-iconsdir=/usr/share/tuxbox/neutrino/icons \
			--with-localedir=/usr/share/tuxbox/neutrino/locale \
			--with-private_httpddir=/usr/share/tuxbox/neutrino/httpd \
			--with-themesdir=/usr/share/tuxbox/neutrino/themes \
			--with-stb-hal-includes=$(sourcedir)/libstb-hal-cst-next/include \
			--with-stb-hal-build=$(LH_OBJDIR) \
			PKG_CONFIG=$(hostprefix)/bin/$(target)-pkg-config \
			PKG_CONFIG_PATH=$(targetprefix)/usr/lib/pkgconfig \
			CFLAGS="$(N_CFLAGS)" CXXFLAGS="$(N_CFLAGS)" CPPFLAGS="$(N_CPPFLAGS)"

$(sourcedir)/neutrino-mp-cst-next/src/gui/version.h:
	@rm -f $@; \
	echo '#define BUILT_DATE "'`date`'"' > $@
	@if test -d $(sourcedir)/libstb-hal-cst-next ; then \
		pushd $(sourcedir)/libstb-hal-cst-next ; \
		HAL_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		pushd $(sourcedir)/neutrino-mp-cst-next ; \
		NMP_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		pushd $(buildprefix) ; \
		DDT_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		echo '#define VCS "FS_CDK-rev'$$DDT_REV'_HAL-rev'$$HAL_REV'_FS-neutrino-mp-cst-next-rev'$$NMP_REV'"' >> $@ ; \
	fi

$(D)/neutrino-mp-cst-next.do_compile: neutrino-mp-cst-next.config.status $(sourcedir)/neutrino-mp-cst-next/src/gui/version.h
	cd $(sourcedir)/neutrino-mp-cst-next && \
		$(MAKE) -C $(N_OBJDIR) all
	touch $@

$(D)/neutrino-mp-cst-next: neutrino-mp-cst-next.do_prepare neutrino-mp-cst-next.do_compile
	$(MAKE) -C $(N_OBJDIR) install DESTDIR=$(targetprefix) && \
	rm -f $(targetprefix)/var/etc/.version
	make $(targetprefix)/var/etc/.version
	$(target)-strip $(targetprefix)/usr/local/bin/neutrino
	$(target)-strip $(targetprefix)/usr/local/bin/pzapit
	$(target)-strip $(targetprefix)/usr/local/bin/sectionsdcontrol
	$(target)-strip $(targetprefix)/usr/local/sbin/udpstreampes
	touch $@

neutrino-mp-cst-next-clean:
	rm -f $(D)/neutrino-mp-cst-next
	rm -f $(sourcedir)/neutrino-mp-cst-next/src/gui/version.h
	cd $(N_OBJDIR) && \
		$(MAKE) -C $(N_OBJDIR) distclean

neutrino-mp-cst-next-distclean:
	rm -rf $(N_OBJDIR)
	rm -f $(D)/neutrino-mp-cst-next*

################################################################################
#
# fs-basis yaud-neutrino-alpha
#
yaud-neutrino-alpha: yaud-none lirc \
		boot-elf neutrino-alpha release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

yaud-neutrino-alpha-plugins: yaud-none lirc \
		boot-elf neutrino-alpha neutrino-mp-plugins release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

yaud-neutrino-alpha-xupnpd: yaud-none lirc \
		boot-elf neutrino-alpha xupnpd release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

#
# fs-basis neutrino-alpha
#
FS_NEUTRINO_ALPHA_PATCHES =

$(D)/neutrino-alpha.do_prepare: | $(NEUTRINO_DEPS) libstb-hal-cst-next
	rm -rf $(sourcedir)/neutrino-alpha
	rm -rf $(sourcedir)/neutrino-alpha.org
	rm -rf $(N_OBJDIR)
	[ -d "$(archivedir)/neutrino-alpha.git" ] && \
	(cd $(archivedir)/neutrino-alpha.git; git pull; cd "$(buildprefix)";); \
	[ -d "$(archivedir)/neutrino-alpha.git" ] || \
	git clone -b alpha https://github.com/fs-basis/neutrino-mp-cst-next.git $(archivedir)/neutrino-alpha.git; \
	cp -ra $(archivedir)/neutrino-alpha.git $(sourcedir)/neutrino-alpha; \
	cp -ra $(sourcedir)/neutrino-alpha $(sourcedir)/neutrino-alpha.org
	for i in $(FS_NEUTRINO_ALPHA_PATCHES); do \
		echo "==> Applying Patch: $(subst $(PATCHES)/,'',$$i)"; \
		set -e; cd $(sourcedir)/neutrino-alpha && patch -p1 -i $$i; \
	done;
	touch $@

$(D)/neutrino-alpha.config.status:
	rm -rf $(N_OBJDIR)
	test -d $(N_OBJDIR) || mkdir -p $(N_OBJDIR) && \
	cd $(N_OBJDIR) && \
		$(sourcedir)/neutrino-alpha/autogen.sh && \
		$(BUILDENV) \
		$(sourcedir)/neutrino-alpha/configure \
			--build=$(build) \
			--host=$(target) \
			$(N_CONFIG_OPTS) \
			--with-boxtype=$(BOXTYPE) \
			--disable-upnp \
			--disable-fastscan \
			--enable-ffmpegdec \
			--enable-giflib \
			--enable-lua \
			--with-tremor \
			--with-libdir=/usr/lib \
			--with-datadir=/usr/share/tuxbox \
			--with-fontdir=/usr/share/fonts \
			--with-configdir=/var/tuxbox/config \
			--with-gamesdir=/var/tuxbox/games \
			--with-plugindir=/var/tuxbox/plugins \
			--with-iconsdir=/usr/share/tuxbox/neutrino/icons \
			--with-localedir=/usr/share/tuxbox/neutrino/locale \
			--with-private_httpddir=/usr/share/tuxbox/neutrino/httpd \
			--with-themesdir=/usr/share/tuxbox/neutrino/themes \
			--with-stb-hal-includes=$(sourcedir)/libstb-hal-cst-next/include \
			--with-stb-hal-build=$(LH_OBJDIR) \
			PKG_CONFIG=$(hostprefix)/bin/$(target)-pkg-config \
			PKG_CONFIG_PATH=$(targetprefix)/usr/lib/pkgconfig \
			CFLAGS="$(N_CFLAGS)" CXXFLAGS="$(N_CFLAGS)" CPPFLAGS="$(N_CPPFLAGS)"

$(sourcedir)/neutrino-alpha/src/gui/version.h:
	@rm -f $@; \
	echo '#define BUILT_DATE "'`date`'"' > $@
	@if test -d $(sourcedir)/libstb-hal-cst-next ; then \
		pushd $(sourcedir)/libstb-hal-cst-next ; \
		HAL_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		pushd $(sourcedir)/neutrino-alpha ; \
		NMP_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		pushd $(buildprefix) ; \
		DDT_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		echo '#define VCS "FS_CDK-rev'$$DDT_REV'_HAL-rev'$$HAL_REV'_FS-Neutrino-alpha-rev'$$NMP_REV'"' >> $@ ; \
	fi

$(D)/neutrino-alpha.do_compile: neutrino-alpha.config.status $(sourcedir)/neutrino-alpha/src/gui/version.h
	cd $(sourcedir)/neutrino-alpha && \
		$(MAKE) -C $(N_OBJDIR) all
	touch $@

$(D)/neutrino-alpha: neutrino-alpha.do_prepare neutrino-alpha.do_compile
	$(MAKE) -C $(N_OBJDIR) install DESTDIR=$(targetprefix) && \
	rm -f $(targetprefix)/var/etc/.version
	make $(targetprefix)/var/etc/.version
	$(target)-strip $(targetprefix)/usr/local/bin/neutrino
	$(target)-strip $(targetprefix)/usr/local/bin/pzapit
	$(target)-strip $(targetprefix)/usr/local/bin/sectionsdcontrol
	$(target)-strip $(targetprefix)/usr/local/sbin/udpstreampes
	touch $@

neutrino-alpha-clean:
	rm -f $(D)/neutrino-alpha
	rm -f $(sourcedir)/neutrino-alpha/src/gui/version.h
	cd $(N_OBJDIR) && \
		$(MAKE) -C $(N_OBJDIR) distclean

neutrino-alpha-distclean:
	rm -rf $(N_OBJDIR)
	rm -f $(D)/neutrino-alpha*

################################################################################
#
# fs-basis yaud-neutrino-old
#
yaud-neutrino-old: yaud-none lirc \
		boot-elf neutrino-old release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

yaud-neutrino-old-plugins: yaud-none lirc \
		boot-elf neutrino-old neutrino-mp-plugins release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

yaud-neutrino-old-xupnpd: yaud-none lirc \
		boot-elf neutrino-old xupnpd release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

#
# fs-basis neutrino-old
#
FS_NEUTRINO_OLD_PATCHES =

$(D)/neutrino-old.do_prepare: | $(NEUTRINO_DEPS) libstb-hal-cst-next
	rm -rf $(sourcedir)/neutrino-old
	rm -rf $(sourcedir)/neutrino-old.org
	rm -rf $(N_OBJDIR)
	[ -d "$(archivedir)/neutrino-old.git" ] && \
	(cd $(archivedir)/neutrino-old.git; git pull; cd "$(buildprefix)";); \
	[ -d "$(archivedir)/neutrino-old.git" ] || \
	git clone -b old https://github.com/fs-basis/neutrino-mp-cst-next.git $(archivedir)/neutrino-old.git; \
	cp -ra $(archivedir)/neutrino-old.git $(sourcedir)/neutrino-old; \
	cp -ra $(sourcedir)/neutrino-old $(sourcedir)/neutrino-old.org
	for i in $(FS_NEUTRINO_OLD_PATCHES); do \
		echo "==> Applying Patch: $(subst $(PATCHES)/,'',$$i)"; \
		set -e; cd $(sourcedir)/neutrino-old && patch -p1 -i $$i; \
	done;
	touch $@

$(D)/neutrino-old.config.status:
	rm -rf $(N_OBJDIR)
	test -d $(N_OBJDIR) || mkdir -p $(N_OBJDIR) && \
	cd $(N_OBJDIR) && \
		$(sourcedir)/neutrino-old/autogen.sh && \
		$(BUILDENV) \
		$(sourcedir)/neutrino-old/configure \
			--build=$(build) \
			--host=$(target) \
			$(N_CONFIG_OPTS) \
			--with-boxtype=$(BOXTYPE) \
			--disable-upnp \
			--disable-fastscan \
			--enable-ffmpegdec \
			--enable-giflib \
			--enable-lua \
			--with-tremor \
			--with-libdir=/usr/lib \
			--with-datadir=/usr/share/tuxbox \
			--with-fontdir=/usr/share/fonts \
			--with-configdir=/var/tuxbox/config \
			--with-gamesdir=/var/tuxbox/games \
			--with-plugindir=/var/tuxbox/plugins \
			--with-iconsdir=/usr/share/tuxbox/neutrino/icons \
			--with-localedir=/usr/share/tuxbox/neutrino/locale \
			--with-private_httpddir=/usr/share/tuxbox/neutrino/httpd \
			--with-themesdir=/usr/share/tuxbox/neutrino/themes \
			--with-stb-hal-includes=$(sourcedir)/libstb-hal-cst-next/include \
			--with-stb-hal-build=$(LH_OBJDIR) \
			PKG_CONFIG=$(hostprefix)/bin/$(target)-pkg-config \
			PKG_CONFIG_PATH=$(targetprefix)/usr/lib/pkgconfig \
			CFLAGS="$(N_CFLAGS)" CXXFLAGS="$(N_CFLAGS)" CPPFLAGS="$(N_CPPFLAGS)"

$(sourcedir)/neutrino-old/src/gui/version.h:
	@rm -f $@; \
	echo '#define BUILT_DATE "'`date`'"' > $@
	@if test -d $(sourcedir)/libstb-hal-cst-next ; then \
		pushd $(sourcedir)/libstb-hal-cst-next ; \
		HAL_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		pushd $(sourcedir)/neutrino-old ; \
		NMP_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		pushd $(buildprefix) ; \
		DDT_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		echo '#define VCS "FS_CDK-rev'$$DDT_REV'_HAL-rev'$$HAL_REV'_FS-Neutrino-old-rev'$$NMP_REV'"' >> $@ ; \
	fi

$(D)/neutrino-old.do_compile: neutrino-old.config.status $(sourcedir)/neutrino-old/src/gui/version.h
	cd $(sourcedir)/neutrino-old && \
		$(MAKE) -C $(N_OBJDIR) all
	touch $@

$(D)/neutrino-old: neutrino-old.do_prepare neutrino-old.do_compile
	$(MAKE) -C $(N_OBJDIR) install DESTDIR=$(targetprefix) && \
	rm -f $(targetprefix)/var/etc/.version
	make $(targetprefix)/var/etc/.version
	$(target)-strip $(targetprefix)/usr/local/bin/neutrino
	$(target)-strip $(targetprefix)/usr/local/bin/pzapit
	$(target)-strip $(targetprefix)/usr/local/bin/sectionsdcontrol
	$(target)-strip $(targetprefix)/usr/local/sbin/udpstreampes
	touch $@

neutrino-old-clean:
	rm -f $(D)/neutrino-old
	rm -f $(sourcedir)/neutrino-old/src/gui/version.h
	cd $(N_OBJDIR) && \
		$(MAKE) -C $(N_OBJDIR) distclean

neutrino-old-distclean:
	rm -rf $(N_OBJDIR)
	rm -f $(D)/neutrino-old*

################################################################################
#
# fs-basis yaud-neutrino-test
#
yaud-neutrino-test: yaud-none lirc \
		boot-elf neutrino-test release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

yaud-neutrino-test-plugins: yaud-none lirc \
		boot-elf neutrino-test neutrino-mp-plugins release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

yaud-neutrino-test-xupnpd: yaud-none lirc \
		boot-elf neutrino-test xupnpd release_neutrino
	@TUXBOX_YAUD_CUSTOMIZE@

#
# fs-basis neutrino-test
#
FS_NEUTRINO_TEST_PATCHES =

$(D)/neutrino-test.do_prepare: | $(NEUTRINO_DEPS) libstb-hal-cst-next
	rm -rf $(sourcedir)/neutrino-test
	rm -rf $(sourcedir)/neutrino-test.org
	rm -rf $(N_OBJDIR)
	[ -d "$(archivedir)/neutrino-test.git" ] && \
	(cd $(archivedir)/neutrino-test.git; git pull; cd "$(buildprefix)";); \
	[ -d "$(archivedir)/neutrino-test.git" ] || \
	git clone -b test https://github.com/fs-basis/neutrino-mp-cst-next.git $(archivedir)/neutrino-test.git; \
	cp -ra $(archivedir)/neutrino-test.git $(sourcedir)/neutrino-test; \
	cp -ra $(sourcedir)/neutrino-test $(sourcedir)/neutrino-test.org
	for i in $(FS_NEUTRINO_TEST_PATCHES); do \
		echo "==> Applying Patch: $(subst $(PATCHES)/,'',$$i)"; \
		set -e; cd $(sourcedir)/neutrino-test && patch -p1 -i $$i; \
	done;
	touch $@

$(D)/neutrino-test.config.status:
	rm -rf $(N_OBJDIR)
	test -d $(N_OBJDIR) || mkdir -p $(N_OBJDIR) && \
	cd $(N_OBJDIR) && \
		$(sourcedir)/neutrino-test/autogen.sh && \
		$(BUILDENV) \
		$(sourcedir)/neutrino-test/configure \
			--build=$(build) \
			--host=$(target) \
			$(N_CONFIG_OPTS) \
			--with-boxtype=$(BOXTYPE) \
			--disable-upnp \
			--disable-fastscan \
			--enable-ffmpegdec \
			--enable-giflib \
			--enable-lua \
			--with-tremor \
			--with-libdir=/usr/lib \
			--with-datadir=/usr/share/tuxbox \
			--with-fontdir=/usr/share/fonts \
			--with-configdir=/var/tuxbox/config \
			--with-gamesdir=/var/tuxbox/games \
			--with-plugindir=/var/tuxbox/plugins \
			--with-iconsdir=/usr/share/tuxbox/neutrino/icons \
			--with-localedir=/usr/share/tuxbox/neutrino/locale \
			--with-private_httpddir=/usr/share/tuxbox/neutrino/httpd \
			--with-themesdir=/usr/share/tuxbox/neutrino/themes \
			--with-stb-hal-includes=$(sourcedir)/libstb-hal-cst-next/include \
			--with-stb-hal-build=$(LH_OBJDIR) \
			PKG_CONFIG=$(hostprefix)/bin/$(target)-pkg-config \
			PKG_CONFIG_PATH=$(targetprefix)/usr/lib/pkgconfig \
			CFLAGS="$(N_CFLAGS)" CXXFLAGS="$(N_CFLAGS)" CPPFLAGS="$(N_CPPFLAGS)"

$(sourcedir)/neutrino-test/src/gui/version.h:
	@rm -f $@; \
	echo '#define BUILT_DATE "'`date`'"' > $@
	@if test -d $(sourcedir)/libstb-hal-cst-next ; then \
		pushd $(sourcedir)/libstb-hal-cst-next ; \
		HAL_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		pushd $(sourcedir)/neutrino-test ; \
		NMP_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		pushd $(buildprefix) ; \
		DDT_REV=$$(git log | grep "^commit" | wc -l) ; \
		popd ; \
		echo '#define VCS "FS_CDK-rev'$$DDT_REV'_HAL-rev'$$HAL_REV'_FS-Neutrino-test-rev'$$NMP_REV'"' >> $@ ; \
	fi

$(D)/neutrino-test.do_compile: neutrino-test.config.status $(sourcedir)/neutrino-test/src/gui/version.h
	cd $(sourcedir)/neutrino-test && \
		$(MAKE) -C $(N_OBJDIR) all
	touch $@

$(D)/neutrino-test: neutrino-test.do_prepare neutrino-test.do_compile
	$(MAKE) -C $(N_OBJDIR) install DESTDIR=$(targetprefix) && \
	rm -f $(targetprefix)/var/etc/.version
	make $(targetprefix)/var/etc/.version
	$(target)-strip $(targetprefix)/usr/local/bin/neutrino
	$(target)-strip $(targetprefix)/usr/local/bin/pzapit
	$(target)-strip $(targetprefix)/usr/local/bin/sectionsdcontrol
	$(target)-strip $(targetprefix)/usr/local/sbin/udpstreampes
	touch $@

neutrino-test-clean:
	rm -f $(D)/neutrino-test
	rm -f $(sourcedir)/neutrino-test/src/gui/version.h
	cd $(N_OBJDIR) && \
		$(MAKE) -C $(N_OBJDIR) distclean

neutrino-test-distclean:
	rm -rf $(N_OBJDIR)
	rm -f $(D)/neutrino-test*

################################################################################
neutrino-cdkroot-clean:
	[ -e $(targetprefix)/usr/local/bin ] && cd $(targetprefix)/usr/local/bin && find -name '*' -delete || true
	[ -e $(targetprefix)/usr/local/share/iso-codes ] && cd $(targetprefix)/usr/local/share/iso-codes && find -name '*' -delete || true
	[ -e $(targetprefix)/usr/share/tuxbox/neutrino ] && cd $(targetprefix)/usr/share/tuxbox/neutrino && find -name '*' -delete || true
	[ -e $(targetprefix)/usr/share/fonts ] && cd $(targetprefix)/usr/share/fonts && find -name '*' -delete || true
################################################################################
