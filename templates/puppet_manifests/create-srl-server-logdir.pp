class create-srl-server-logdir () {

  $user = 'newsreader'
  $group = 'newsreader'

  file { 'srl-server-logdir':
    ensure => directory,
    name => '/var/log/srl-server',
    owner => $user,
    group => $group,
  }

}
