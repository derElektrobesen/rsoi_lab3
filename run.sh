#!/bin/bash

. config

pidsf='.pids'
if [[ -f .pids ]]
then
    pids=`cat $pidsf`
    kill -9 $pids
    sleep 1
fi

echo -n "" > $pidsf
for var in 'front' 'users' 'messages' 'session'
do
    path=$(echo -n $var | perl -ne '$_ = uc $_;  printf "\"http://*:\$$_%s", "_PORT\""')
    path=$(eval "echo $path")
    ./$var/script/$var daemon -l $path &
    echo -n "$! " >> $pidsf
done
