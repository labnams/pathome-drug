#!/usr/bin/perl
=pod

=head2 Find significantly correlated subpathways (p-value < 0.05) from KEGG 

=head2 Input files

=over 1

=item *
P-value files(.pval file in fisherCorr/)

=item *
Its corresponding linearPath file (.linearPath)

=item * 
Command example. perl /Users/snam/Desktop/NCC2012/CorrBasedSubpathway/Dataset/GSE13861_GC/src/Step3_1_GetPvalues_GivenCutoff.pl -p /Users/snam/Desktop/NCC2012/DrSaraKim/RNASeqData20120306/CorrBasedApproach/KISTIOUTPUT20120320/fisherCorr/\*pval 

=item * 
Watch out -p option in command line. '\*pval' was used.



=back

=head2 Output file

=over 1

=item *
KEGG_Pathway_ID

Entry-based subpathway (Forward direction)

Gene Symbol-based subpathway (Forward direction), p-value, group1_matched_subEdgeLen, group2_matched_subEdgeLen

=back



=head2 History

=over 1 

=item *
Generated in 2010-12-28

=item *
2012-04-05: original file name "Step3_GetInformation.pl" was changed to "Step3_3_GetInformation.pl".

=back

=cut




use strict ;

use lib '/var/www/software/pathome/lib' ; #  '/home/seokjong/lib/perl5/site_perl' ;

use MMIA::Util ;
use Getopt::Long ;


###Input parameter setting###
my $pvalDir = '' ;
# '/Users/snam/Desktop/NCC2012/CorrBasedSubpathway/Dataset/GSE13861_GC/GEO/fisherCorr/*pval' ;

my $linearPathDir = '/pwork01/seokjong/home_backup_darthvader/DrParkMaterial/tonamswish/non-metabolic_KEGG_LinearPath/'; # '/Users/snam/Desktop/KISTI_proposal_2010/KEGG/non-metabolic_KEGG_SIF_GMT/' ;  # almost the dir is fixed.

my $p_cutoff = 0.05 ;
#############################





my $verbose = '';
my $myOptions = GetOptions (
				'pvalDir|p=s' => \$pvalDir ,
				'pathDir|l=s' => \$linearPathDir,
				 'cutoff|c=f' => \$p_cutoff,
				'verbose|v' => \$verbose
			);





my @files = < $pvalDir > ;

foreach my $f ( @files ) {
	print STDERR $f,"\n";	

	my $kgid = '';
	if ($f =~ /(hsa\d+)/) {
		$kgid = $1 ;
		#print STDERR $kgid, "\n";
	}

	if( -z $f ) { next ; } 

	my $content = MMIA::Util::readLineByLineFormat ($f) ;
	my $f_path = $linearPathDir ."/".  $kgid . '.linearPath' ;


	
	my $h_table = {} ;
	foreach my $i (@$content){

		if ($i =~ /beginId/){
			next ;
		}
		

		my ($beginId, $subId, $pval, $subLenC1, $subLenC2 ) = split /\t/ , $i ;
		if( $pval < $p_cutoff ) {
			$h_table->{$beginId}->{$subId} = [ $pval, $subLenC1, $subLenC2 ]  ;
			#print STDERR $beginId,' ', $subId,' ', $pval,"\n";
		}


	}


	open(IN, $f_path) or die "cannot open a file $f_path\n";

	#print STDERR $f_path ,"\n";

	my $beginId = 0 ;
	my $gsSubpathId = 0 ;
	my $beginTitle = '';
	my $subpathTitle = '';
	my $store = [];

	my $outContents =[];

	while(<IN>){

		chomp ;


		if($_ =~ /^#BEGIN/) {

			$gsSubpathId = 0 ;
			$beginTitle = $_ ;
			next ;	
		} 

		if($_ =~ /^#END/) {

			if(scalar @$store > 0) {

				#print $beginTitle ,"\n";
				push @$outContents, $beginTitle ;

				foreach my $i (@$store) {

					my ($p, $bId, $gId) = @$i ;

					my $temp = $h_table->{$bId}->{$gId} ;
					
					#print join("\t",'F', $p, @$temp )   ,"\n";

					push @$outContents, join("\t", 'F', $p, @$temp) ;

				}

				#print $_, "\n";
				push @$outContents, $_ ;

			}


			$store = [] ;
			$beginId ++ ;
			next ;
		}


		if( exists ($h_table->{$beginId}->{$gsSubpathId}) ){
			#print STDERR '** ', $beginId, ' ', $gsSubpathId, "\n";
			push @$store, [$_, $beginId, $gsSubpathId ] ;

		}

		$gsSubpathId ++ ;



	}

	close(IN) ;


	if(scalar @$outContents > 0){

		print '#KEGG',"\t$kgid", "\n";

		print join("\n", @$outContents) ,"\n" ;
		print '#KEGGEND', "\n";



	}


}




