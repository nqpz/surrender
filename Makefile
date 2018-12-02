.PHONY: all clean

all: test

test: surrender.o test.o
	gcc -O3 -o test test.o surrender.o -lm -lOpenCL

test.o: test.c
	gcc -Wall -O3 -c test.c

surrender.o: surrender.c
	gcc -O3 -c surrender.c

surrender.c: surrender.fut lib
	futhark-opencl --library surrender.fut

lib: futhark.pkg
	futhark-pkg sync

clean:
	rm -f surrender.c surrender.h
	rm -f test test.pam
