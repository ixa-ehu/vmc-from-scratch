#!/usr/bin/perl


use strict;
use Getopt::Long;
use File::Temp qw/ tempfile tempdir /;
use FindBin qw($Bin);
my $Bin_f = $Bin;
$Bin_f =~ s/\//\\\//g;
my $help;


# default values
my $boss_img = $Bin."/nodes/bossvm.img";
my $worker_img = $Bin."/nodes/workervm0.img";
my $out_dir = $Bin."/nodes";
my $gw_ip = "192.168.122.1";
my @iplist;
my @namelist;
my @macarray;

# tmp dir
my $tmpdir = File::Temp->newdir( DIR => "/tmp" );


usage() if ( !GetOptions('help|?' => \$help, 'boss-img=s' => \$boss_img, 'worker-img=s' => \$worker_img, 'out-dir=s' => \$out_dir, 'gw-ip=s' => \$gw_ip) or defined $help );

sub usage
{
  print "Unknown option: @_\n" if ( @_ );
  print "Usage:\n";
  print "  cp_worker.pl [--options] new_worker_ip,new_worker_name [new_worker_ip,new_worker_name ...]\n";
  print "Options:\n";
  print "  --help\t\t\tList available options\n";
  print "  --boss-img BOSS_IMG_FILE\tBoss VM image file (default: ./nodes/bossvm.img)\n";
  print "  --worker-img WORKER_IMG_FILE\tWorker VM image file (default: ./nodes/workervm0.img)\n";
  print "  --out-dir OUT_DIR\t\tWhere to create new VM definition and image (default ./nodes)\n";
  print "  --gw-ip GATEWAY_IP\t\tIP Address for gateway (default: 192.168.122.1)\n";
  exit;
}

my $out_dir_f = $out_dir;
$ot_dir_f =~ s/\//\\\//g;

if ($#ARGV >= 0) {

    foreach my $duo (@ARGV) {

	my ($current_ip,$current_name) =split(/,/,$duo);
	if ($current_ip =~ /([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)/) {

	    push(@iplist, $current_ip);
	    push(@namelist, $current_name);

	} else {finish("Bad format for IP addr: ".$current_ip);}

    }
    
    # create conf files
    populateMacArray();
    createHostsFile();
    createKnownHostsFile();
    createNetCfgFiles();

    for (my $i = 0; $i <= $#iplist; $i++) {

	print "Creating workervm-> NAME: ".$namelist[$i]." IPADDR: ".$iplist[$i]."\n";
	createWorkerVM($i);

    }
    
    updateBossImg();

} else {usage();}


sub updateBossImg {
    
    runCommand("virt-copy-in -a ".$boss_img." ".$tmpdir."/hosts /etc/");
    runCommand("virt-copy-in -a ".$boss_img." ".$tmpdir."/known_hosts /root/.ssh");
    
}

sub createWorkerVM {

    my($i) = @_;
    my $nodename = $namelist[$i];

    # prepare def

    my $uuid = `uuidgen`;
    chomp $uuid;
    $uuid =~ s/\-/\\\-/g;
    runCommand("cp ".$Bin."/templates/vmdef/def.xml ".$out_dir."/".$nodename.".xml");
    runCommand("sed -i 's/_VM_NAME_/".$nodename."/g' ".$out_dir."/".$nodename.".xml");
    runCommand("sed -i 's/_UUID_/".$uuid."/g' ".$out_dir."/".$nodename.".xml");
    runCommand("sed -i 's/_IMG_PATH_/".$out_dir_f."\\/".$nodename.".img/g' ".$out_dir."/".$nodename.".xml");
    runCommand("sed -i 's/_MACADDR_/".$macarray[$i]."/g' ".$out_dir."/".$nodename.".xml");

    # prepare img

    runCommand("cp ".$worker_img."  ".$out_dir."/".$nodename.".img");
    runCommand("guestfish -a ".$out_dir."/".$nodename.".img -i rm /etc/udev/rules.d/70-persistent-net.rules &> /dev/null");
    runCommand("guestfish -a ".$out_dir."/".$nodename.".img -i rm-rf /var/lib/puppet &> /dev/null");
    runCommand("guestfish -a ".$out_dir."/".$nodename.".img -i rm-rf /var/lib/storm/supervisor &> /dev/null");
    runCommand("guestfish -a ".$out_dir."/".$nodename.".img -i rm-rf /var/lib/storm/workers &> /dev/null");
    runCommand("virt-copy-in -a ".$out_dir."/".$nodename.".img ".$tmpdir."/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/");
    runCommand("guestfish -a ".$out_dir."/".$nodename.".img -i mv /etc/sysconfig/network-scripts/ifcfg-eth0.".$nodename." /etc/sysconfig/network-scripts/ifcfg-eth0");
    runCommand("virt-copy-in -a ".$out_dir."/".$nodename.".img ".$tmpdir."/network.".$nodename." /etc/sysconfig/");
    runCommand("guestfish -a ".$out_dir."/".$nodename.".img -i mv /etc/sysconfig/network.".$nodename." /etc/sysconfig/network");
    runCommand("virt-copy-in -a ".$out_dir."/".$nodename.".img ".$tmpdir."/hosts /etc/");
    runCommand("virt-copy-in -a ".$out_dir."/".$nodename.".img ".$tmpdir."/known_hosts /root/.ssh");
    runCommand("virt-copy-in -a ".$out_dir."/".$nodename.".img ".$tmpdir."/known_hosts /home/newsreader/.ssh");

}

sub populateMacArray {

    for (my $i = 0; $i <= $#iplist ; $i++) {
	my %thash;
	@thash{@macarray}=();
	my $newmac = "";
	while($newmac eq "" || exists $thash{$newmac}){	$newmac = createMac(); }
	push(@macarray,$newmac);	
    }

}

sub createHostsFile {

    # get boss hosts
    
    runCommand("virt-copy-out -a ".$boss_img." /etc/hosts ".$tmpdir);
    

    open HFILE, ">>".$tmpdir."/hosts" or finish("ERROR: Cannot open ".$tmpdir."/hosts");
    
    for(my $i=0; $i <= $#iplist; $i++) {

	print HFILE $iplist[$i]."    ".$namelist[$i]."\n";

    }
    
    close HFILE;

}

sub createKnownHostsFile {

    
    my $rsakey = "";
    open RFILE, "<".$Bin."/img/base_img_ssh_rsa_key.txt" or finish("ERROR: Cannot read ".$Bin."/img/base_img_ssh_rsa_key.txt");
    $rsakey = do { local $/; <RFILE> };
    close RFILE;
    chomp $rsakey;    

    # get boss known_hosts
    
    runCommand("virt-copy-out -a ".$boss_img." /root/.ssh/known_hosts ".$tmpdir);

    open HFILE, ">>".$tmpdir."/known_hosts" or finish("ERROR: Cannot create ".$tmpdir."/known_hosts");

    for(my $i=0; $i <= $#iplist; $i++) {

	print HFILE $iplist[$i].",".$namelist[$i]." ".$rsakey."\n";

    }

    close HFILE;


}

sub createNetCfgFiles {

    for(my $i=0; $i <= $#iplist; $i++) {

	open NFILE, ">".$tmpdir."/ifcfg-eth0.".$namelist[$i] or finish("ERROR: Cannot create ".$tmpdir."/ifcfg-eth0.".$namelist[$i]);
	print NFILE "DEVICE=eth0\n";
	print NFILE "HWADDR=".$macarray[$i]."\n";
	print NFILE "TYPE=Ethernet\n";
	print NFILE "ONBOOT=yes\n";
	print NFILE "NM_CONTROLLED=no\n";
	print NFILE "BOOTPROTO=none\n";
	print NFILE "IPADDR=".$iplist[$i]."\n";
	print NFILE "NETMASK=255.255.252.0\n";
	print NFILE "GATEWAY=".$gw_ip."\n"; # FIXME
	close NFILE;

	open NFILE, ">".$tmpdir."/network.".$namelist[$i] or finish("ERROR: Cannot create ".$tmpdir."/network.".$namelist[$i]);
	print NFILE "HOSTNAME=".$namelist[$i]."\n";
	print NFILE "NETWORKING=yes\n";
	close NFILE;
	    
    }


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

sub runCommand {
    
    my ($command) = @_;
    system ($command) == 0
	or finish("FAILED: ".$command);

}
