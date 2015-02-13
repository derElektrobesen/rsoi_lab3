#!/bin/bash

. config

echo -n "kill -TERM " > pids
for var in 'front' 'logic' 'users' 'messages' 'session'
do
    path=$(echo -n $var | perl -ne '$_ = uc $_;  printf "\"http://*:\$$_%s", "_PORT\""')
    path=$(eval "echo $path")
    ./$var/script/$var daemon -l $path &
    echo -n "$! " >> pids
done
