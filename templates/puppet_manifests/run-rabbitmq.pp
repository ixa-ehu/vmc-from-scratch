class run-rabbitmq () {

  require install-rabbitmq
  require create-boss-supervisord-conf
  require create-flush-queue-daemon-logdir
  
  exec { 'run-rabbitmq':

    command => "/usr/bin/supervisorctl start rabbitmq",
    unless => "/opt/bin/isrunning.sh rabbitmq"
    
  }
  ->
  exec { 'run-flush-queue-daemon':

    command => "/usr/bin/supervisorctl start flush-queue-daemon",
    unless => "/opt/bin/isrunning.sh flush-queue-daemon"
    
  }

  
}
