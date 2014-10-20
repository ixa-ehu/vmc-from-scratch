#!/bin/sh

LE=`/usr/bin/supervisorctl status $1`

if [[ "$LE" =~ "RUNNING" ]]; then
    echo "running"
    exit 0
else
    echo "stopped"
    exit 1
fi
