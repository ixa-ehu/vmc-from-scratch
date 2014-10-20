
class copy-hosts-file () {

  exec { "copy-hosts":
    command => "/bin/cp /etc/hosts /etc/puppet/conf_files/hosts",
#    creates => "/etc/puppet/conf_files/hosts"
  }
  
}
