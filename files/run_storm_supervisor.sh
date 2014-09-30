#!/bin/sh
exec >/dev/null 2>&1
exec </dev/null
su - newsreader -c '/opt/storm/bin/storm supervisor &'
