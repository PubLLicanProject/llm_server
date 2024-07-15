#!/bin/bash
TMPFILE=`uuidgen | tr -d '-'`

echo $1 > data/tempinput/$TMPFILE
mv data/tempinput/$TMPFILE data/input/$TMPFILE

until [ -f data/output/$TMPFILE ]
do
     sleep 3
done
cat data/output/$TMPFILE
mv data/output/$TMPFILE data/results/$TMPFILE


