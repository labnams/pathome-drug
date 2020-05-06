#!/usr/bin/perl
=pod

=head2 Extract a detailed subpath info of the sig. subpathways, and then combine their q-value 

=head2 Input files

=over 1

=item *
Step3_3_sig_pval_subpath.txt

=item *
FDR distribution file: Step3_2_sorted_pval_qval_table_for_Step3_1

=item *
Command example:  perl Step4_make..pl -f Step3_3_sig_pval_subpath.txt -d Step3_2_sorted_pval_qval_table_for_Step3_1


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
2012-04-05: The original file name "Step4_parse_sig_pval_subpath_To_FDRInput_AllInfo.pl" was changed to "Step4_make_sig_pval_subpath_AllInfo_with_qval.pl".

=item *
2012-04-09: pval-qval mapping improved by hash function and sprintf


=back

=cut









use strict ;
use lib  '/var/www/software/pathome/lib' ; # '/home/seokjong/lib/perl5/site_perl' ;

use Getopt::Long ;


###########[Input parameters]#####################
my $f = '' ; # 'Step3_3_sig_pval_subpath.txt' ;
my $fdrDistn_f = ''; # 'Step3_2_sorted_pval_qval_table_for_Step3_1' ;
###################################################








my $verbose = '';
my $myOptions = GetOptions (
				'sigPaths|f=s' => \$f ,
				 'fdr|d=s' => \$fdrDistn_f,
				'verbose|v' => \$verbose
			);



if($f eq '' or $fdrDistn_f eq '') {print STDERR 'No input files defined.', "\n"; exit(0);}






########[BEGIN: Read the FDR distribution file ($fdrDistn_f)]##############
my $temph_pval_qval = {} ;
my $h_pval_qval = {};

open(FDR, $fdrDistn_f) or die "cannot open a file $fdrDistn_f\n";
while(<FDR>){

	chomp ;

        my ($p, $q) = split /\s+/ ;

	my $p_format = sprintf ("%.16f", $p) ;

        $h_pval_qval->{$p_format} = $q ;

}
close(FDR) ;


$temph_pval_qval = {} ;
########[END]###########



my $keggid = '' ;
my $nPath = '' ;



open(INPUT, $f) or die "cannot open a file $f\n";

while ( <INPUT> ) {

	chomp ;
	my $line = $_ ;

	if(/^#KEGG/) {

		if( $line =~ /(hsa\d+)/ ) {

			$keggid = $1 ;	
		}

		next ;

	}

	if(/^#BEGIN/) {

		my $temp = [ split /\t/, $line ] ;
		shift @$temp ;
		$nPath = join ("\t", @$temp) ;	
		next ;

	}


	if( /^#END/ ) {

		$nPath = '';

		next ;

	}


	if( /^#KEGGEND/) {
		$keggid = '' ;
	}



	my @a_line = split /\t/ , $line ;
	my $a_len = scalar @a_line ;
	my $pval = $a_line[ $#a_line - 2 ] ;
	my $p_format = sprintf("%.16f", $pval) ;
	my $qval =  qvalGivenPval($h_pval_qval, $p_format) ;

	my $line_qval = $line. "\t" . $qval ;	

	########## all information 
	print join(' // ', $keggid, $nPath, $line_qval), "\n";
	##########################




}


close(INPUT) ;





sub qvalGivenPval {
        my ($h_fdr, $p) = @_ ;


	if( exists( $h_fdr->{$p} )) {
		#print STDERR "here-1","\n";
		return $h_fdr->{$p} ;
	}

	my $k = '' ;

	foreach  $k (sort {$a <=>$b} keys %$h_fdr) {
		if( $p <= $k ) {
			#print STDERR "here-2","\n";
			return $h_fdr->{$k} ;
		}
	}
	
	#print STDERR "here-3","\n";

	return  $h_fdr->{$k} ;
}


