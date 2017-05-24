#!/usr/local/git/perl/bin/perl

use strict;
use warnings;

sub getcomb($$){

    my ($n,$r) = @_;

    my $nval = 1;

    for my $val ($r+1..$n){
	$nval *= $val;
    }
     
    return $nval unless $n-$r;

    for my $val (1..($n-$r)){
	$nval /= $val;
    } 

    return $nval;
    
}


# Create permutations for a string of n chars
my @permlist;
sub createperm($$);

sub createperm($$){

    my ($listref,$level) = @_;

    my $hosts = @$listref;
	
    if ($level == $hosts){

        for my $start (0..@$listref-1){

	    next if grep{ $_ == $start }@permlist;

            push @permlist,$start;

            for ( @permlist ){

		print "\nNO value for $_  HOst list size $hosts \n" and next unless @{$listref}[$_];
                print @{$listref}[$_];

            }

            print "\n";

            pop @permlist;

        }
    }
    else{

        for my $newposition (0..@$listref-1){
		
	    next if grep{ $_ == $newposition }@permlist;

            push @permlist,$newposition;

            createperm($listref,$level+1);

	    pop @permlist;

        }

    }

}

my @hostlist;

sub createcomb($$$$);

sub createcomb($$$$){
    
    my ($hosts,$listref,$position,$level) = @_;
    
    my $sizeoflist = @$listref;
    
    if ($level == $hosts){
	
	for my $start ($position..($sizeoflist-1)){
	  
	 #   push @hostlist,$listref->[$start];

	    $hostlist[$level-1] = $listref->[$start];
	
#	    for ( @hostlist ){
		
#		print "$_";
		
#	    }
	    
#	    print "\n";  
	    createperm(\@hostlist,1);

	    pop @hostlist;
	    
	}
    }
    else{
	
	for my $newposition ($position..($sizeoflist-($hosts-$level))){
	    
#	    push @hostlist, $listref->[$newposition];
	    $hostlist[$level-1] = $listref->[$newposition];

	    createcomb($hosts,$listref,$newposition+1,$level+1);  	    

#	    pop @hostlist;
	    
	}
	
    }
       
}



my @a=qw(s t o r m o n 1);

my $n = @a;
my $total;

for my $hosts($n..$n){
    
    my $combs = getcomb($n,$hosts);
    
#    print "$n c $hosts = $combs \n";
    
    createcomb($hosts,\@a,0,1);

    $total += $combs;
}


#print "Total $n = $total \n";
