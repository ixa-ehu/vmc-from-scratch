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
my $command;

# tmp dir
my $tmpdir = File::Temp->newdir( DIR => "/tmp" );


usage() if (!GetOptions('help|?' => \$help, 'master-ip=s'=> \$master_ip, 'boss-ip=s' => \$boss_ip, 'boss-name=s' => \$boss_name, 'worker-ip=s' => \$worker_ip, 'worker-name=s' => \$worker_name, 'gw-ip=s' => \$gw_ip, 'run' => \$run_vms) or defined $help);

sub usage
{
  print "Unknown option: @_\n" if ( @_ );
  print "usage: ./create_basic_cluster.pl [--help|-?] [--master-ip MASTER_IP] [--boss-ip BOSS_IP] [--boss-name BOSS_NAME] [--worker-ip WORKER_IP] [--worker-name WORKER_NAME] [--gw-ip GATEWAY_IP] [--run]\n";
  exit;
}


if ($boss_ip !~ /([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/ || $worker_ip !~ /([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/ || $gw_ip !~ /([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/) {

    finish ("Wrong IP address.");

}



unless (-d $Bin."/img") { runCommand("mkdir ".$Bin."/img");}
unless (-d $Bin."/nodes") { runCommand("mkdir ".$Bin."/nodes");}

unless (-f $Bin."/img/base.img") {

    print "Download base.img...\n";    
    runCommand("wget -P ".$Bin."/img http://ixa2.si.ehu.es/newsreader_storm_resources/base.img"); 
    runCommand("wget -P ".$Bin."/img http://ixa2.si.ehu.es/newsreader_storm_resources/base_img_ssh_rsa_key.txt");

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
    runCommand("virsh create ".$Bin."/nodes/".$boss_name.".xml");
    runCommand("virsh create ".$Bin."/nodes/".$worker_name.".xml");
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

    runCommand("cp ".$Bin."/templates/vmdef/def.xml ".$Bin."/nodes/".$boss_name.".xml");
    runCommand("sed -i 's/_VM_NAME_/".$boss_name."/g' ".$Bin."/nodes/".$boss_name.".xml");
    runCommand("sed -i 's/_UUID_/".$uuid."/g' ".$Bin."/nodes/".$boss_name.".xml");
    runCommand("sed -i 's/_IMG_PATH_/".$Bin_f."\\/nodes\\/".$boss_name.".img/g' ".$Bin."/nodes/".$boss_name.".xml");
    runCommand("sed -i 's/_MACADDR_/".$boss_mac."/g' ".$Bin."/nodes/".$boss_name.".xml");
    
    # prepare img
    runCommand("cp ".$Bin."/img/base.img ".$Bin."/nodes/".$boss_name.".img");
    runCommand("guestfish -a ".$Bin."/nodes/".$boss_name.".img -i rm /etc/udev/rules.d/70-persistent-net.rules");     
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/ifcfg-eth0.".$boss_name." /etc/sysconfig/network-scripts/");
    runCommand("guestfish -a ".$Bin."/nodes/".$boss_name.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$boss_name." /etc/sysconfig/network-scripts/ifcfg-eth0");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/network.".$boss_name." /etc/sysconfig/");
    runCommand("guestfish -a ".$Bin."/nodes/".$boss_name.".img -i mv /etc/sysconfig/network.".$boss_name." /etc/sysconfig/network");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/hosts /etc/");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/known_hosts /root/.ssh");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/known_hosts /home/newsreader/.ssh");
    runCommand("guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/bin/chown 500:500 /home/newsreader/.ssh/known_hosts'");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/network.".$boss_name." /etc/sysconfig/");
    runCommand("guestfish -a ".$Bin."/nodes/".$boss_name.".img -i mv /etc/sysconfig/network.".$boss_name." /etc/sysconfig/network");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$Bin."/templates/various/ntp.conf /etc");

    # copy puppet files and chkconfig puppetmaster
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img  ".$tmpdir."/puppet.conf ".$tmpdir."/fileserver.conf ".$tmpdir."/conf_files ".$tmpdir."/manifests /etc/puppet/");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img  ".$tmpdir."/hosts /etc/puppet/conf_files/");
    runCommand("guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/sbin/chkconfig puppetmaster on'");
    runCommand("guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/sbin/chkconfig mongod on'");
    runCommand("guestfish -a ".$Bin."/nodes/".$boss_name.".img -i command '/sbin/chkconfig ntpd on'");

    # copy scripts
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/update_nlp_components_boss.sh /home/newsreader");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$tmpdir."/init_system.sh /root/");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$boss_name.".img ".$Bin."/templates/scripts/upload_file_to_queue.php /var/www/html");

}

sub createWorkerVM {

    my $nodename =  $worker_name;

    # prepare def

    my $uuid = `uuidgen`;
    chomp $uuid;
    $uuid =~ s/\-/\\\-/g;
    runCommand("cp ".$Bin."/templates/vmdef/def.xml ".$Bin."/nodes/".$nodename.".xml");
    runCommand("sed -i 's/_VM_NAME_/".$nodename."/g' ".$Bin."/nodes/".$nodename.".xml");
    runCommand("sed -i 's/_UUID_/".$uuid."/g' ".$Bin."/nodes/".$nodename.".xml");
    runCommand("sed -i 's/_IMG_PATH_/".$Bin_f."\\/nodes\\/".$nodename.".img/g' ".$Bin."/nodes/".$nodename.".xml");
    runCommand("sed -i 's/_MACADDR_/".$worker_mac."/g' ".$Bin."/nodes/".$nodename.".xml");

    # prepare img

    runCommand("cp ".$Bin."/img/base.img ".$Bin."/nodes/".$nodename.".img");
    runCommand("guestfish -a ".$Bin."/nodes/".$nodename.".img -i rm /etc/udev/rules.d/70-persistent-net.rules &> /dev/null");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/");
    runCommand("guestfish -a ".$Bin."/nodes/".$nodename.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/ifcfg-eth0");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/network.".$nodename." /etc/sysconfig/");
    runCommand("guestfish -a ".$Bin."/nodes/".$nodename.".img -i mv /etc/sysconfig/network.".$nodename." /etc/sysconfig/network");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/hosts /etc/");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/known_hosts /root/.ssh");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/known_hosts /home/newsreader/.ssh");
    runCommand("guestfish -a ".$Bin."/nodes/".$nodename.".img -i command '/bin/chown 500:500 /home/newsreader/.ssh/known_hosts'");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/ntp.conf /etc");

    # copy puppet.conf file
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nodename.".img  ".$tmpdir."/puppet.conf /etc/puppet/");

    # ntpd / Don't activate we'll sync time in workers using puppet
    #    runCommand("guestfish -a ".$Bin."/nodes/".$nodename.".img -i command '/sbin/chkconfig ntpd on'");    

    # copy scripts
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nodename.".img ".$tmpdir."/update_nlp_components_worker.sh /home/newsreader");

}

sub createHostsFile {

    open HFILE, ">".$tmpdir."/hosts" or finish("ERROR: Cannot create ".$tmpdir."/hosts");
    print HFILE "127.0.0.1    localhost localhost.localdomain localhost4 localhost4.localdomain4\n";
    print HFILE "$boss_ip    $boss_name\n";
    print HFILE "$worker_ip    $worker_name\n";    
    close HFILE;

}

sub createKnownHostsFile {

    
    my $rsakey = "";
    open RFILE, "<".$Bin."/img/base_img_ssh_rsa_key.txt" or finish("ERROR: Cannot read ".$Bin."/img/base_img_ssh_rsa_key.txt");
    $rsakey = do { local $/; <RFILE> };
    close RFILE;
    chomp $rsakey;
    
    open HFILE, ">".$tmpdir."/known_hosts" or finish("ERROR: Cannot create ".$tmpdir."/known_hosts");
    print HFILE "$master_ip $rsakey\n";
    print HFILE "$boss_ip,$boss_name $rsakey\n";
    print HFILE "$worker_ip,$worker_name $rsakey\n";    
    close HFILE;

}


sub createPuppetFiles {

    # puppet main conf
    open PFILE, ">".$tmpdir."/puppet.conf" or finish("ERROR: Cannot create ".$tmpdir."/puppet.conf");
    print PFILE "[main]\n";
    print PFILE "    logdir = /var/log/puppet\n";
    print PFILE "    rundir = /var/run/puppet\n";
    print PFILE "    ssldir = \$vardir/ssl\n";
    print PFILE "    server=$boss_name\n";
    print PFILE "    runinterval=1h\n";
    print PFILE "[master]\n";
    print PFILE "    autosign = true\n";
    print PFILE "[agent]\n";
    print PFILE "    classfile = \$vardir/classes.txt\n";
    print PFILE "    localconfig = \$vardir/localconfig\n";
    close PFILE;

    # file server conf for master
    open PFILE, ">".$tmpdir."/fileserver.conf" or finish("ERROR: Cannot create ".$tmpdir."/fileserver.conf");
    print PFILE "[conf_files]\n";
    print PFILE "path /etc/puppet/conf_files\n";
    print PFILE "allow *\n";
    close PFILE;

    #
    # puppet manifests
    #
    runCommand ("cp -R ".$Bin."/templates/puppet_manifests ".$tmpdir."/manifests");
    # main manifest for master (site.pp)
    runCommand("sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/manifests/site.pp");

    #
    # diverse conf files 
    #
    runCommand("cp -R ".$Bin."/templates/conf_files ".$tmpdir."/");
    # storm.conf
    runCommand("sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/conf_files/storm.conf");
    # isrunning_zookeeper.sh
    runCommand("sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/conf_files/isrunning_zookeeper.sh");

}

sub createNetCfgFiles {

    open NFILE, ">".$tmpdir."/ifcfg-eth0.$boss_name" or finish("ERROR: Cannot create ".$tmpdir."/ifcfg-eth0.$boss_name");
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

    open NFILE, ">".$tmpdir."/network.$boss_name" or finish("ERROR: Cannot create ".$tmpdir."/network.$boss_name");
    print NFILE "HOSTNAME=$boss_name\n";
    print NFILE "NETWORKING=yes\n";
    close NFILE;


    open NFILE, ">".$tmpdir."/ifcfg-eth0.$worker_name" or finish("ERROR: Cannot create ".$tmpdir."/ifcfg-eth0.$worker_name");
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

    open NFILE, ">".$tmpdir."/network.$worker_name" or finish("ERROR: Cannot create ".$tmpdir."/network.$worker_name");
    print NFILE "HOSTNAME=$worker_name\n";
    print NFILE "NETWORKING=yes\n";
    close NFILE;

    # worker ntp config
    runCommand("cp ".$Bin."/templates/various/worker_ntp.conf ".$tmpdir."/ntp.conf");
    runCommand("sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/ntp.conf");

}

sub createScripts() {

    # update_nlp_components_boss.sh
    runCommand("cp ".$Bin."/templates/scripts/update_nlp_components_boss.sh ".$tmpdir."/update_nlp_components_boss.sh");
    runCommand("sed -i 's/_MASTER_IP_/".$master_ip."/g' ".$tmpdir."/update_nlp_components_boss.sh");

    # update_nlp_components_worker.sh
    runCommand( "cp ".$Bin."/templates/scripts/update_nlp_components_worker.sh ".$tmpdir."/update_nlp_components_worker.sh");
    runCommand("sed -i 's/_BOSS_NAME_/".$boss_name."/g' ".$tmpdir."/update_nlp_components_worker.sh");

    # init_system.sh
    runCommand("cp ".$Bin."/templates/scripts/init_system.sh ".$tmpdir."/init_system.sh");
    runCommand( "sed -i 's/_WORKER_NAME_/".$worker_name."/g' ".$tmpdir."/init_system.sh");

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

sub runCommand {
    
    my ($command) = @_;
    system ($command) == 0
	or finish("FAILED: ".$command);

}
