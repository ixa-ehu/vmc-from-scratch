
class create-hosts-file () {

  file {'hosts-file':
    path    => '/etc/hosts',
    ensure  => present,
    mode    => 0644,
    source => 'puppet:///conf_files/hosts',
  }

}
