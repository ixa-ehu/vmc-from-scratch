import "install-storm.pp"


class install-storm-worker () {

  contain install-storm
  
  file { 'storm-conf-worker':
    ensure => file,
    replace => 'no',
    name => '/opt/storm/conf/storm.yaml',
    owner => $user,
    group => $group,
    source => 'puppet:///conf_files/storm.worker.conf',
  }

}