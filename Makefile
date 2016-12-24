build:
	snapcraft
test-ci:
	@echo "Soon..."
test-local:
	snapcraft clean steam launcher
	FORCE_X=1 snapcraft
	snap install --force-dangerous --devmode *.snap
	/snap/bin/steam
iso-build:
	rm -rf parts/steam/
	mkdir -p parts/steam/install
	mkdir -p parts/steam/state
	touch parts/steam/state/build
	touch parts/steam/state/pull
	cp -rvp src parts/steam/build
	cp -rvp src parts/steam/src
	make -C parts/steam/build FORCE_X=1
	make -C parts/steam/build install DESTDIR=$(PWD)/parts/steam/install
iso-test: iso-build
	cp -rvp launcher/launcher.sh $(PWD)/parts/steam/install
	mkdir -p $(PWD)/parts/steam/x1
	mkdir -p $(PWD)/parts/steam/common
	@echo
	@echo
	@echo
	@echo
	@echo
	cd $(PWD)/parts/steam/install;SNAP=$(PWD)/parts/steam/install HOME=$(PWD)/parts/steam/x1 SNAP_USER_DATA=$(PWD)/parts/steam/x1 SNAP_USER_COMMON=$(PWD)/parts/steam/common ./launcher.sh
