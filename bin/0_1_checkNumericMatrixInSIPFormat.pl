#!/usr/bin/perl

use strict ;

use lib '/var/www/software/pathome/lib' ; # '/home/seokjong/lib/perl5/site_perl' ;

use MMIA::Preprocessing ;
use MMIA::Util ;
use Getopt::Long ;


my $sipFile = '/pwork01/seokjong/home_backup_darthvader/DrParkMaterial/Materials/GSE13861.sip';
my $log2 = 1; # set to 1('-l' option) if data is already log2 transformed
my $sipFileChecked = '0_1_formatChecked.sip' ;
my $verbose = 0;

GetOptions("sip|i=s" => \$sipFile,
	"log2|l" => \$log2,
	"outsip|o=s" => \$sipFileChecked,
	"verbose|v" => \$verbose);

if( ! $sipFile || ! -r $sipFile ){
	die "ERROR_000001 : cannot read SIP file";
}

### Read a sip file
my $content = MMIA::Preprocessing::readSipFile ($sipFile) ;
my $min_samples_per_class = 3 ; # check minimum number of samples per group
my $total_samples = 0 ; # whether or not total samples are equal throughout genes
my $limit_class = 2 ; # The number of classes should be 2.
my $p_count = 1e-10 ; # pseudo count in linear scale 0

my $arr_rc = []; 
foreach my $i (0 .. (scalar @$content -1)) {
	my $num_line = $i + 1 ;

	my @elms = split /\t/ , $content->[$i] ;

	if($i == 0 ){
		$total_samples = scalar @elms -1 ; # update the actual number of samples

		my %tmph = () ;
		
		foreach my $j ( 1 .. $#elms ) {

			$tmph{$elms[$j]} ++ ;
			
		}

		if( scalar keys %tmph  != $limit_class ) {
			print "ERROR_000003 : the first line error: the number of classes should be two.\n";
			
			exit(-1) ;
		}

		my ($c1_num, $c2_num) = values %tmph ;
		#print STDERR "total: $total_samples ; c1_num : $c1_num ; c2_num : $c2_num \n";
		
		if( $c1_num < $min_samples_per_class or $c2_num < $min_samples_per_class ){
			print "ERROR_000004 : the first line error: the minimun number of samples per group should be 3.\n";
			exit(-2) ;	
		}

		push @$arr_rc , $content->[$i] ;
 
	} elsif ($i == 1 ) {
		if( scalar @elms -1 != $total_samples ){
			print "ERROR_000005 : the line number $num_line has the different number of columns.\n";
			exit(-3) ;
		}
		
		push @$arr_rc , $content->[$i] ;

	} else{
		if( scalar @elms -1 != $total_samples ){
			print "ERROR_000005 : the line number  $num_line has the different number of columns.\n";
			exit(-3) ;
		}


		foreach my $k ( 1 .. $#elms ){


			if($log2 == 1 ) { # already log2 transformed
				if( MMIA::Util::getnum( $elms[$k] ) ){
					;
				} else {
					print "ERROR_000006 : non-numerals exist in the line number $num_line.\n";
					exit(-4) ;
				}
				
			} else { # linear scaled
				unless( MMIA::Util::getnum( $elms[$k] ) ){
					print "ERROR_000006 : non-numerals exist in the line number $num_line.\n";
					exit(-4) ;
				}

				if ( $elms[$k] < 0 ) {
					print "ERROR_000007 : negative value is not allowed in linear scale value in the line number $num_line. Please transform your data into non-negative values or remove the rows having negative values from your dataset.\n";	
					exit(-5) ;
				} elsif ( $elms[$k] == 0) {
					$elms [$k ] = $p_count ;
				} else {
					;
				}

			}

		}
		push @$arr_rc, join("\t", @elms) ;
	
	}
	
}

open(OUT, ">$sipFileChecked") or die "cannot open $sipFileChecked\n";

foreach my $i (@$arr_rc){
	print OUT $i, "\n";
}

close (OUT); 

print "SUCCESS_0_1_checkNumericMatrixInSIPFormat.pl\n";
# MMIA::Util::getClassDescriptionFromSIPFile ($sipFile) ;
