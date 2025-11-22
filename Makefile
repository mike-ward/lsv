.PHONY: all

all:
	-mkdir bin
	v -prod -gc none lsv -o bin/lsv

native:
	-mkdir bin
	v -prod -backend native lsv -o bin/lsv
