import "install-zeromq.pp"
import "install-jzmq.pp"


class install-storm () {

  $user = 'newsreader'
  $group = 'newsreader'

  include install-zeromq
  include install-jzmq
  
  group { 'storm-group':
    ensure => present,
    name => $group,
  }

  user { 'storm-user':
    ensure => present,
    name => $user,
    gid => $group,
    home => "/home/$user",
    managehome => true,
    shell => '/bin/bash',
    require => Group['storm-group'],
  }

  package { 'unzip-install':
    name => 'unzip',
    ensure => installed,
  }

  wget { 'download-storm':
    url => 'http://ixa2.si.ehu.es/newsreader_storm_resources/storm-0.8.2.zip',
    creates => '/tmp/storm-0.8.2.zip',
    require => Package['unzip-install'],
  }      
  
  exec { 'unzip':
    command => '/usr/bin/unzip /tmp/storm-0.8.2.zip -d /opt',
    require => Wget['download-storm'],
    creates => '/opt/storm-0.8.2',
  }

  file { 'storm-chown':
    ensure => directory,
    name => '/opt/storm-0.8.2',
    owner => $user,
    group => $group,
    recurse => true,
    require => Exec['unzip'], 
  }

  file { 'storm-symlnk':
    ensure => link,
    name => '/opt/storm',
    target => '/opt/storm-0.8.2',
    owner => $user,
    group => $group,
    require => File['storm-chown'],
  }

  file { 'storm-data-dir':
    ensure => directory,
    name => '/var/lib/storm',
    owner => $user,
    group => $group,
  }

  file { 'storm-log-dir':
    ensure => directory,
    name => '/var/log/storm',
    owner => $user,
    group => $group,
  }

  file { 'storm-conf':
    ensure => file,
    name => '/opt/storm/conf/storm.yaml',
    owner => $user,
    group => $group,
    source => 'puppet:///conf_files/storm.conf',
  }
  
}
