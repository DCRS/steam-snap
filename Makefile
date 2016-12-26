build:
	snapcraft
test-ci:
	@echo "Soon..."
clean:
	rm -rf parts/ prime/ stage/
test-local: clean
	FORCE_X=1 snapcraft
	snap install --force-dangerous --devmode *.snap
	/snap/bin/steam
iso-build: clean
	rm -rf parts/steam/
	mkdir -p parts/steam/install
	mkdir -p parts/steam/state
	touch parts/steam/state/build
	touch parts/steam/state/pull
	cp -rvp src parts/steam/build
	cp -rvp src parts/steam/src
	make -C parts/steam/build FORCE_X=1 isobuild=1
	make -C parts/steam/build install DESTDIR=$(PWD)/parts/steam/install
iso-test: iso-build
	mkdir -p $(PWD)/parts/steam/x1
	mkdir -p $(PWD)/parts/steam/common
	@echo
	@echo
	@echo
	@echo
	@echo
	cd $(PWD)/parts/steam/install;SNAP=$(PWD)/parts/steam/install HOME=$(PWD)/parts/steam/x1 SNAP_USER_DATA=$(PWD)/parts/steam/x1 SNAP_USER_COMMON=$(PWD)/parts/steam/common isobuild=1 ./launcher.sh
