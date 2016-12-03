class run-boss-servers () {

  require install-zookeeper
  require install-rabbitmq
  require install-storm
  require create-boss-supervisord-conf
  require create-flush-queue-daemon-logdir
  
  exec { 'run-boss-servers':

    command => "/home/newsreader/opt/init.d/boss_servers start",
    onlyif => "/usr/bin/test ! -f /var/lock/subsys/boss_servers"

  }
  
}
