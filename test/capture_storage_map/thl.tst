#!/bin/sh

PERL5LIB=$SRCHOME/emagent/sysman/admin/scripts:$SRCHOME/perl/lib;export PERL5LIB

$SRCHOME/perl/bin/perl tst.pl $1


