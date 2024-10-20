#!/bin/sh

# Generates the include files needed for the lib and tests.
# Depends on gcc C compiler and a prebuild C libgrapheme

#export PATH=$PATH:/c/mingw64_32msys2/mingw32/bin
#export CC=gcc
# ./configure
# make all 

#build include generators
gcc pascal_gen/character.c pascal_gen/util.c libgrapheme.lib -o pascal_gen/character.exe
gcc pascal_gen/word.c pascal_gen/util.c libgrapheme.lib -o pascal_gen/word.exe
gcc pascal_gen/line.c pascal_gen/util.c libgrapheme.lib -o pascal_gen/line.exe
gcc pascal_gen/sentence.c pascal_gen/util.c libgrapheme.lib -o pascal_gen/sentence.exe
gcc pascal_gen/case.c pascal_gen/util.c libgrapheme.lib -o pascal_gen/case.exe
gcc pascal_gen/bidirectional.c pascal_gen/util.c -o pascal_gen/bidirectional.exe

#build include generators for tests
gcc pascal_gen/character-test.c pascal_gen/util.c -o pascal_gen/character-test.exe
gcc pascal_gen/word-test.c pascal_gen/util.c libgrapheme.lib  -o pascal_gen/word-test.exe
gcc pascal_gen/line-test.c pascal_gen/util.c libgrapheme.lib  -o pascal_gen/line-test.exe  
gcc pascal_gen/sentence-test.c pascal_gen/util.c libgrapheme.lib  -o pascal_gen/sentence-test.exe
gcc pascal_gen/bidirectional-test.c pascal_gen/util.c libgrapheme.lib  -o pascal_gen/bidirectional-test.exe

#generate include files
pascal_gen/character.exe > pascal_src/grapheme_gen_character.inc
pascal_gen/word.exe > pascal_src/grapheme_gen_word.inc
pascal_gen/line.exe > pascal_src/grapheme_gen_line.inc
pascal_gen/sentence.exe > pascal_src/grapheme_gen_sentence.inc
pascal_gen/case.exe > pascal_src/grapheme_gen_case.inc
pascal_gen/bidirectional.exe > pascal_src/grapheme_gen_bidirectional.inc

#generate include files for tests
pascal_gen/character-test.exe > pascal_test/character-test.inc
pascal_gen/word-test.exe > pascal_test/word-test.inc
pascal_gen/line-test.exe > pascal_test/line-test.inc 
pascal_gen/sentence-test.exe > pascal_test/sentence-test.inc
pascal_gen/bidirectional-test.exe > pascal_test/bidirectional-test.inc
