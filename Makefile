.PHONY: all

all:
	-mkdir bin
	v -prod -parallel-cc lsv -o bin/lsv

unused:
	-mkdir bin
	v -prod -skip-unused lsv -o bin/lsv

