class run-storm-worker () {

  require create-hosts-file
  require install-storm
  require create-worker-supervisord-conf
  
  exec { 'run-storm-worker':
#    command => "/usr/bin/supervisorctl start storm-supervisor",
    command => "/opt/bin/run_worker_servers.sh",
    unless => "/opt/bin/isrunning.sh storm-supervisor",
    onlyif => "/opt/bin/isrunning_zookeeper.sh"
    
  }

}
