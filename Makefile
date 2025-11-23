.PHONY: all

all:
	-mkdir bin
	v -prod lsv -o bin/lsv

native:
	-mkdir bin
	v -prod -backend native lsv -o bin/lsv
