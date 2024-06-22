.PHONY: all

all:
	@v fmt -w .
	@v -prod lsv -o bin/lsv
