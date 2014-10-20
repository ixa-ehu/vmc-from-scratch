#!/bin/sh

/usr/bin/supervisorctl start dbpedia
/usr/bin/supervisorctl start storm-supervisor
