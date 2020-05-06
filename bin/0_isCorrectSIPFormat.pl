#!/usr/bin/perl

use strict ;
use lib '/var/www/software/pathome/lib' ; # '/home/seokjong/lib/perl5/site_perl' ;

use MMIA::Util qw() ;
use Getopt::Long ;


my $sipFile = 'tempsip.sip' ;
my $verbose = 0 ;

GetOptions("sip|i=s" => \$sipFile,
	"verbose|v" => \$verbose ) ;



if( ! $sipFile || ! -r $sipFile ) {


	print "ERROR: SIP file format does not exist.\n"  ;

	
	exit(-1) ;

} 

my $rc = MMIA::Util::isFileChecked ($sipFile ) ;


if ($rc < 0) {


	print  "ERROR_000001 : SIP file format is not correct. Please check your file.\n";


} else {



	print  "SUCCESS: SIP file format check. \n";

}

