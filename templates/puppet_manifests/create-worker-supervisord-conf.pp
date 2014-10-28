
class create-worker-supervisord-conf () {

  require install-storm
  
  file {'worker-supervisord-conf':
    path    => '/etc/supervisord.conf',
    ensure  => present,
    mode    => 0644,
    source => 'puppet:///conf_files/worker_supervisord.conf',
  }
  ->
  exec {'reload-supervisord':
    command => '/usr/bin/supervisorctl update',
  }

}
