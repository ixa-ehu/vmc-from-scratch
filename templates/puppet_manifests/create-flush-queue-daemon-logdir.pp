class create-flush-queue-daemon-logdir () {

  $user = 'newsreader'
  $group = 'newsreader'

  file { 'flush-queue-daemon-logdir':
    ensure => directory,
    name => '/var/log/flush-queue-daemon',
    owner => $user,
    group => $group,
  }

}
