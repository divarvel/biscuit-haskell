.PHONY: ghcid
ghcid:
	ghcid -l -c 'stack ghci biscuit-haskell:lib biscuit-haskell:biscuit-haskell-test' -T main

.PHONY: configure
configure:
	cabal configure --enable-tests --test-show-details=direct --disable-optimization

.PHONY: build
build:
	cabal build -j all

.PHONY: test
test:
	cabal test all
