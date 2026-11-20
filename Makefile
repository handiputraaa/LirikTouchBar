.PHONY: build debug run install release clean

build:
	./scripts/build-app.sh

debug:
	CONFIG=debug ./scripts/build-app.sh

run:
	open LirikTouchBar.app

install: build
	rm -rf /Applications/LirikTouchBar.app
	cp -R LirikTouchBar.app /Applications/

release:
	./scripts/release.sh

clean:
	rm -rf .build LirikTouchBar.app *.zip
