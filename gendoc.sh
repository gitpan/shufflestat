#!/bin/bash

PREFIX=$1

createdoc()
{
	filename=${1%.*};
	echo "pod2text $1 > $PREFIX/doc/$filename.txt"
	pod2text $1 > $PREFIX/doc/$filename.txt 2>/dev/null
	echo "pod2man  $1 > $PREFIX/doc/$filename.man"
	pod2man  $1 > $PREFIX/doc/$filename.man 2>/dev/null
	echo "pod2html $1 --outfile $PREFIX/doc/$filename.html"
	pod2html $1 --outfile $PREFIX/doc/$filename.html 2>/dev/null
	rm -f pod2htm*
}
createdoc ./StatDB.pm
