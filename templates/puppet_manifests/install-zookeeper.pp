import "wget.pp"


class install-zookeeper () {

  $dir = '/opt'
  $user = 'zookeeper'
  $group = 'zookeeper'

  
  group { 'zk-group':
    ensure => present,
    name => $group,
  }

  user { 'zk-user':
    ensure => present,
    name => $user,
    gid => $group,
    home => '/home/zookeeper',
    managehome => true,
    shell => '/bin/bash',
    require => Group['zk-group'],
  }

  wget { 'download-zookeeper':
    url => 'http://ixa2.si.ehu.es/newsreader_storm_resources/zookeeper-3.4.6.tar.gz',
    path => '/tmp',
    creates => '/tmp/zookeeper-3.4.6.tar.gz',
  }

  exec { 'untar-zk':
    command => "/bin/tar xfz /tmp/zookeeper-3.4.6.tar.gz -C $dir",
    require => Wget['download-zookeeper'],
    creates => '/opt/zookeeper-3.4.6',
  }

  file { 'zk-dir-owner':
    name => '/opt/zookeeper-3.4.6',
    ensure => directory,
    owner => $user,
    group => $group,
    recurse => true,
    require => Exec['untar-zk'],
  }

  file { 'zk-dir-symlink':
    name => '/opt/zookeeper',
    ensure => link,
    target => '/opt/zookeeper-3.4.6',
    owner => $user,
    group => $group,
    require => File['zk-dir-owner'],
  }

  file { 'data-dir':
    name => '/var/lib/zookeeper',
    ensure => directory,
    owner => $user,
    group => $group,
  }

  file { 'log-dir':
    name => '/var/log/zookeeper',
    ensure => 'directory',
    owner => $user,
    group => $group,
  }

  file { 'conf-file':
    ensure => file,
    name => '/etc/zookeeper.cfg',
    owner => $user,
    group => $group,
    source => 'puppet:///conf_files/zookeeper.cfg',
  }    
  
}
