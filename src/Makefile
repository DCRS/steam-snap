steam:
	if [ -z $(FORCE_X) ]; then xvfb-run bash script.sh; else bash script.sh; fi
install:
	mv deb $(DESTDIR)/deb
	mv steam $(DESTDIR)/steam
	mkdir -p $(DESTDIR)/sh
	mv launcher.sh $(DESTDIR)
	rm script.sh
	mv *.sh $(DESTDIR)/sh
