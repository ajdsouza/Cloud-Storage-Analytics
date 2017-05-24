#  $Header: emd_common.pl 25-aug-2004.17:28:10 kduvvuri Exp $
#
# Copyright (c) 2001, 2004, Oracle. All rights reserved.  
#
#    NAME
#      emd_common.pl - <one-line expansion of the name>
#
#    DESCRIPTION
#      This file contains common subroutines.
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#      kduvvuri  08/25/04 - fix bug 3848591. 
#      jsutton   04/15/04 - Clean up warnings 
#      kduvvuri  10/28/03 - use EMSTATE instead of AGENTSTATE as the dir for 
#                           perl tracing.(b3221051) 
#      jsoule    08/29/03 - fix non-existant procedure call 
#      xxu       03/05/03 - add EMAGENT_isPerl*Enabled check
#      vnukal    12/16/02 - making trace directory state-only install aware
#      pbantis   12/07/02 - Fix agent tracing
#      xxu       11/25/02 - do not fail if cannot write to trace file
#      xxu       11/04/02 - EMD->EMAGENT
#      xxu       10/24/02 - add more tracing levels
#      xxu       06/25/02 - remove /usr/local/bin/perl
#      aaitghez  08/07/01 - filename issues.
#      aaitghez  08/05/01 - adding dbms_application registration function.
#      xxu       07/31/01 - add trace support
#      xxu       05/29/01 - move system dependent code into semd_common.pl
#      xxu       05/21/01 - cut over from tcl
#      xxu       05/21/01 - Creation
# 
#

use strict;
use Oraperl;
use FileHandle;
use File::Basename;

my $EMAGENT_PERL_TRACE_LEVEL_DEBUG  = 1;
my $EMAGENT_PERL_TRACE_LEVEL_INFO   = 2;
my $EMAGENT_PERL_TRACE_LEVEL_WARN   = 3;
my $EMAGENT_PERL_TRACE_LEVEL_ERROR  = 4;
# parses <STDIN> 
# reads any line of thge form <name>=<var>
# and returns a string of the form: "$<name>=<value>;$<name>=<value>;"
sub get_stdinvars
{
    my %r;
    while(<STDIN>)
    {
	if(/(.*)=(.*)/)
	{
	    if($2 eq "__BeginProp__")
	    {
		while(<STDIN>)
		{
		    if($_ ne "__EndProp__\n")
		    {
			$r{"$1"} .= "$_";
		    }
		}
	    }
	    else
	    {
		$r{"$1"} = "$2"; 
	    }
	}
    }
    return %r;
}

#registers a perl script with the database it is connected to
sub register_metric_call
{
    my ($lda) = @_;
    my $sql = q{
        BEGIN  
            dbms_application_info.set_module('Oracle Enterprise Manager.Metric Engine', '' ); 
        END;
    };
    &ora_do($lda, $sql) || warn "error registering - ora_do : $ora_errno: $ora_errstr\n";;
}		

# get the database version
# currently, valid DB version will be "8", "8i", "9i"
sub get_db_version
{
    my ($lda) = @_;

    my $sql = "select banner from v\$version where banner like 'Oracle%'";
    my $cur = &ora_open ($lda, $sql) || warn "ora_open ($lda, $sql): $ora_errno: $ora_errstr\n";
    my @fetch_row = &ora_fetch($cur);
    &ora_close($cur) || warn "ora_close($cur): $ora_errno: $ora_errstr\n";

    my $db_version = substr($fetch_row[0], 6, 2);
    $db_version =~ s/\s//g;

    return $db_version;
}

# get the database startup time
sub get_db_up_time
{
    my ($lda) = @_;

    my $sql = "select TO_CHAR(STARTUP_TIME, 'MM/DD/YYYY/HH24/MI/SS') from v\$instance";
    my $cur = &ora_open ($lda, $sql) || warn "ora_open ($lda, $sql): $ora_errno: $ora_errstr\n";
    my @fetch_row = &ora_fetch($cur);
    &ora_close($cur)  || warn "ora_close($cur): $ora_errno: $ora_errstr\n";

    my $db_up_time = $fetch_row[0];

    return $db_up_time;
}

# This subroutine will be used to retrive data from a file.
# The data in the file must be saved through save_last_sample()
sub retrieve_last_sample
{
    my ($fn) = @_;

    my $last_time;
    my $db_up_time;
    my %last_value;

    open (INPUT, $fn) || warn "Could not open file $fn: $!\n";

    while (<INPUT>) {
        my $i = 0;
        my @last_record = split(':', $_);
        $last_time = $last_record[$i++];
        $db_up_time = $last_record[$i++];
        for ( ; $i <= $#last_record; $i++ ) {
            my @d = split ('=', $last_record[$i]);
            $last_value{$d[0]} = $d[1];
        }
    }

    close (INPUT);

    return ($last_time, $db_up_time, %last_value);
}

# This subroutine will be used to save the current data into a file.
# Those data can be retrieved through retrieve_last_sample()
sub save_last_sample
{
    my ($fn, $now, $db_up_time, %value) = @_;

    open (OUTPUT, ">$fn") || die "Could not open file $fn to write: $!\n";

    my $record = $now;
    $record = $record . ":$db_up_time";
    my $name;
    foreach $name (keys %value) {
        $record = $record . ":$name=$value{$name}";
    }

    print OUTPUT $record;
    close (OUTPUT);
}

#
# trace error info for EMD perl scripts
#
sub EMD_PERL_ERROR
{
    my ($message) = @_;

    # always write the error message
    EMD_PERL_TRACE ("ERROR: ", $message);
}

#
# trace warning info for EMD perl scripts
#
sub EMD_PERL_WARN
{
    my ($message) = @_;

    if ( $ENV{EMAGENT_PERL_TRACE_LEVEL} ne "" ) {
        # get the current trace level
        my $trace_level = $ENV{EMAGENT_PERL_TRACE_LEVEL};

        # only write the message if the current trace level is DEBUG or INFO or WARN
        if ( $trace_level <= $EMAGENT_PERL_TRACE_LEVEL_WARN ) {
            EMD_PERL_TRACE ("WARN: ", $message);
        }
    }
}

#
# trace normal info for EMD perl scripts
#
sub EMD_PERL_INFO
{
    my ($message) = @_;

    if ( $ENV{EMAGENT_PERL_TRACE_LEVEL} ne "" ) {
        # get the current trace level
        my $trace_level = $ENV{EMAGENT_PERL_TRACE_LEVEL};

        # only write the message if the current trace level is DEBUG or INFO
        if ( $trace_level <= $EMAGENT_PERL_TRACE_LEVEL_INFO ) {
            EMD_PERL_TRACE ("INFO: ", $message);
        }
    }
}

#
# trace debug info for EMD perl scripts
#
sub EMD_PERL_DEBUG
{
    my ($message) = @_;

    if ( defined($ENV{EMAGENT_PERL_TRACE_LEVEL}) && ($ENV{EMAGENT_PERL_TRACE_LEVEL} ne "") ) {
        # get the current trace level
        my $trace_level = $ENV{EMAGENT_PERL_TRACE_LEVEL};

        # only write the message if the current trace level is DEBUG
        if ( $trace_level == $EMAGENT_PERL_TRACE_LEVEL_DEBUG ) {
            EMD_PERL_TRACE ("DEBUG: ", $message);
        }
    }
}

#
# write the trace message into file emd_perl.trc
# the default tracing directory will {EMDROOT}/sysman/log/
# users can specify their own directory by setting {EMAGENT_PERL_TRACE_DIR}
# the default maximum size of the trace file is 5M.
# users can change that number by setting {EMAGENT_PERL_TRACE_FILESIZE}
#
sub EMD_PERL_TRACE
{
    my ($level, $message) = @_;

    # get the trace file with the full path
    my $trace_file;
    my $backup_trace_file;
    if ( $ENV{EMAGENT_PERL_TRACE_DIR} ne "") {
        $trace_file = $ENV{EMAGENT_PERL_TRACE_DIR} . "/emagent_perl.trc";
        $backup_trace_file = $ENV{EMAGENT_PERL_TRACE_DIR} . "/.emagent_perl.trc";
    } else {
	if ( $ENV{EMSTATE} eq "" ) {
	    $trace_file = $ENV{EMDROOT} . "/sysman/log/emagent_perl.trc";
	    $backup_trace_file = $ENV{EMDROOT} . "/sysman/log/.emagent_perl.trc";
	} else {
	    $trace_file = $ENV{EMSTATE} . "/sysman/log/emagent_perl.trc";
	    $backup_trace_file = $ENV{EMSTATE} . "/sysman/log/.emagent_perl.trc";
	}
	    
    }

    # open the trace file
    open (TRACE, ">>$trace_file") || return;

    # open the trace file succeed
    # get the current time
    my $cur_time = localtime;

    # get the script file name (without the directory)
    my $filename = basename ($0, "");

    # append the message
    print TRACE "$filename: $cur_time: $level $message\n";
    TRACE->autoflush(1);

    # close the trace file
    close (TRACE);

    # default the max trace file size is 5MB
    my $file_max_size = 5 * 1024 * 1024;
    if ( $ENV{EMAGENT_PERL_TRACE_FILESIZE} ne "" ) {
        $file_max_size = $ENV{EMAGENT_PERL_TRACE_FILESIZE} * 1024;
    }

    # rename the file to the backup file if the size is over the maximum size
    my $file_size = -s $trace_file;
    if ( $file_size > $file_max_size ) {
        if (!rename $trace_file, $backup_trace_file) {
            print "Could not rename file $trace_file : $!\n";
        }
    }
}

sub EMAGENT_isPerlDebugEnabled
{
    # get the current trace level
    my $trace_level = $ENV{EMAGENT_PERL_TRACE_LEVEL};
    return  $trace_level ne "" 
               && 
            $trace_level == $EMAGENT_PERL_TRACE_LEVEL_DEBUG; 
}

sub EMAGENT_isPerlInfoEnabled
{
    # get the current trace level
    my $trace_level = $ENV{EMAGENT_PERL_TRACE_LEVEL};
    return  $trace_level ne "" 
                && 
            $trace_level <= $EMAGENT_PERL_TRACE_LEVEL_INFO; 
}

sub EMAGENT_isPerlWarningEnabled
{
    # get the current trace level
    my $trace_level = $ENV{EMAGENT_PERL_TRACE_LEVEL};
    return  $trace_level ne "" 
                && 
            $trace_level <= $EMAGENT_PERL_TRACE_LEVEL_WARN; 
}

#
# trace error info for EMAGENT perl scripts
#
sub EMAGENT_PERL_ERROR
{
    my ($message) = @_;

    # always write the error message
    EMD_PERL_TRACE ("ERROR: ", $message);
}

#
# trace warning info for EMAGENT perl scripts
#
sub EMAGENT_PERL_WARN
{
    my ($message) = @_;

    if ( EMAGENT_isPerlWarningEnabled() ) {
        # only write the message if the current trace level is DEBUG or INFO or WARN
        EMD_PERL_TRACE ("WARN: ", $message);
    }
}

#
# trace normal info for EMAGENT perl scripts
#
sub EMAGENT_PERL_INFO
{
    my ($message) = @_;

    if ( EMAGENT_isPerlInfoEnabled() ) {
        # only write the message if the current trace level is DEBUG or INFO
        EMD_PERL_TRACE ("INFO: ", $message);
    }
}

#
# trace debug info for EMAGENT perl scripts
#
sub EMAGENT_PERL_DEBUG
{
    my ($message) = @_;

    if ( EMAGENT_isPerlDebugEnabled() ) {
        # only write the message if the current trace level is DEBUG
        EMD_PERL_TRACE ("DEBUG: ", $message);
    }
}

1;

