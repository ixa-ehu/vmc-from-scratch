class run-worker-servers () {

  require create-hosts-file
  require install-storm
  require create-worker-supervisord-conf
  require create-dbpedia-logdir
  
  exec { 'run-worker-servers':

    command => "/home/newsreader/opt/sbin/init.d/worker_servers start",
    onlyif => [
               "/usr/bin/test ! -f /var/lock/subsys/worker_servers",
               "/opt/bin/isrunning_zookeeper.sh"
               ]

  }
  
}
