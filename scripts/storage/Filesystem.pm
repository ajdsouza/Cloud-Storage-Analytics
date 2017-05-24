# 
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: Filesystem.pm,v 1.67 2003/10/10 00:38:16 ajdsouza Exp $ 
#
#
# NAME  
#	 Filesystem.pm
#
# DESC 
#	Filesystem specific subroutines to get filesystem information 
#
#
# FUNCTIONS
# sub openTcpSocket( $$ );
# sub getServerDesc( $ );
# getNFSShare($)
# getMountPrivilege($)
# getMountOptions( $ );
# getProduct($)
# getVendor($) 
# getServerVendor($)
# localFilesystems
# allFilesystems
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	10/01/01 - Created
#
#
#
package Monitor::OS::Filesystem;

require v5.6.1;
use strict;
use warnings;
use Net::SNMP;
use IO::Socket;
use Monitor::Utilities;
use Monitor::Storage;

#------------------------------------------------
# subs declared
#-----------------------------------------------
sub openTcpSocket( $$ );
sub getServerDesc( $ );
sub getNFSShare( $ );
sub getMountPrivilege( $ );
sub getMountOptions( $ );
sub getProduct( $ );
sub getVendor( $ );
sub getServerVendor( $ );
sub localFilesystems;
sub allFilesystems;
sub getNFSFilesystems ( );

#-------------------------------------------------
# Variables in package scope
#------------------------------------------------

# SNMP OIDs used in SNMP get 
my %snmpoid = (
	       product => '1.3.6.1.2.1.1.2.0',
	       vendor  => '1.3.6.1.2.1.1.1.0'
	       );

my %productoid =  ( 
		    "1.3.6.1.4.1.789.2.1" 	=> "FILER",
		    "1.3.6.1.4.1.789.2.2" 	=> "NETCACHE",
		    "1.3.6.1.4.1.789.2.3" 	=> "CLUSTERED FILER",
		    "1.3.6.1.4.1.42.2.1.1" 	=> "SOLARIS",
		    "1.3.6.1.4.1.9.5.2" 	=> "SOLARIS"
		    );

# Cache the mount privilege hash
my %mountprivilege;
my %mount_options;

# Cache the nfs share count for nfs filesystems
my %nfsshare;

# This is a list of the TCP ports we care about
my %ports = (
	     time => '13',
	     ftp => '21',
	     ssh => '22',
	     telnet => '23',
	     smtp => '25',
	     dns => '53',
	     http => '80',
	     netbios => '139',
	     EMC1 => '1024',
	     EMC2 => '1025',
	     nfs => '2049'
	     );

# Organization Unique Identifiers.  The 1st 6 hex digits of a MAC address
# contains the OUI for the Manufacturer.
my %ouis = (
	    '00007D' => 'Sun Microsystems',
	    '0003BA' => 'Sun Microsystems',
	    '0020F2' => 'Sun Microsystems',
	    '080020' => 'Sun Microsystems',
	    '0060CF' => 'Alteon Networks',
	    '0002B3' => 'Intel Corporation',
	    '000347' => 'Intel Corporation',
	    '000423' => 'Intel Corporation',
	    '0007E9' => 'Intel Corporation',
	    '00207B' => 'Intel Corporation',
	    '009027' => 'Intel Corporation',
	    '00A0C9' => 'Intel Corporation',
	    '00AA00' => 'Intel Corporation',
	    '00AA01' => 'Intel Corporation',
	    '00AA02' => 'Intel Corporation',
	    '00D0B7' => 'Intel Corporation',
	    '00A098' => 'Network Appliance',
	    '00065B' => 'Dell Computer',
	    '000874' => 'Dell Computer'
	    );

my %telnetfps = (
		 'fffd18fffd1ffffd23fffd27fffd' => 'SUN',
		 'fffb01fffd18fffd23' => 'NETAPP',
		 'fffd18fffd20fffd23fffd27' => 'LINUX',
		 'fffd24' => 'HP',
		 );

#------------------------------------------------------------------------------------
# FUNCTION : localFilesystems
#
#
# DESC
# Returns a hash of hashes of the local file systems
#
# ARGUMENTS:
#
#------------------------------------------------------------------------------------
sub localFilesystems{
	
    return allFilesystems('LOCAL');

}


#------------------------------------------------------------------------------------
# FUNCTION : allFilesystems
#
#
# DESC
# Returns a array of hashes of filesystem metrics
#
# ARGUMENTS:
# LOCAL for local filesystems only, default  all filesystems
#
#------------------------------------------------------------------------------------
sub allFilesystems {

    return @Monitor::Storage::filesystemarray 
	if @Monitor::Storage::filesystemarray;
    
    my ( $localfsonly ) = @_;
    my %nfsservers;
    my %filesystems = Monitor::Storage::getFilesystems();
    
    # For each file system type
    for my $fstype( keys %filesystems ){
	
	# If argument is LOCAL then local filesystems only , skip nfs
	# This check works if filesystem is executed before Veritas
	# else Monitor::Storage::filesystemarray will have local filesystems
	# only
	next 
	    if $localfsonly 
	    and $localfsonly =~ /LOCAL/i 
	    and $fstype =~ /nfs/i;
		      
	#-------------------------------------------------------
	# Build the nfs server list and server information
	#-------------------------------------------------------
	if ( $fstype =~/nfs/i ){
	    
	    # build Unique list of nfs servers for fstype = nfs, 
	    # filesystem for nfs is server:filesystem
	    %nfsservers = 
		map{$_->{nfs_server} => 1} values %{$filesystems{$fstype}};
	    
	    #Get the vendor product for each of the nfs server , build a
	    #hash of hashes for nfs configuration
	    map{
		my %reslt = getServerDesc($_);
		$nfsservers{$_} = \%reslt;
	    } keys %nfsservers;

	}
	
	#------------------------------------------------------
	# Loop and push each file system metrics
	#------------------------------------------------------
	for my $fsref ( values %{$filesystems{$fstype}}){
	    
	    my %nfs;
	    
	    # Get the nfs(vendor,product,server) hash if filesystem nfs
	    if ( $fsref->{fstype} =~ /nfs/i ){
		
		$fsref->{nfs_privilege} = getMountPrivilege($fsref->{mountpoint});
		$fsref->{nfs_exclusive} = getNFSShare($fsref->{filesystem});
		
		%nfs = %{$nfsservers{$fsref->{nfs_server}}} if $nfsservers{$fsref->{nfs_server}};
		
	    }
	  	
	    # Get the mount options for the filesystem
	    $fsref->{mount_options} = get_mount_options($fsref->{mountpoint});

	    # Get inode for local (non nfs)  filesystems
	    # Skip if filesystem cant be seen on the host
	    $fsref->{inode} = getinode($fsref->{filesystem}) or next if $fsref->{fstype} !~ /nfs/i;

	    # Check if the filesystem is based on another filesystem
	    # the filesystem has to be a regular file or directory
	    $fsref->{mounttype} = 'FILESYSTEM_BASED'
		if $fsref->{filesystem}
		and -e $fsref->{filesystem}
		and ( -f $fsref->{filesystem} or -d $fsref->{filesystem} )
		and $fsref->{fstype} !~ /nfs/i;

	    # Get inode for the mountpoint	    
	    $fsref->{mountpointinode} = getinode($fsref->{mountpoint}) or next;
	    
	    # Generate a unique key for each record , < 128
	    $fsref->{key} = 
		substr($fsref->{mountpoint},0,120).'-'.@Monitor::Storage::filesystemarray;

	    # Copy values from the nfs hash array
	    for my $key ( keys %nfs ){ 
		
		$fsref->{$key} = $nfs{$key};
		
	    }
	    
	    push @Monitor::Storage::filesystemarray,$fsref;
	    
	}
    }
		    
    return @Monitor::Storage::filesystemarray;
		    
}



#------------------------------------------------------------------------------------
# FUNCTION : getNFSFilesystems
#
#
# DESC
# Returns a array nfs Filesystems with nfs server vendor , product and filesystem mount privileges
# and share count
#
# ARGUMENTS:
#
#------------------------------------------------------------------------------------
sub getNFSFilesystems ( ) {

    return @Monitor::Storage::NFSfilesystems
	if @Monitor::Storage::NFSfilesystems;
        
    # from the list of all filesystems
    for my $fsref( allFilesystems ){
	
	# only the nfs filesystems
	next unless $fsref->{fstype} =~ /nfs/i;
	
 	#------------------------------------------------------
	# Loop and push each file system metrics
	#------------------------------------------------------	    
	push @Monitor::Storage::NFSFilesystems,$fsref;
	
    }
    
    return @Monitor::Storage::NFSFilesystems;
    
}


#------------------------------------------------------------------------------------
# FUNCTION : getServerVendor
#
#
# DESC
# Assumes the servers snmp agent is listening on port 161 , requests info in the public 
# community
# Returns a hash list of vendor and product 
#
# Default timeout 5 secs ,reduced to 1 secs
# Default retries 1 ,increased to 2 
#
# ARGUMENTS:
# nfs server Name or address
#
#------------------------------------------------------------------------------------

sub getServerVendor($){
 
    my %result;
    my ( $hostname ) = @_;

    return unless $hostname;
    
    my ($session, $error)=
	Net::SNMP->session(
			   -hostname	=>	$hostname,
			   -community   =>	'public',
			   -port	=>	161,
			   -timeout	=>	1,
			   -retries	=>	2
			   );
 
    warn "WARN:Failed opening SNMP session for $hostname $error \n" 
	and return if not $session;	
 
    for my $key ( keys %snmpoid ) {
  
	my $response = $session->get_request($snmpoid{$key});
  
	if ( not $response ){
	    $session->close();
	    warn "WARN: SNMP get $key from $hostname ".$session->error().",SNMP agent no response \n" 
		and return ;
	}
	
	$result{$key} = $response->{$snmpoid{$key}};
    }
 
    $session->close();

    return (nfs_vendor => getVendor($result{vendor}) , nfs_product => getProduct($result{product}));
}


#---------------------------------------------------------------------------------------
# Enterprise MIBS
#1.3.6.1.4.1.789 	=> NETWORK APPLIANCE
#1.3.6.1.4.1.42 	=> SUN
#1.3.6.1.4.1.9 		=> CISCO
#
# FUNCTION :	getProduct
#
# DESC
# Return the Product that matches the OID returned my sysObjectId
#
# ARGUMENTS
# OID returned by the sysObjectId 
#
#---------------------------------------------------------------------------------------

sub getProduct($){
		     
    warn "WARN: OID null in getProduct \n" 
	and return unless $_[0];
		     
    return uc ($_[0]) 
	if not defined $productoid{$_[0]};
		     
    return $productoid{$_[0]};
}


#---------------------------------------------------------------------------------------
# FUNCTION :	getVendor
#
# DESC
# Return the Standard Vendor string that matches the desc returned my sysDescr
#
# ARGUMENTS
# sysDescr 
#
#---------------------------------------------------------------------------------------
sub getVendor($) {

    warn "WARN: Arg null in getVendor \n" 
	and return unless $_[0];

    return 'NETAPP' if $_[0] =~ /NetApp/i;
    return 'SUN' if $_[0] =~ /Sun/i;
			 
    return uc $_[0];
}



#---------------------------------------------------------------------------------------
# FUNCTION :	getMountPrivilege
#
# DESC
# Return a hash array of the filsystem and mount privilege for that filesystem
#
# ARGUMENTS
# mountpoint
#--------------------------------------------------------------------------------------
sub getMountPrivilege($){
			 
    warn "WARN: Arg null in getMountPrivilege \n" and return unless $_[0];
			 
    # Cache the results the first time
    if  ( not keys %mountprivilege ){
	
	get_mount_options($_[0]) unless keys %mount_options;
		
	# Execute mount -v twice so it gives a complete 
	# list of mounted filesystems 
	for my $mount_point( keys %mount_options ){
	    
	    my @cols = split /\s+/,$mount_options{$mount_point};
	    
	    warn "DEBUG: mount option $mount_options{$mount_point} not well formatted, unable to read mount privilege\n" and next unless @cols > 5;
	    
	    if  ( $cols[5] =~ /write|rw/i ) {
		
		$mountprivilege{$mount_point} = 'WRITE';
		next;		
	    }
	    
	    $mountprivilege{$mount_point} = 'READ';
	    
	}
    }
    
    warn "WARN: Mount Privilege not found for $_[0] \n" and return unless $mountprivilege{$_[0]};
			 
    return $mountprivilege{$_[0]};
}


#---------------------------------------------------------------------------------------
# FUNCTION :	get_mount_options
#
# DESC
# Return a hash array of the filsystem and mount options for that filesystem
#
# ARGUMENTS
# mountpoint
#--------------------------------------------------------------------------------------
sub get_mount_options($){
			 
    warn "WARN: Arg is null in get_mount_options \n" and return unless $_[0];
			 
    # Cache the results the first time
    if  ( not keys %mount_options ){
	
	# Execute mount -v twice so it gives a complete 
	# list of mounted filesystems 
	my @dummy = runSystemCmd("mount -v",120);
	for ( runSystemCmd("mount -v",120) ){
	    
	    chomp;
	    my @cols = split;

	    warn "DEBUG: mount option $_ not well formatted, unable to parse values , skipping \n" and next unless @cols > 2;
	    
	    $mount_options{$cols[2]} = $_;
	    
	}
    }
    
    warn "WARN: Mount options not found for $_[0] \n" and return unless $mount_options{$_[0]};
			 
    return $mount_options{$_[0]};
}



#---------------------------------------------------------------------------------------
# FUNCTION :	getNFShare
#
# DESC
# Return number of hosts that mount this filesystem
#
# ARGUMENTS
# NFS filesystem in the format server:filesystem
#---------------------------------------------------------------------------------------
sub getNFSShare($){
			  
    warn "WARN: Arg null in getNFSShare \n" 
	and return unless $_[0];
		       
    my ($server,$filesystem) = split/\s*:\s*/,$_[0];

    # Remove the trailing '/'
    # Linux df adds this character, but showmount does not
    # so the match always fails below.
    $filesystem =~ s/\/$//;
		       
    return $nfsshare{$server}{$filesystem} 
    if defined $nfsshare{$server}{$filesystem};
		       
    for ( Monitor::Storage::runShowmount($server) ){
			
	chomp;

	$nfsshare{$server}{( split /\s*:\s*/ )[1]}++;
			
    }
		       
    warn "WARN: Share not found for $_[0] \n" 
	and return 0 
	unless $nfsshare{$server}{$filesystem};
		       
    return $nfsshare{$server}{$filesystem};
}

#---------------------------------------------------------------------------------------
# FUNCTION :    openTcpSocket
#
# DESC
# Create and return a tcp socket handle
#
# ARGUMENTS
# Hostname and port number
#---------------------------------------------------------------------------------------
sub openTcpSocket( $$ )
{
	my ($host,$port) = @_;

	my $socket = IO::Socket::INET->new
	(
    		PeerAddr => $host,
    		PeerPort => $port,
    		Proto    => "tcp",
    		Type     => SOCK_STREAM,
		Timeout  => 2
	) or return;

	return $socket;
}

#---------------------------------------------------------------------------------------
# FUNCTION :    getServerDesc
#
# DESC
# Return the description of a given server.  Currently limited to Vendor name and if
# SNMP is active, Product type.
# NOTE: Nfs rpc calls do not provide enough distinguishing information to be a single
# reliable source for determining the vendor of a remote host.  Other checks such as the 
# ones used currently (telnet scan, http banner grab, arp, etc.) would have to be used in
# addition to the rpc calls.  The complexity of developing and maintaining an rpc call
# program did not provide enough added benefit to be worthwhile.
#
# ARGUMENTS
# Hostname
#---------------------------------------------------------------------------------------
sub getServerDesc($)
{
	my $hostname = $_[0];
	my $output;
	my %nfs;

	return unless $hostname;
	
	# This is the list of "scores" that will be used to determine the vendor.
	# As metrics are run, the score will be incremented or decremented and
	# the Vendor with the highest score at the end is our best guess.
	my %vendors = (
		SUN => '0',
		NETAPP => '0',
		EMC => '0',
		LINUX => '0',
		HP => '0'
	);

	# Check the HTTP port
	my $socket = openTcpSocket($hostname,$ports{http});
	if ($socket) {
      		print $socket "GET \/ HTTP\/1.0\n\n";

	      	for (<$socket>) {
		      	$vendors{LINUX}++ if /^Server:.*linux/i;
	            	$vendors{NETAPP}++ if /^Server:.*netapp/i;
	            	$vendors{NETAPP}-- if /^Server:.*apache/i;
	            	$vendors{EMC}-- if /^Server:.*apache/i;
	      	}
	      	close ($socket);
	}

	# Check the FTP port , +2 for emc and netapp
	$socket = openTcpSocket($hostname,$ports{ftp});
	if ($socket) {
      		print $socket "quit\n\n";
		for (<$socket>) {
			$vendors{LINUX}++ if /linux/i;
			$vendors{NETAPP} +=2 if /netapp/i;
			$vendors{SUN}++ if /sunos/i;
			$vendors{EMC} +=2 if /emc/i;
		}
		close ($socket);
	}

	# Check the Telnet port
	$socket = openTcpSocket($hostname,$ports{telnet});
	if ($socket) {
		my $buff;
		my $bytes = sysread($socket, $buff, 14);
      		if($bytes) {
			my $bin = unpack("H28",$buff);
			if (exists $telnetfps{$bin}) {
				$vendors{$telnetfps{$bin}}++;
			}
		}
		close($socket);
	}


	# Showmount
        $output = runSystemCmd("showmount -e $hostname");
        if ($output) {
        	if ($output =~ /\/vol\/vol0/i) {
                	$vendors{NETAPP}++;
        	} else {
                	$vendors{NETAPP}--;
        	}

        	if ($output =~ /\/nas_d/i) {
                	$vendors{EMC}++;
        	}
	}

	# Arp
        my $arp;
        for (runSystemCmd("arp $hostname")) {
                $arp = $_ if /$hostname/i;
        }

        if ($arp and $arp !~ /no entry/i) {
        	$arp =~ m/(.{2}:.{2}:.{2}:)/;
		my $oui = $1;
        	$oui =~ s/://g;

        	if ($ouis{$oui}) {
        		$vendors{SUN}++ if $ouis{$oui} =~ /Sun Microsystems/i;
        		$vendors{NETAPP}++ if $ouis{$oui} =~ /Network Appliance/i;
        		$vendors{EMC}++ if $ouis{$oui} =~ /Alteon/i;
		}
	}

	# SNMP, +2 for netapp and emc
	my %result;
	my ($session, $error)=
	Net::SNMP->session(
		-hostname    =>      $hostname,
		-community   =>      'public',
		-port        =>      161,
		-timeout     =>      1,
		-retries     =>      1
	);

	if ($session) {

	    for my $key ( keys %snmpoid ) {
		
		my $response = $session->get_request($snmpoid{$key});
		
		if ( $response ){
		    
		    $result{$key} = $response->{$snmpoid{$key}};
		    
		    # Added to support the new OS detection framework
		    $vendors{LINUX}++ if $result{$key} =~ /linux/i;
		    $vendors{NETAPP} +=2  if $result{$key} =~ /netapp/i;
		    $vendors{SUN}++ if $result{$key} =~ /sunos/i;
		    $vendors{EMC} +=2 if $result{$key} =~ /emc/i;
		    $vendors{HP}++ if $result{$key} =~ /hpux/i;
		}
		
		# Get the product data from the snmp results
		$nfs{nfs_product} = getProduct($result{$key}) 
		    if 
		    $key =~ /product/i
		    and $result{$key};
		
	    }
	    
	    $session->close();

	}
	
	# Sort the vendors in the descending order of their score values
	my @sortedvendors = sort { $vendors{$b} <=> $vendors{$a} } keys %vendors;
	
	# If we have more than one vendor at the top score then
	# we have failed to accurately guess the vendor
	warn "WARN: Unable to determine Vendor for $hostname.\n" and 
	    return	    
	    if
	    $sortedvendors[0] 
	    and $sortedvendors[1] 
	    and $vendors{$sortedvendors[0]} == $vendors{$sortedvendors[1]};	
	
	# Store the successfuly guessed vendor
	$nfs{nfs_vendor} =  $sortedvendors[0] if $sortedvendors[0];
	
	return %nfs;
}

1;
