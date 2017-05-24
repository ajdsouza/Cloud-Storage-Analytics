#!/usr/local/git/perl/bin/perl 

require v5.6.1;
use strict;
use warnings;
use Cwd;
use File::Basename;
use File::Spec::Functions;
use File::Path;
use storage::sRawmetrics;
use storage::Register;
use Net::Ping;

use Data::Dumper;
$Data::Dumper::Indent = 2;

my $reslt = storage::Register::get_filesystem_metrics();

print Dumper($reslt);


