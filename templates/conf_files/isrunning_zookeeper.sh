#!/bin/sh
portInfo=$(nmap -p 2181 _BOSS_NAME_ | grep open)

if [ -z "$portInfo" ]; then
    echo "stopped"
    exit 1
else
    echo "running"
    exit 0
fi
