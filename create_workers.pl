#!/usr/bin/perl

use Cwd;
use strict;
use Getopt::Long;

# default values
my $master_ip = "158.227.106.100";
my $net_ip = "192.168.122";
my $boss_ip = "100";
my $boss_name = "bossvm";
my $worker_first = 1;
my $worker_first_net = "101";
my $worker_name = "workervm";
my $num_nodes = 1;
my $base_img = "nodes/workervm0.img";
my $help;

my $first_ip = "";
my $nodes_path = "nodes";

my @conf_name;
my @conf_ip;
my @conf_uuid;
my @macarray;


my $cwd = getcwd();
$cwd =~ s/\//\\\//g;


usage() if ( !GetOptions('help|?' => \$help, 'first-ip=s' => \$first_ip) or defined $help );

sub usage
{
  print "Unknown option: @_\n" if ( @_ );
  print "usage: ./create_workers.pl [--help|?] CLUSTER_NODES_PATH NUM_OF_WORKER_NODES\n";
  exit;
}

if ($#ARGV == 1 && $ARGV[1] =~ /^\d+$/) {

    $nodes_path = $ARGV[0];
    $num_nodes = $ARGV[1];

    loadConf();

    populateMacArray();
    createHostsFile();
    createKnownHostsFile();
    createNetCfgFiles();
    
    for (my $i = $worker_first; $i < $worker_first+$num_nodes; $i++) {

	 createWorkerVM($i);

     }

    updateBossImg();
    createConfFile();


 } else {usage();}

 sub loadConf() {

     my $cluster_conf_path = $nodes_path."/cluster.conf";

     if (-f $cluster_conf_path) {

	 open CFILE, $cluster_conf_path;
	 my @lines = <CFILE>;
	 close CFILE;

	 foreach my $line(@lines) {

	     chomp $line;
	     my @line_exp = split(/\t/,$line);
	     push(@conf_name,$line_exp[0]);
	     push(@conf_ip,$line_exp[1]);
	     push(@macarray,$line_exp[2]);
	     push(@conf_uuid,$line_exp[3]);

	 }

	 $boss_name = $conf_name[0];
	 my $first_ip = $conf_ip[0];

	 if ($first_ip =~ /([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/) {
	     $boss_ip = $4;
	 } else { finish ("Something is wrong in cluster.conf IPs.");}


	 $worker_first=$#lines;
	 my $last_ip = $conf_ip[$#conf_ip];
 #	print "LAST IP: $last_ip\n";
	 if ($last_ip =~ /([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/) {
	     $net_ip = $1.".".$2.".".$3.".";
	     $worker_first_net = $4 + 1;
	 } else { finish ("Something is wrong in cluster.conf IPs.");}


     } else {

	 finish("Cannot find $cluster_conf_path");

     }


 }

sub updateBossImg {
    
    system "virt-copy-in -a nodes/".$boss_name.".img tmp/hosts /etc/";

}

sub createWorkerVM {

    print "Creating Worker VM.\n";
     
    my $nodename =  $worker_name.$_[0];
    my $oldnodename = $worker_name.($_[0]-1);

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

    system "cp nodes/".$oldnodename.".img nodes/".$nodename.".img";
    system "guestfish -a nodes/".$nodename.".img -i rm /etc/udev/rules.d/70-persistent-net.rules &> /dev/null";
    system "guestfish -a nodes/".$nodename.".img -i rm-rf /var/lib/puppet &> /dev/null";
    system "guestfish -a nodes/".$nodename.".img -i rm-rf /var/lib/storm/supervisor &> /dev/null";
    system "guestfish -a nodes/".$nodename.".img -i rm-rf /var/lib/storm/workers &> /dev/null";
#    system "guestfish -a nodes/".$nodename.".img -i mv /var/lib/puppet /var/lib/puppet_kk ";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/";
    system "guestfish -a nodes/".$nodename.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/ifcfg-eth0";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/network.".$nodename." /etc/sysconfig/";
    system "guestfish -a nodes/".$nodename.".img -i mv /etc/sysconfig/network.".$nodename." /etc/sysconfig/network";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/hosts /etc/";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/known_hosts /root/.ssh";
    system "virt-copy-in -a nodes/".$nodename.".img tmp/known_hosts /home/newsreader/.ssh";

}

sub populateMacArray {

    for (my $i = $worker_first; $i < $worker_first+$num_nodes; $i++) {
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
    
    for(my $i=0; $i <= $#conf_name; $i++) {

	print HFILE $conf_ip[$i]."    ".$conf_name[$i]."\n";

    }

    my $worker_cnt = $worker_first_net; 
    for (my $i = $worker_first; $i < $worker_first+$num_nodes; $i++) {

	print HFILE "$net_ip$worker_cnt    $worker_name$i\n";

	push(@conf_ip,"$net_ip$worker_cnt");
	push(@conf_name,"$worker_name$i");

	$worker_cnt++;

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

    for(my $i=0; $i <= $#conf_name; $i++) {

	print HFILE $conf_ip[$i].",".$conf_name[$i]." ".$rsakey."\n";

    }

    my $worker_cnt = $worker_first_net; 
    for (my $i = $worker_first; $i < $worker_first+$num_nodes; $i++) {

	print HFILE "$net_ip$worker_cnt,$worker_name$i $rsakey\n";
	$worker_cnt++;

    }


    close HFILE;


}

sub createNetCfgFiles {

    my $worker_cnt = $worker_first_net; 
    for (my $i = $worker_first; $i < $worker_first+$num_nodes; $i++) {

	    open NFILE, ">tmp/ifcfg-eth0.$worker_name$i\n";
	    print NFILE "DEVICE=eth0\n";
	    print NFILE "HWADDR=".$macarray[$i+1]."\n";
	    print NFILE "TYPE=Ethernet\n";
	    print NFILE "ONBOOT=yes\n";
	    print NFILE "NM_CONTROLLED=no\n";
	    print NFILE "BOOTPROTO=none\n";
	    print NFILE "IPADDR=$net_ip$worker_cnt\n";
	    print NFILE "NETMASK=255.255.252.0\n";
	    print NFILE "GATEWAY=".$net_ip."1\n";
	    close NFILE;

	    open NFILE, ">tmp/network.$worker_name$i\n";
	    print NFILE "HOSTNAME=$worker_name$i\n";
	    print NFILE "NETWORKING=yes\n";
	    close NFILE;
	    
	    $worker_cnt++;
	
    }


}

sub createConfFile {

    open CFILE, ">nodes/cluster.conf";

    for (my $i=0; $i<=$#conf_name; $i++) {

	print CFILE $conf_name[$i]."\t";
	print CFILE $conf_ip[$i]."\t";
	print CFILE $macarray[$i]."\t";
	print CFILE $conf_uuid[$i];
	print CFILE "\n";

    }

    close CFILE;

}

sub checkDeps {
    
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
