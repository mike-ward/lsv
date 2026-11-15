.PHONY: all

all:
	-mkdir -p bin
	v -prod lsv -o bin/lsv

native:
	-mkdir -p bin
	v -prod -backend native lsv -o bin/lsv
