#!/usr/bin/perl

use Cwd;
use strict;
use Getopt::Long;

# default values
my $master_ip = "158.227.106.100";
my $net_ip = "192.168.122";
my $boss_ip = "100";
my $boss_name = "bossvm";
my $slave_first = "101";
my $slave_name = "workervm";
my $num_nodes = 1;
my $run_vms = 0;

my @conf_name;
my @conf_ip;
my @conf_uuid;
my @macarray;

my $help;

usage() if (!GetOptions('help|?' => \$help, 'master-ip=s'=> \$master_ip, 'net=s' => \$net_ip, 'boss-ip=s' => \$boss_ip, 'boss-name=s' => \$boss_name, 'worker-first-ip=s' => \$slave_first, 'worker-name=s' => \$slave_name, 'run' => \$run_vms) or defined $help);

sub usage
{
  print "Unknown option: @_\n" if ( @_ );
  print "usage: ./create_vcluster.pl [--help|-?] [--master-ip MASTER_IP] [--net XXX.XXX.XXX_NETWORK] [--boss-ip XXX_BOSS_IP] [--boss-name BOSS_NAME] [--worker-first-ip XXX_WORKER_IP] [--worker-name WORKER_NAME] [--run] NUM_OF_WORKER_NODES\n";
  exit;
}

$net_ip .= ".";

unless (-d "img") { system "mkdir img";}
unless (-d "tmp") { system "mkdir tmp";}
unless (-d "nodes") { system "mkdir nodes";}

unless (-f "img/base.img") {

    print "Download base.img...\n";
    system "wget -P img http://ixa2.si.ehu.es/newsreader_storm_resources/base.img";
    system "wget -P img http://ixa2.si.ehu.es/newsreader_storm_resources/base_img_ssh_rsa_key.txt";
}

my $cwd = getcwd();
$cwd =~ s/\//\\\//g;


if ($#ARGV==0) {

    checkDeps();

    if ($ARGV[0] =~ /[0-9]+/ && $ARGV[0] > 0) {

	$num_nodes = $ARGV[0];
	populateMacArray();
	createHostsFile();
	createKnownHostsFile();
	createPuppetFiles();
	createNetCfgFiles();
	createScripts();
	
	# create boss VM

	createBossVM();
	
	# create worker VMs

	for (my $ino=0; $ino < $num_nodes; $ino++) {

	    createSlaveVM($ino);
	    
	}

	# create conf file
	createConfFile();

	# run VMs?

	if ($run_vms) {
	
	    print "Starting VMs...\n\n";
	    system "virsh create nodes/".$boss_name.".xml";
	    for (my $ino=0; $ino < $num_nodes; $ino++) {
		system "virsh create nodes/".$slave_name.$ino.".xml";
	    }	

	    print "Now you can log into ".$net_ip.$boss_ip." (".$boss_name.") as root and run /root/init_system.sh\n\n";
	    
	}

    } else { usage(); }
    
} else { usage(); }

sub createBossVM {

    print "Creating Boss VM.\n";

    # prepare def

    my $uuid = `uuidgen`;
    chomp $uuid;   
    push(@conf_uuid,$uuid);
    $uuid =~ s/\-/\\\-/g;
    system "cp templates/vmdef/def.xml nodes/".$boss_name.".xml";
    system "sed -i 's/_VM_NAME_/".$boss_name."/g' nodes/".$boss_name.".xml";
    system "sed -i 's/_UUID_/".$uuid."/g' nodes/".$boss_name.".xml";
    system "sed -i 's/_IMG_PATH_/".$cwd."\\/nodes\\/".$boss_name.".img/g' nodes/".$boss_name.".xml";
    system "sed -i 's/_MACADDR_/".$macarray[0]."/g' nodes/".$boss_name.".xml";
    
    # prepare img
    system "cp img/base.img nodes/".$boss_name.".img";
    system "guestfish -a nodes/".$boss_name.".img -i rm /etc/udev/rules.d/70-persistent-net.rules &> /dev/null";
# virt-customize ez dago RHEL6ean
#    system "virt-customize -a nodes/".$boss_name.".img --upload tmp/ifcfg-eth0.".$boss_name.":/etc/sysconfig/network-scripts/ifcfg-eth0";
#    system "virt-customize -a nodes/".$boss_name.".img --upload tmp/network.".$boss_name.":/etc/sysconfig/network";
#    system "virt-customize -a nodes/".$boss_name.".img --upload tmp/hosts:/etc/hosts";
    
    system "virt-copy-in -a nodes/".$boss_name.".img tmp/ifcfg-eth0.".$boss_name." /etc/sysconfig/network-scripts/";
    system "guestfish -a nodes/".$boss_name.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$boss_name." /etc/sysconfig/network-scripts/ifcfg-eth0";
    system "virt-copy-in -a nodes/".$boss_name.".img tmp/network.".$boss_name." /etc/sysconfig/";
    system "guestfish -a nodes/".$boss_name.".img -i mv /etc/sysconfig/network.".$boss_name." /etc/sysconfig/network";
    system "virt-copy-in -a nodes/".$boss_name.".img tmp/hosts /etc/";
    system "virt-copy-in -a nodes/".$boss_name.".img tmp/known_hosts /root/.ssh";
    system "virt-copy-in -a nodes/".$boss_name.".img tmp/network.".$boss_name." /etc/sysconfig/";
    system "guestfish -a nodes/".$boss_name.".img -i mv /etc/sysconfig/network.".$boss_name." /etc/sysconfig/network";
    system "virt-copy-in -a nodes/".$boss_name.".img templates/various/ntp.conf /etc";

    # copy puppet files and chkconfig puppetmaster
    system "virt-copy-in -a nodes/".$boss_name.".img  tmp/puppet.conf tmp/fileserver.conf tmp/conf_files tmp/manifests /etc/puppet/";
    system "virt-copy-in -a nodes/".$boss_name.".img  tmp/hosts /etc/puppet/conf_files/";
    system "guestfish -a nodes/".$boss_name.".img -i command '/sbin/chkconfig puppetmaster on'";
    system "guestfish -a nodes/".$boss_name.".img -i command '/sbin/chkconfig mongod on'";
    system "guestfish -a nodes/".$boss_name.".img -i command '/sbin/chkconfig ntpd on'";
    system "guestfish -a nodes/".$boss_name.".img -i command '/sbin/chkconfig ntpdate on'";
    #

    # copy scripts
    system "virt-copy-in -a nodes/".$boss_name.".img tmp/update_nlp_components_boss.sh /home/newsreader";
    system "virt-copy-in -a nodes/".$boss_name.".img tmp/init_system.sh /root/";

    # copy storm topology data
    
#    system "virt-copy-in -a nodes/".$boss_name.".img  topologia_proba_2014_09 /home/newsreader";
    
    

    
}

sub createSlaveVM {

    print "Creating Worker VM.\n";

    my $nodename =  $slave_name.$_[0];

    # prepare def

    my $uuid = `uuidgen`;
    chomp $uuid;
    push(@conf_uuid,$uuid);
    $uuid =~ s/\-/\\\-/g;
    system "cp templates/vmdef/def.xml nodes/".$nodename.".xml";
    system "sed -i 's/_VM_NAME_/".$nodename."/g' nodes/".$nodename.".xml";
    system "sed -i 's/_UUID_/".$uuid."/g' nodes/".$nodename.".xml";
    system "sed -i 's/_IMG_PATH_/".$cwd."\\/nodes\\/".$nodename.".img/g' nodes/".$nodename.".xml";
    system "sed -i 's/_MACADDR_/".$macarray[$_[0]+1]."/g' nodes/".$nodename.".xml";

    # prepare img

    system "cp img/base.img nodes/".$nodename.".img";
    system "guestfish -a nodes/".$nodename.".img -i rm /etc/udev/rules.d/70-persistent-net.rules &> /dev/null";
# virt-customize ez dago RHEL6ean
#    system "virt-customize -a nodes/".$nodename.".img --upload tmp/ifcfg-eth0.".$nodename.":/etc/sysconfig/network-scripts/ifcfg-eth0";
#    system "virt-customize -a nodes/".$nodename.".img --upload tmp/network.".$nodename.":/etc/sysconfig/network";
#    system "virt-customize -a nodes/".$nodename.".img --upload tmp/hosts:/etc/hosts"
    system "virt-copy-in -a nodes/".$nodename.".img tmp/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/";
    system "guestfish -a nodes/".$nodename.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/ifcfg-eth0";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/network.".$nodename." /etc/sysconfig/";
    system "guestfish -a nodes/".$nodename.".img -i mv /etc/sysconfig/network.".$nodename." /etc/sysconfig/network";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/hosts /etc/";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/known_hosts /root/.ssh";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/known_hosts /home/newsreader/.ssh";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/ntp.conf /etc";

    # copy puppet.conf file
    system "virt-copy-in -a nodes/".$nodename.".img  tmp/puppet.conf /etc/puppet/";

    # ntpdate on
    system "guestfish -a nodes/".$nodename.".img -i command '/sbin/chkconfig ntpd on'";
    system "guestfish -a nodes/".$nodename.".img -i command '/sbin/chkconfig ntpdate on'";

    # copy scripts
    system "virt-copy-in -a nodes/".$nodename.".img tmp/update_nlp_components_worker.sh /home/newsreader";
    system "virt-copy-in -a nodes/".$nodename.".img files/run_storm_supervisor.sh /opt";

}

sub populateMacArray {
    
    # first the boss:
    push(@macarray,createMac());
    
    # then the workers:    

    for (my $i = 0; $i < $num_nodes; $i++) {
	my %thash;
	@thash{@macarray}=();
	my $newmac = "";
	while($newmac eq "" || exists $thash{$newmac}){	$newmac = createMac(); }
	push(@macarray,$newmac);	
    }



}

sub createHostsFile {

    open HFILE, ">tmp/hosts";
    print HFILE "127.0.0.1    localhost localhost.localdomain localhost4 localhost4.localdomain4\n";
    print HFILE "$net_ip$boss_ip    $boss_name\n";
    push(@conf_ip,"$net_ip$boss_ip");
    push(@conf_name,$boss_name);
    my $slave_cnt = $slave_first; 

    for (my $i = 0; $i < $num_nodes; $i++) {

	print HFILE "$net_ip$slave_cnt    $slave_name$i\n";
	push(@conf_ip,"$net_ip$slave_cnt");
	push(@conf_name,"$slave_name$i");

	$slave_cnt++;


    }
    
    close HFILE;

}

sub createKnownHostsFile {

    
    my $rsakey = "";
    open RFILE, "<img/base_img_ssh_rsa_key.txt";
    $rsakey = do { local $/; <RFILE> };
    close RFILE;
    chomp $rsakey;
    
    
    open HFILE, ">tmp/known_hosts";
    print HFILE "$net_ip$boss_ip,$boss_name $rsakey\n";
    my $slave_cnt = $slave_first; 
    for (my $i = 0; $i < $num_nodes; $i++) {

	print HFILE "$net_ip$slave_cnt,$slave_name$i $rsakey\n";
	$slave_cnt++;

    }
    
    close HFILE;

}


sub createPuppetFiles {

    # puppet main conf
    open PFILE, ">tmp/puppet.conf";
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
    open PFILE, ">tmp/fileserver.conf";
    print PFILE "[conf_files]\n";
    print PFILE "path /etc/puppet/conf_files\n";
    print PFILE "allow *\n";
    close PFILE;

    #
    # puppet manifests
    #
    system "cp -R templates/puppet_manifests tmp/manifests";
    # main manifest for master (site.pp)
    open PFILE, ">tmp/manifests/site.pp";
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
    
#    for (my $i = 0; $i < $num_nodes; $i++) {

#	print PFILE "node '$slave_name$i' {\n";
    
    print PFILE "node /^".$slave_name."\\d+\$/ {\n";
    print PFILE "  include create-hosts-file\n";
    print PFILE "  include install-storm\n";
    print PFILE "  include create-worker-scripts\n";
    print PFILE "  include create-worker-supervisord-conf\n";
    print PFILE "  include create-dbpedia-logdir\n";
    print PFILE "  include run-storm-worker\n";
    print PFILE "}\n";
#	print PFILE "\n";
	
#    }

    close PFILE;

    #
    # diverse conf files 
    #
    system "cp -R templates/conf_files tmp/";
    # storm.conf
    system "sed -i 's/_BOSS_NAME_/".$boss_name."/g' tmp/conf_files/storm.conf";
    # isrunning_zookeeper.sh
    system "sed -i 's/_BOSS_NAME_/".$boss_name."/g' tmp/conf_files/isrunning_zookeeper.sh";

}

sub createNetCfgFiles {

    open NFILE, ">tmp/ifcfg-eth0.$boss_name\n";
    print NFILE "DEVICE=eth0\n";
    print NFILE "HWADDR=".$macarray[0]."\n";
    print NFILE "TYPE=Ethernet\n";
    print NFILE "ONBOOT=yes\n";
    print NFILE "NM_CONTROLLED=no\n";
    print NFILE "BOOTPROTO=none\n";
    print NFILE "IPADDR=$net_ip$boss_ip\n";
    print NFILE "NETMASK=255.255.252.0\n";
    print NFILE "GATEWAY=".$net_ip."1\n";
    close NFILE;

    open NFILE, ">tmp/network.$boss_name\n";
    print NFILE "HOSTNAME=$boss_name\n";
    print NFILE "NETWORKING=yes\n";
    close NFILE;

    my $slave_cnt = $slave_first; 
    for (my $i = 0; $i < $num_nodes; $i++) {

	    open NFILE, ">tmp/ifcfg-eth0.$slave_name$i\n";
	    print NFILE "DEVICE=eth0\n";
	    print NFILE "HWADDR=".$macarray[$i+1]."\n";
	    print NFILE "TYPE=Ethernet\n";
	    print NFILE "ONBOOT=yes\n";
	    print NFILE "NM_CONTROLLED=no\n";
	    print NFILE "BOOTPROTO=none\n";
	    print NFILE "IPADDR=$net_ip$slave_cnt\n";
	    print NFILE "NETMASK=255.255.252.0\n";
	    print NFILE "GATEWAY=".$net_ip."1\n";
	    close NFILE;

	    open NFILE, ">tmp/network.$slave_name$i\n";
	    print NFILE "HOSTNAME=$slave_name$i\n";
	    print NFILE "NETWORKING=yes\n";
	    close NFILE;
	    
	    $slave_cnt++;
	
    }

    # worker ntp config
    system "cp templates/various/worker_ntp.conf tmp/ntp.conf";
    system "sed -i 's/_BOSS_NAME_/".$boss_name."/g' tmp/ntp.conf";

}

sub createScripts() {

    # update_nlp_components_boss.sh
    system "cp templates/scripts/update_nlp_components_boss.sh tmp/update_nlp_components_boss.sh";
    system "sed -i 's/_MASTER_IP_/".$master_ip."/g' tmp/update_nlp_components_boss.sh";

    # update_nlp_components_worker.sh
    system "cp templates/scripts/update_nlp_components_worker.sh tmp/update_nlp_components_worker.sh";
    system "sed -i 's/_BOSS_NAME_/".$boss_name."/g' tmp/update_nlp_components_worker.sh";

    # init_system.sh
    system  "cp templates/scripts/init_system.sh tmp/init_system.sh";
    my $num_nodes_b = $num_nodes-1;
    system "sed -i 's/_NUM_NODES_/".$num_nodes_b."/g' tmp/init_system.sh";
    system "sed -i 's/_WORKER_NAME_/".$slave_name."/g' tmp/init_system.sh";

}

sub createConfFile() {

    open CFILE, ">nodes/cluster.conf";

    for (my $i=0; $i<=$num_nodes; $i++) {

	print CFILE $conf_name[$i]."\t";
	print CFILE $conf_ip[$i]."\t";
	print CFILE $macarray[$i]."\t";
	print CFILE $conf_uuid[$i];
	print CFILE "\n";

    }

    close CFILE;

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
