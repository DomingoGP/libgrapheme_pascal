libgrapheme
===========

This is a fork of **Laslo Hunhold** dev@frign.de  https://git.suckless.org/libgrapheme ported to
language Object Pascal  (Freepascal(Lazarus) / Delphi)

All changes to original library are in the branch "pascal"

pascal_src    contains the pascal implementation of libgrapheme.

pascal_gen    modified source C codes to generate pascal include files.

pascal_test   tests ported to pascal.


To rebuild (not required to use the package) the pascal include files, we need a c compiler. Tested with gcc 13.2.0

**Since github don't allow files bigger than 100 MB if we want to run the tests we need to generate the include files.**

open MSYS2 terminal.
C:\mingw64_32msys2\msys2.exe

export PATH=$PATH:/c/mingw64_32msys2/mingw32/bin
export CC=gcc

./configure
make all
./pascal_build_generators.sh

Author of the pascal port.
  Domingo Galmés <dgalmesp@gmail.com>

libgrapheme
===========

libgrapheme is an extremely simple freestanding C99 library providing
utilities for properly handling strings according to the latest Unicode
standard 15.0.0. It offers fully Unicode compliant

 - grapheme cluster (i.e. user-perceived character) segmentation
 - word segmentation
 - sentence segmentation
 - detection of permissible line break opportunities
 - case detection (lower-, upper- and title-case)
 - case conversion (to lower-, upper- and title-case)

on UTF-8 strings and codepoint arrays, which both can also be
null-terminated.

The necessary lookup-tables are automatically generated from the Unicode
standard data (contained in the tarball) and heavily compressed. Over
10,000 automatically generated conformance tests and over 150 unit tests
ensure conformance and correctness.

There is no complicated build-system involved and it's all done using one
POSIX-compliant Makefile. All you need is a C99 compiler, given the
lookup-table-generators and compressors are also written in C99. The
resulting library is freestanding and thus not even dependent on a
standard library to be present at runtime, making it a suitable choice
for bare metal applications.

It is also way smaller and much faster than the other established
Unicode string libraries (ICU, GNU's libunistring, libutf8proc).

Requirements
------------
A C99-compiler and POSIX make.

Installation
------------
Run ./configure, which automatically edits config.mk to match your local
setup. Edit config.mk by hand if necessary or desired for further
customization.

Afterwards enter the following command to build and install libgrapheme
(if necessary as root):

	make install

Conformance
-----------
The libgrapheme library is compliant with the Unicode 15.0.0
specification (September 2022). The tests can be run with

	make test

to check standard conformance and correctness.

Usage
-----
Include the header grapheme.h in your code and link against libgrapheme
with "-lgrapheme" either statically ("-static") or dynamically.

Author
------
Laslo Hunhold <dev@frign.de>




