class run-kafka () {

  require install-kafka
  require run-zookeeper
  require create-boss-supervisord-conf
  require create-flush-queue-daemon-logdir
  
  exec { 'run-kafka':

    command => "/usr/bin/supervisorctl start kafka",
    unless => "/opt/bin/isrunning.sh kafka"
    
  }
  ->
  exec { 'run-flush-queue-daemon':

    command => "/usr/bin/supervisorctl start flush-queue-daemon",
    unless => "/opt/bin/isrunning.sh flush-queue-daemon"
    
  }

  
}
