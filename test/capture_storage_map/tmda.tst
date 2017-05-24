#!/bin/sh

TAG_LIST="db_datafiles db_controlfiles db_redologs"

for tag in $TAG_LIST
do
	./tmd.tst $tag
done

exit 0
