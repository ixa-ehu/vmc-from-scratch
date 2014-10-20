
class create-worker-scripts () {

  file { 'opt-bin-dir':
    name => '/opt/bin',
    ensure => 'directory',
    owner => root,
    group => root,
  }
  
  file {'worker-start-script':
    path    => '/opt/bin/run_worker_servers.sh',
    ensure  => present,
    mode    => 0755,
    source => 'puppet:///conf_files/run_worker_servers.sh',
  }

  file {'worker-stop-script':
    path    => '/opt/bin/stop_worker_servers.sh',
    ensure  => present,
    mode    => 0755,
    source => 'puppet:///conf_files/stop_worker_servers.sh',
  }

  file {'is-running':
    path    => '/opt/bin/isrunning.sh',
    ensure  => present,
    mode    => 0755,
    source => 'puppet:///conf_files/isrunning.sh',
  }

  file {'is-running-zookeeper':
    path    => '/opt/bin/isrunning_zookeeper.sh',
    ensure  => present,
    mode    => 0755,
    source => 'puppet:///conf_files/isrunning_zookeeper.sh',
  }
  
}
