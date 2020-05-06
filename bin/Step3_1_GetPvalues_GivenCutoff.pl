#!/usr/bin/perl
=pod

=head2 Find all the p-values for all the subpathways from KEGG.
We need an exact FDR distribution based on all the p-values.

=head2 Input files

=over 1

=item *
P-value file (.pval file in fisherCorr/)

=item *
Its corresponding linearPath file (.linearPath)

=back

=head2 Output file

=over 1

=item *
only p-value column

=item * 
Command example. perl /Users/snam/Desktop/NCC2012/CorrBasedSubpathway/Dataset/GSE13861_GC/src/Step3_1_GetPvalues_GivenCutoff.pl -p /Users/snam/Desktop/NCC2012/DrSaraKim/RNASeqData20120306/CorrBasedApproach/KISTIOUTPUT20120320/fisherCorr/\*pval 

=item * 
Watch out -p option in command line. '\*pval' was used.



=back


=head2 History

=over 1 

=item *
Generated in 2012-03-28 (Copied from Step3_GetInformation.pl.deprecated and modified.)

=item *
File name "Step3_1_GetAll_pvalues.pl" was changed to " Step3_1_GetPvalues_GivenCutoff.pl"


=back


=cut



use strict ;
use lib '/var/www/software/pathome/lib' ; # '/home/seokjong/lib/perl5/site_perl' ;

use MMIA::Util ;
use Getopt::Long ;

my $pvalDir =  'aa' ;
# '/Users/snam/Desktop/NCC2012/CorrBasedSubpathway/Dataset/GSE13861_GC/GEO/fisherCorr/*pval' ;

my $linearPathDir = '/pwork01/seokjong/home_backup_darthvader/DrParkMaterial/tonamswish/non-metabolic_KEGG_LinearPath/'; # /Users/snam/Desktop/KISTI_proposal_2010/KEGG/non-metabolic_KEGG_SIF_GMT/' ; # almost the dir fixed.

my $p_cutoff = 0.05 ;

my $verbose = '';

my $myOptions = GetOptions (
				'pvalDir|p=s' => \$pvalDir ,
				'pathDir|l=s' => \$linearPathDir ,
				 'cutoff|c=f' => \$p_cutoff,
				'verbose|v' => \$verbose
			);










my @files = < $pvalDir > ;



foreach my $f ( @files ) {
	print STDERR $f,"\n";

	my $kgid = '';
	if ($f =~ /(hsa\d+)/) {
		$kgid = $1 ;
	}

	if( -z $f ) { next ; } 

	my $content = MMIA::Util::readLineByLineFormat ($f) ;
	my $f_path = $linearPathDir .  $kgid . '.linearPath' ; # nominal variable


	
	my $h_table = {} ;

	foreach my $i (@$content){

		if ($i =~ /beginId/){
			next ;
		}
		

		my ($beginId, $subId, $pval, $subLenC1, $subLenC2 ) = split /\t/ , $i ;
		if( $pval < $p_cutoff ) {
			$h_table->{$beginId}->{$subId} = [ $pval, $subLenC1, $subLenC2 ]  ;
			
			print $pval, "\n";

			# print join(' ',$kgid, $beginId, $subId, $pval),"\n";

		}
	}

}




