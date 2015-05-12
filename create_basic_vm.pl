#!/usr/bin/perl

use strict;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;
use FindBin qw($Bin);
my $Bin_f = $Bin;
$Bin_f =~ s/\//\\\//g;


# default values
my $master_ip = "158.227.106.100";
my $master_port = "3333";
my $nrvm_ip = "192.168.122.100";
my $nrvm_name = "nrvm";
my $gw_ip = "192.168.122.1";
my $nrvm_mac = createMac();
my $run_vms = 0;
my $disable_dbpedia = 0;
my $help;
my $command;

# tmp dir
my $tmpdir = File::Temp->newdir( DIR => "/tmp" );

 
usage() if (!GetOptions('help|?' => \$help, 'master-ip=s'=> \$master_ip, 'master-port=s'=> \$master_port, 'nrvm-ip=s' => \$nrvm_ip, 'nrvm-name=s' => \$nrvm_name, 'gw-ip=s' => \$gw_ip, 'run' => \$run_vms, 'disable-dbpedia' => \$disable_dbpedia) or defined $help);

sub usage
{
  print "Unknown option: @_\n" if ( @_ );
  print "Usage:\n";
  print "  create_basic_vm.pl [--options]\n";
  print "Options:\n";
  print "  --help\t\t\tList available options\n";
  print "  --master-ip MASTER_IP\t\tIP Address for master (default: 158.227.106.100)\n";
  print "  --master-port MASTER_PORT\tPort for master rsync service (default: 3333)\n";
  print "  --nrvm-ip NRVM_IP\t\tIP Address for nrvm (default: 192.168.122.100)\n";
  print "  --nrvm-name NRVM_NAME\t\tName for nrvm (default: nrvm)\n";
  print "  --gw-ip GATEWAY_IP\t\tIP Address for gateway (default: 192.168.122.1)\n";
  print "  --disable-dbpedia\t\tDon't run dbpedia-spotlight server.\n";
  print "  --run\t\t\t\tStart basic cluster with 'virsh create'\n";
  exit;
}


if ($nrvm_ip !~ /([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/ || $gw_ip !~ /([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/) {

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
createNetCfgFiles();
createScripts();
	
# create NRVM

print "Creating nrvm-> NAME: ".$nrvm_name." IPADDR: ".$nrvm_ip."\n";

createNRVM();
	

# run VMs?

if ($run_vms) {
    
    print "Starting VMs...\n\n";
    runCommand("virsh create ".$Bin."/nodes/".$nrvm_name.".xml");
    print "Now you can log into ".$nrvm_ip." (".$nrvm_name.") as root and run /root/init_system.sh\n\n";
	    
} else {

    print "Now you can run the VMs with these commands:\n";
    print "virsh create ".$Bin."/nodes/".$nrvm_name.".xml \n";

}


sub createNRVM {

    # prepare def

    my $uuid = `uuidgen`;
    chomp $uuid;
    $uuid =~ s/\-/\\\-/g;

    runCommand("cp ".$Bin."/templates/vmdef/def.xml ".$Bin."/nodes/".$nrvm_name.".xml");
    runCommand("sed -i 's/_VM_NAME_/".$nrvm_name."/g' ".$Bin."/nodes/".$nrvm_name.".xml");
    runCommand("sed -i 's/_UUID_/".$uuid."/g' ".$Bin."/nodes/".$nrvm_name.".xml");
    runCommand("sed -i 's/_IMG_PATH_/".$Bin_f."\\/nodes\\/".$nrvm_name.".img/g' ".$Bin."/nodes/".$nrvm_name.".xml");
    runCommand("sed -i 's/_MACADDR_/".$nrvm_mac."/g' ".$Bin."/nodes/".$nrvm_name.".xml");
    
    # prepare img
    runCommand("cp ".$Bin."/img/base.img ".$Bin."/nodes/".$nrvm_name.".img");
    runCommand("guestfish -a ".$Bin."/nodes/".$nrvm_name.".img -i rm /etc/udev/rules.d/70-persistent-net.rules");     
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$tmpdir."/ifcfg-eth0.".$nrvm_name." /etc/sysconfig/network-scripts/");
    runCommand("guestfish -a ".$Bin."/nodes/".$nrvm_name.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$nrvm_name." /etc/sysconfig/network-scripts/ifcfg-eth0");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$tmpdir."/network.".$nrvm_name." /etc/sysconfig/");
    runCommand("guestfish -a ".$Bin."/nodes/".$nrvm_name.".img -i mv /etc/sysconfig/network.".$nrvm_name." /etc/sysconfig/network");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$tmpdir."/hosts /etc/");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$tmpdir."/known_hosts /root/.ssh");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$tmpdir."/known_hosts /home/newsreader/.ssh");
    runCommand("guestfish -a ".$Bin."/nodes/".$nrvm_name.".img -i command '/bin/chown 500:500 /home/newsreader/.ssh/known_hosts'");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$tmpdir."/network.".$nrvm_name." /etc/sysconfig/");
    runCommand("guestfish -a ".$Bin."/nodes/".$nrvm_name.".img -i mv /etc/sysconfig/network.".$nrvm_name." /etc/sysconfig/network");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$Bin."/templates/various/ntp.conf /etc");
    if ($disable_dbpedia == 0) {
	runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$Bin."/templates/conf_files/nrvm_supervisord.conf.dbpedia /etc");
    }

    # copy scripts
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$tmpdir."/update_nlp_components_boss.sh /home/newsreader");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$Bin."/templates/conf_files/master_rsync_secret /etc");
    runCommand("virt-copy-in -a ".$Bin."/nodes/".$nrvm_name.".img ".$tmpdir."/init_system.sh /root/");



}

sub createHostsFile {

    open HFILE, ">".$tmpdir."/hosts" or finish("ERROR: Cannot create ".$tmpdir."/hosts");
    print HFILE "127.0.0.1    localhost localhost.localdomain localhost4 localhost4.localdomain4\n";
    print HFILE "$nrvm_ip    $nrvm_name\n";
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
    print HFILE "$nrvm_ip,$nrvm_name $rsakey\n";
    close HFILE;

}

sub createNetCfgFiles {

    open NFILE, ">".$tmpdir."/ifcfg-eth0.$nrvm_name" or finish("ERROR: Cannot create ".$tmpdir."/ifcfg-eth0.$nrvm_name");
    print NFILE "DEVICE=eth0\n";
    print NFILE "HWADDR=".$nrvm_mac."\n";
    print NFILE "TYPE=Ethernet\n";
    print NFILE "ONBOOT=yes\n";
    print NFILE "NM_CONTROLLED=no\n";
    print NFILE "BOOTPROTO=none\n";
    print NFILE "IPADDR=$nrvm_ip\n";
    print NFILE "NETMASK=255.255.252.0\n";
    print NFILE "GATEWAY=".$gw_ip."\n";
    close NFILE;

    open NFILE, ">".$tmpdir."/network.$nrvm_name" or finish("ERROR: Cannot create ".$tmpdir."/network.$nrvm_name");
    print NFILE "HOSTNAME=$nrvm_name\n";
    print NFILE "NETWORKING=yes\n";
    close NFILE;

}

sub createScripts() {

    # update_nlp_components_boss.sh
    runCommand("cp ".$Bin."/templates/scripts/update_nlp_components_boss.sh ".$tmpdir."/update_nlp_components_boss.sh");
    runCommand("sed -i 's/_MASTER_IP_/".$master_ip."/g' ".$tmpdir."/update_nlp_components_boss.sh");
    runCommand("sed -i 's/_MASTER_PORT_/".$master_port."/g' ".$tmpdir."/update_nlp_components_boss.sh");

    # init_system.sh
    runCommand("cp ".$Bin."/templates/scripts/init_system_nrvm.sh ".$tmpdir."/init_system.sh");

}

sub checkDeps {
    
    if (!-f "/usr/bin/wget" || !-x "/usr/bin/wget") { finish("ERROR: We need /usr/bin/wget"); }
    if (!-f "/usr/bin/virsh" || !-x "/usr/bin/virsh") { finish("ERROR: We need /usr/bin/virsh"); }
    if (!-f "/usr/bin/guestfish" || !-x "/usr/bin/guestfish") { finish("ERROR: We need /usr/bin/guestfish"); }
    if (!-f "/usr/bin/virt-copy-in" || !-x "/usr/bin/virt-copy-in") { finish("ERROR: We need /usr/bin/virt-copy-in"); }

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
