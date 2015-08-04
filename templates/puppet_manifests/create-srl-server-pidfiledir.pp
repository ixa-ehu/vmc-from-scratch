class create-srl-server-pidfiledir () {

  $user = 'newsreader'
  $group = 'newsreader'

  file { 'srl-server-pidfiledir':
    ensure => directory,
    name => '/var/run/srl-server',
    owner => $user,
    group => $group,
  }

}
