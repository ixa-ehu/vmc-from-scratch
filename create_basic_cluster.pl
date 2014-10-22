#!/usr/bin/perl

use strict;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;
use FindBin qw($Bin);
my $Bin_f = $Bin;
$Bin_f =~ s/\//\\\//g;


# default values
my $master_ip = "158.227.106.100";
my $boss_ip = "192.168.122.100";
my $boss_name = "bossvm";
my $worker_ip = "192.168.122.101";
my $worker_name = "workervm0";
my $gw_ip = "192.168.122.1";
my $boss_mac = createMac();
my $worker_mac = createMac();
my $run_vms = 0;
my $help;

# tmp dir
my $tmpdir = File::Temp->newdir( DIR => "/tmp" );


usage() if (!GetOptions('help|?' => \$help, 'master-ip=s'=> \$master_ip, 'boss-ip=s' => \$boss_ip, 'boss-name=s' => \$boss_name, 'worker-ip=s' => \$worker_ip, 'worker-name=s' => \$worker_name, 'gw-ip=s' => \$gw_ip, 'run' => \$run_vms) or defined $help);

sub usage
{
  print "Unknown option: @_\n" if ( @_ );
  print "usage: ./create_basic_cluster.pl [--help|-?] [--master-ip MASTER_IP] [--boss-ip BOSS_IP] [--boss-name BOSS_NAME] [--worker-ip WORKER_IP] [--worker-name WORKER_NAME] [--gw-ip GATEWAY_IP] [--run]\n";
  exit;
}




unless (-d $Bin."/img") { system "mkdir ".$Bin."/img";}
unless (-d $Bin."/nodes") { system "mkdir ".$Bin."/nodes";}

unless (-f $Bin."/img/base.img") {

    print "Download base.img...\n";
    system "wget -P ".$Bin."/img http://ixa2.si.ehu.es/newsreader_storm_resources/base.img";
    system "wget -P ".$Bin."/img http://ixa2.si.ehu.es/newsreader_storm_resources/base_img_ssh_rsa_key.txt";
}

checkDeps();
createHostsFile();
createKnownHostsFile();
createPuppetFiles();
createNetCfgFiles();
createScripts();
	
# create boss VM

print "Creating bossvm-> NAME: ".$boss_name." IPADDR: ".$boss_ip."\n";

createBossVM();
	
# create worker VMs

print "Creating workervm-> NAME: ".$worker_name." IPADDR: ".$worker_ip."\n";
createWorkerVM();

# run VMs?

if ($run_vms) {
    
    print "Starting VMs...\n\n";
    system "virsh create ".$Bin."/nodes/".$boss_name.".xml";
    system "virsh create ".$Bin."/nodes/".$worker_name.".xml";
    print "Now you can log into ".$boss_ip." (".$boss_name.") as root and run /root/init_system.sh\n\n";
	    
} else {

    print "Now you can run the VMs with these commands:\n";
    print "virsh create ".$Bin."/nodes/".$boss_name.".xml \n";
    print "virsh create ".$Bin."/nodes/".$worker_name.".xml \n";

}


sub createBossVM {

    # prepare def

    my $uuid = `uuidgen`;
    chomp $uuid;
    $uuid =~ s/\-/\\\-/g;
    system "cp ".$Bin."/templates/vmdef/def.xml ".$Bin."/nodes/".$boss_name.".xml";
    system "sed -i 's/_VM_NAME_/".$boss_name."/g' ".$Bin."/nodes/".$boss_name.".xml";
    system "sed -i 's/_UUID_/".$uuid."/g' ".$Bin."/nodes/".$boss_name.".xml";
    system "sed -i 's/_IMG_PATH_/".$Bin_f."\\/nodes\\/".$boss_name.".img/g' ".$Bin."/nodes/".$boss_name.".xml";
    system "sed -i 's/_MACADDR_/".$boss_mac."/g' ".$Bin."/nodes/".$boss_name.".xml";
    
    # prepare img
    system "cp ".$Bin."/img/base.img ".$Bin."/nodes/".$boss_name.".img";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i rm /etc/udev/rules.d/70-persistent-net.rules &> /dev/null";
    
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/ifcfg-eth0.".$boss_name." /etc/sysconfig/network-scripts/";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$boss_name." /etc/sysconfig/network-scripts/ifcfg-eth0";
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/network.".$boss_name." /etc/sysconfig/";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i mv /etc/sysconfig/network.".$boss_name." /etc/sysconfig/network";
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/hosts /etc/";
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/known_hosts /root/.ssh";
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/known_hosts /home/newsreader/.ssh";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/bin/chown 500:500 /home/newsreader/.ssh/known_hosts'";
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/network.".$boss_name." /etc/sysconfig/";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i mv /etc/sysconfig/network.".$boss_name." /etc/sysconfig/network";
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$Bin."/templates/various/ntp.conf /etc";

    # copy puppet files and chkconfig puppetmaster
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img  ".$tmpdir."/puppet.conf ".$tmpdir."/fileserver.conf ".$tmpdir."/conf_files ".$tmpdir."/manifests /etc/puppet/";
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img  ".$tmpdir."/hosts /etc/puppet/conf_files/";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/sbin/chkconfig puppetmaster on'";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/sbin/chkconfig mongod on'";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/sbin/chkconfig ntpd on'";
    system "guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/sbin/chkconfig ntpdate on'";
    #

    # copy scripts
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/update_nlp_components_boss.sh /home/newsreader";
    system "virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/init_system.sh /root/";
    
}

sub createWorkerVM {

    my $nodename =  $worker_name;

    # prepare def

    my $uuid = `uuidgen`;
    chomp $uuid;
    $uuid =~ s/\-/\\\-/g;
    system "cp ".$Bin."/templates/vmdef/def.xml ".$Bin."/nodes/".$nodename.".xml";
    system "sed -i 's/_VM_NAME_/".$nodename."/g' ".$Bin."/nodes/".$nodename.".xml";
    system "sed -i 's/_UUID_/".$uuid."/g' ".$Bin."/nodes/".$nodename.".xml";
    system "sed -i 's/_IMG_PATH_/".$Bin_f."\\/nodes\\/".$nodename.".img/g' ".$Bin."/nodes/".$nodename.".xml";
    system "sed -i 's/_MACADDR_/".$worker_mac."/g' ".$Bin."/nodes/".$nodename.".xml";

    # prepare img

    system "cp ".$Bin."/img/base.img ".$Bin."/nodes/".$nodename.".img";
    system "guestfish -a ".$Bin."/nodes/".$nodename.".img -i rm /etc/udev/rules.d/70-persistent-net.rules &> /dev/null";
    system "virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/";
    system "guestfish -a ".$Bin."/nodes/".$nodename.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/ifcfg-eth0";
    system "virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/network.".$nodename." /etc/sysconfig/";
    system "guestfish -a ".$Bin."/nodes/".$nodename.".img -i mv /etc/sysconfig/network.".$nodename." /etc/sysconfig/network";
    system "virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/hosts /etc/";
#    system "virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/known_hosts /root/.ssh";
#    system "virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/known_hosts /home/newsreader/.ssh";
    system "virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/ntp.conf /etc";

    # copy puppet.conf file
    system "virt-copy-in -a ".$Bin."/nodes/".$nodename.".img  ".$tmpdir."/puppet.conf /etc/puppet/";

    # ntpdate on
    system "guestfish -a ".$Bin."/nodes/".$nodename.".img -i command '/sbin/chkconfig ntpd on'";
    system "guestfish -a ".$Bin."/nodes/".$nodename.".img -i command '/sbin/chkconfig ntpdate on'";

    # copy scripts
    system "virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/update_nlp_components_worker.sh /home/newsreader";

}

sub createHostsFile {

    open HFILE, ">".$tmpdir."/hosts";
    print HFILE "127.0.0.1    localhost localhost.localdomain localhost4 localhost4.localdomain4\n";
    print HFILE "$boss_ip    $boss_name\n";
    print HFILE "$worker_ip    $worker_name\n";    
    close HFILE;

}

sub createKnownHostsFile {

    
    my $rsakey = "";
    open RFILE, "<".$Bin."/img/base_img_ssh_rsa_key.txt";
    $rsakey = do { local $/; <RFILE> };
    close RFILE;
    chomp $rsakey;
    
    open HFILE, ">".$tmpdir."/known_hosts";
    print HFILE "$boss_ip,$boss_name $rsakey\n";
    print HFILE "$worker_ip,$worker_name $rsakey\n";    
    close HFILE;

}


sub createPuppetFiles {

    # puppet main conf
    open PFILE, ">".$tmpdir."/puppet.conf";
    print PFILE "[main]\n";
    print PFILE "    logdir = /var/log/puppet\n";
    print PFILE "    rundir = /var/run/puppet\n";
    print PFILE "    ssldir = \$vardir/ssl\n";
    print PFILE "    server=$boss_name\n";
    print PFILE "[master]\n";
    print PFILE "    autosign = true\n";
    print PFILE "[agent]\n";
    print PFILE "    classfile = \$vardir/classes.txt\n";
    print PFILE "    localconfig = \$vardir/localconfig\n";
    close PFILE;

    # file server conf for master
    open PFILE, ">".$tmpdir."/fileserver.conf";
    print PFILE "[conf_files]\n";
    print PFILE "path /etc/puppet/conf_files\n";
    print PFILE "allow *\n";
    close PFILE;

    #
    # puppet manifests
    #
    system "cp -R ".$Bin."/templates/puppet_manifests ".$tmpdir."/manifests";
    # main manifest for master (site.pp)
    open PFILE, ">".$tmpdir."/manifests/site.pp";
    print PFILE "import \"copy-hosts-file.pp\"\n";
    print PFILE "import \"create-hosts-file.pp\"\n";
    print PFILE "import \"install-zookeeper.pp\"\n";
    print PFILE "import \"install-kafka.pp\"\n";
    print PFILE "import \"install-storm.pp\"\n";
    print PFILE "import \"create-boss-scripts.pp\"\n";
    print PFILE "import \"create-worker-scripts.pp\"\n";
    print PFILE "import \"create-boss-supervisord-conf.pp\"\n";
    print PFILE "import \"create-worker-supervisord-conf.pp\"\n";
    print PFILE "import \"run-zookeeper.pp\"\n";
    print PFILE "import \"run-kafka.pp\"\n";
    print PFILE "import \"run-storm-boss.pp\"\n";
    print PFILE "import \"run-storm-worker.pp\"\n";
    print PFILE "import \"create-dbpedia-logdir\"\n";
    print PFILE "\n";
    print PFILE "node '$boss_name' {\n";
    print PFILE "  include copy-hosts-file\n";
    print PFILE "  include install-zookeeper\n";
    print PFILE "  include install-kafka\n";
    print PFILE "  include install-storm\n";
    print PFILE "  include create-boss-scripts\n";
    print PFILE "  include create-boss-supervisord-conf\n";
    print PFILE "  include run-zookeeper\n";
    print PFILE "  include run-kafka\n";
    print PFILE "  include run-storm-boss\n";
    print PFILE "}\n";
    print PFILE "\n";
    
    print PFILE "node default {\n";
    print PFILE "  include create-hosts-file\n";
    print PFILE "  include install-storm\n";
    print PFILE "  include create-worker-scripts\n";
    print PFILE "  include create-worker-supervisord-conf\n";
    print PFILE "  include create-dbpedia-logdir\n";
    print PFILE "  include run-storm-worker\n";
    print PFILE "}\n";
    close PFILE;

    #
    # diverse conf files 
    #
    system "cp -R ".$Bin."/templates/conf_files ".$tmpdir."/";
    # storm.conf
    system "sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/conf_files/storm.conf";
    # isrunning_zookeeper.sh
    system "sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/conf_files/isrunning_zookeeper.sh";

}

sub createNetCfgFiles {

    open NFILE, ">".$tmpdir."/ifcfg-eth0.$boss_name\n";
    print NFILE "DEVICE=eth0\n";
    print NFILE "HWADDR=".$boss_mac."\n";
    print NFILE "TYPE=Ethernet\n";
    print NFILE "ONBOOT=yes\n";
    print NFILE "NM_CONTROLLED=no\n";
    print NFILE "BOOTPROTO=none\n";
    print NFILE "IPADDR=$boss_ip\n";
    print NFILE "NETMASK=255.255.252.0\n";
    print NFILE "GATEWAY=".$gw_ip."\n";
    close NFILE;

    open NFILE, ">".$tmpdir."/network.$boss_name\n";
    print NFILE "HOSTNAME=$boss_name\n";
    print NFILE "NETWORKING=yes\n";
    close NFILE;


    open NFILE, ">".$tmpdir."/ifcfg-eth0.$worker_name\n";
    print NFILE "DEVICE=eth0\n";
    print NFILE "HWADDR=".$worker_mac."\n";
    print NFILE "TYPE=Ethernet\n";
    print NFILE "ONBOOT=yes\n";
    print NFILE "NM_CONTROLLED=no\n";
    print NFILE "BOOTPROTO=none\n";
    print NFILE "IPADDR=$worker_ip\n";
    print NFILE "NETMASK=255.255.252.0\n";
    print NFILE "GATEWAY=".$gw_ip."\n";
    close NFILE;

    open NFILE, ">".$tmpdir."/network.$worker_name\n";
    print NFILE "HOSTNAME=$worker_name\n";
    print NFILE "NETWORKING=yes\n";
    close NFILE;

    # worker ntp config
    system "cp ".$Bin."/templates/various/worker_ntp.conf ".$tmpdir."/ntp.conf";
    system "sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/ntp.conf";

}

sub createScripts() {

    # update_nlp_components_boss.sh
    system "cp ".$Bin."/templates/scripts/update_nlp_components_boss.sh ".$tmpdir."/update_nlp_components_boss.sh";
    system "sed -i 's/_MASTER_IP_/".$master_ip."/g' ".$tmpdir."/update_nlp_components_boss.sh";

    # update_nlp_components_worker.sh
    system "cp ".$Bin."/templates/scripts/update_nlp_components_worker.sh ".$tmpdir."/update_nlp_components_worker.sh";
    system "sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/update_nlp_components_worker.sh";

    # init_system.sh
    system  "cp ".$Bin."/templates/scripts/init_system.sh ".$tmpdir."/init_system.sh";
    system "sed -i 's/_WORKER_NAME_/".$worker_name."/g' ".$tmpdir."/init_system.sh";

}

sub checkDeps {
    
    if (!-f "/usr/bin/wget" || !-x "/usr/bin/wget") { finish("We need executable /usr/bin/wget"); }
    if (!-f "/usr/bin/virsh" || !-x "/usr/bin/virsh") { finish("We need executable /usr/bin/virsh"); }
    if (!-f "/usr/bin/guestfish" || !-x "/usr/bin/guestfish") { finish("We need executable /usr/bin/guestfish"); }
    if (!-f "/usr/bin/virt-copy-in" || !-x "/usr/bin/virt-copy-in") { finish("We need executable /usr/bin/virt-copy-in"); }

}

sub createMac {

    my $mac = "52:54:00:";
    for (my $i=0;$i<3;$i++) {
	$mac.=sprintf("%02X",int(rand(255))).(($i<2)?':':'');
    }
    return $mac;

}

sub finish {
    my ($p) = @_;
    print $p."\n";
    exit;
}
