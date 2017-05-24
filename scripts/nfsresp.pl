# 
# Copyright  (c) 2001,2002  Oracle Corporation All rights reserved 
#
#  $Id: nfsresp.pl,v 1.3 2003/05/20 01:15:26 ajdsouza Exp $ 
#
#
# NAME  
#	 nfsresp.pl
#
# DESC 
#	Get the ping response time for each nfs host sharing filesystems with this host
#
#
# NOTES
#
#
# MODIFIED	(MM/DD/YY)
# ajdsouza	05/19/03 - Created
#
#
#


require v5.6.1;

use strict;
use warnings;

#-------------------------------------------------------------------------
# Clean Environment at compile time before the libraries are initialized
#-------------------------------------------------------------------------
BEGIN{
    
        for ( keys %ENV ){
                delete $ENV{$_} 
		unless $_ =~ 
		    /^(HOME|EM_TARGET_NAME|EM_TARGET_TYPE|EM_TARGET_USERNAME|EM_TARGET_PASSWORD|EM_TARGET_ADDRESS|PERL5LIB|PATH)$/;
        }
     
}

use Monitor::Storage;
use Monitor::Utilities;

my %nfsservers;
my @NFSFilesystems =  Monitor::Storage::getNFSFilesystemMetrics;
my $timer = 60;

for my $fsref ( @NFSFilesystems ) {
 
    # to leave out Non netapp vendors based of argv1
    # next unless $fsref->{vendor} =! /netapp/i;

    #to leave out read only mounts
    # next unless $fsref->{privilege} =! /write/i;

    # build Unique list of nfs servers for fstype = nfs, 
    # filesystem for nfs is server:filesystem
    $nfsservers{$fsref->{nfs_server}} = $fsref;
    
}

# Save the old target name
my $old_em_target_name = $ENV{EM_TARGET_NAME} if $ENV{EM_TARGET_NAME};

for my $nfsserver ( keys %nfsservers ) {
    
    $nfsserver =~ s/^\s+|\s+$//;
    
    next unless $nfsserver;
    
    # call osresp here setting the EM_TARGET_NAME to $_
    $ENV{EM_TARGET_NAME} = $nfsserver;
    
    for ( runSystemCmd('perl osresp.pl') ){
	
	chomp;
	
	s/^\s+|\s+$//;
	
	next unless $_ and $_ =~ /^em_result=/;
	
	$_ =~ s/^em_result=//;
	
	next unless $_;
	
	my @cols = split /\|/;
	
	next unless @cols == 2;
	
	# skip after printing one row for a nfs server
	$nfsservers{$nfsserver}->{ping_results} = $cols[0];
	$nfsservers{$nfsserver}->{ping_status} = $cols[1] and last;
	
    }
    
}

# Restore the old target name
$ENV{EM_TARGET_NAME} = $old_em_target_name if $old_em_target_name;

for my $nfsserver ( keys %nfsservers ) {
    
    $nfsserver =~ s/^\s+|\s+$//;

    next unless $nfsserver and $nfsservers{$nfsserver};
    
    $nfsservers{$nfsserver}->{nfs_vendor} = 'UNKNOWN' unless $nfsservers{$nfsserver}->{nfs_vendor};

    # Ping results = timeer and host status down if no ping results or invalid ping results
    $nfsservers{$nfsserver}->{ping_results} = $timer and
	$nfsservers{$nfsserver}->{ping_status} = 0 
	unless 
	exists $nfsservers{$nfsserver}->{ping_results} and 
	exists $nfsservers{$nfsserver}->{ping_status} and
	$nfsservers{$nfsserver}->{ping_results} =~ /\d+/ and
	$nfsservers{$nfsserver}->{ping_status} =~ /\d+/;    
        
    print "em_result=$nfsserver|$nfsservers{$nfsserver}->{nfs_vendor}|$nfsservers{$nfsserver}->{ping_results}|$nfsservers{$nfsserver}->{ping_status}\n";
    
}
