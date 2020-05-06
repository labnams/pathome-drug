#!/usr/bin/perl
=pod

=head2 Identify corr agreed subpathways

=head1 Inputs

=over

=item *
Expression file : Non-redundant expression file in the SIP format (refer to 2_MakeNRExprData.pl)

=item *
Class 1 name : e.g., c1

=item *
Fisher transformed correlation distributions for c1, c2, and null_class
The fisher transformed correlation changes to it absoluete value 
Test t-test.

=back


=head1 Outputs

=over

=item *
beginId(0-based):gssubpathid(0-based):c1_correlation_edges(reverse order):c2_correlation_edges(reverse order)

=back


=head2  History

=over

=item *
2012-05-27 Serious Bug Find. And then updated.


=back


=cut



use strict ;

use lib '/var/www/software/pathome/lib' ; # '/home/seokjong/lib/perl5/site_perl' ;

use MMIA::Util ; # Modified
use MMIA::Preprocessing ;
use Getopt::Long ;
use Data::Dumper ;
use Statistics::Descriptive;

my $verbose = '';
my $f_linearpaths =  '' ;
	#	  '/Users/snam/Desktop/KISTI_proposal_2010/KEGG/non-metabolic_KEGG_SIF_GMT/hsa04510.linearPath' ;
my $f_nrSip =  '' ;
    # '/Users/snam/Desktop/NCC2012/CorrBasedSubpathway/Dataset/GSE13861_GC/GEO/GSE13861.nr.sip' ;
    # ''; #'../DATA/GSE4107_nr.sip' ;
my $c1_name = 'c1'; # e.g., class 1 name: c1 or g1




my $myOptions = GetOptions (
                                'linearPaths|l=s' => \$f_linearpaths,
				'class1|c=s' => \$c1_name,
				'nrSip|n=s' => \$f_nrSip,
                                'verbose' => \$verbose
                           ) ;


if( !  -e $f_linearpaths ) { exit(0) ; }
if( -z $f_linearpaths) { exit(0); } 

my $beginId = 0  ; # Entry based subpath Id
my $gsSubpathId  = 0 ; # Gene Symbol based subpath Id

my $sipContent = MMIA::Util::readLineByLineFormat ( $f_nrSip );
my $exprMat = MMIA::Preprocessing::transform1DSipFormatTo2DMatrix ( $sipContent ) ;
my $geneSymbols = MMIA::Preprocessing::getGeneNames ($sipContent) ;

my ($cls1idx, $cls2idx) = @{ MMIA::Preprocessing::getSampleIdsForEachClassFromSIPGivenClass1 ( $f_nrSip , $c1_name ) };

my $h_c1_exprArr = make2DExprMatToGeneHash ($exprMat, $geneSymbols, $cls1idx) ;
my $h_c2_exprArr = make2DExprMatToGeneHash ($exprMat, $geneSymbols, $cls2idx) ;

my $linearpaths = MMIA::Util::readLineByLineFormat ($f_linearpaths ) ;








my $beginHeader = '';

print join(':','#BeginId', 'subpathId', 'c1_fisherCorr', 'c2_fisherCorr', 'c1_subNumEdges', 'c2_subNumEdges'),"\n" ;

foreach my $p (@$linearpaths) {

        chomp ($p) ;

        if( $p=~ /^#BEGIN/ ) {
                $beginHeader = $p ;
                $beginHeader =~ s/BEGIN/BEGIN\tF/ ;# forward order , entry-based pathway
                #print STDERR $beginHeader,"\t$beginId", "\n";


		$gsSubpathId = -1 ;
                next ;
        }
        if ($p =~ /^#END/) {
                $beginHeader = '';
                #print STDERR '#END', "\n";
		$beginId ++ ;
                next ;
        }

	$gsSubpathId ++ ;

        my $subpath = [ split /\s+/, $p ] ;


        my $nodes = [] ;
        my $edges = [] ;


        foreach my $i (0 .. ( scalar @$subpath -1 ) ) {

                if ($i % 2 == 0) {
                        push @$nodes , $subpath->[$i] ;
                } else {
			if ($subpath->[$i] eq 'ac' ){
                        	push @$edges , 1 ;
			}else{
				push @$edges, -1 ;
			}
                }

        }


	my $breakInd = 0;
	foreach my $n (@$nodes) {
                if(!  exists ( $h_c1_exprArr->{$n} ) ) {
                        $breakInd ++ ;
                        last ;
                }
	}	
	if ($breakInd > 0) {
		#print STDERR "$p:$beginId:$gsSubpathId\t",'error_MissingExpr',"\n";
		next ;
	}else{
		$breakInd = 0 ;
	}


        my $reverse_edges = [reverse @$edges] ;
        my $reverse_nodes = [reverse @$nodes] ;


	#my @gnodes = grep { $_ eq 'VEGFB' or $_ eq 'PDGFRA'} @$reverse_nodes ;
	#if( scalar @gnodes < 2 ) {next ;}

	### For class 1
	my $reverse_corr_c1 = [] ;
	foreach my $j (0 ..(scalar @$reverse_nodes - 2 )){

		my $gj1 = $h_c1_exprArr->{$reverse_nodes->[$j]} ;
		my $gj2	= $h_c1_exprArr->{$reverse_nodes->[$j+1]} ;

		my $r = MMIA::Util::calCorrCoef ($gj1, $gj2) ;
		
		if (abs $r <= 1 ){	
			push @$reverse_corr_c1 ,  MMIA::Util::fisherTransformationOfCorr( $r );
		}else{
			$breakInd ++ ;
			#print STDERR "$p:$beginId:$gsSubpathId\t",'error_c1CorrInfoUndef',"\n";
			last ;
		}
	}
	if($breakInd > 0 ){
		#print STDERR "$p:$beginId:$gsSubpathId\t",'error_MissingCorrInfoC1',"\n";

		next ;
	}else{
		$breakInd = 0 ;
	}


	### For class 2
	my $reverse_corr_c2 = [] ;
	foreach my $j (0 ..(scalar @$reverse_nodes - 2 )){

		my $gj1 = $h_c2_exprArr->{$reverse_nodes->[$j]} ;
		my $gj2	= $h_c2_exprArr->{$reverse_nodes->[$j+1]} ;

		my $r = MMIA::Util::calCorrCoef ($gj1, $gj2) ;

		if (abs $r <= 1 ){	
			push @$reverse_corr_c2 ,  MMIA::Util::fisherTransformationOfCorr( $r );
		}else{
			$breakInd ++ ;
			#print STDERR "$p:$beginId:$gsSubpathId\t",'error_c2CorrUndef',"\n";
			last ;
		}

	}
	if($breakInd > 0 ){
		#print STDERR "$p:$beginId:$gsSubpathId\t",'error_MissingCorrInfoC2',"\n";
		next ;
	}else{
		$breakInd = 0 ;
	}

	### For null class 
	my $reverse_corr_null = [] ;
	foreach my $j (0 ..(scalar @$reverse_nodes - 2 )){
	
		my $gj1 = [ @{ $h_c2_exprArr->{$reverse_nodes->[$j]} }, @{ $h_c1_exprArr->{$reverse_nodes->[$j]} } ] ;
		my $gj2	=  [ @{ $h_c2_exprArr->{$reverse_nodes->[$j+1]} }, @{ $h_c1_exprArr->{$reverse_nodes->[$j+1]} } ] ;

		my $r = MMIA::Util::calCorrCoef( $gj1, $gj2 ) ;

		if( abs $r <= 1) {
			push @$reverse_corr_null,   MMIA::Util::fisherTransformationOfCorr( $r ) ; 
		}else{
			$breakInd ++ ;
			#print STDERR "$p:$beginId:$gsSubpathId\t",'erro_NullCorrUndef',"\n";
			last ;
		}

	}
	if($breakInd > 0 ){
		print STDERR "$p:$beginId:$gsSubpathId\t",'error_MissingCorrInfoCNull',"\n";
		next ;
	}else{
		$breakInd = 0 ;
	}




	### Check maximum correlation length for class 1
	if(scalar @$edges != scalar @$reverse_corr_c1){
		print STDERR "$p:$beginId:$gsSubpathId\t",'error_-1_corrC1',"\n";
		exit(-1) ;
	}
	my $c1_subNumEdges = 0 ;
	#print STDERR 'c1 ' ;
	foreach my $j ( 0 .. (scalar @$reverse_edges - 1) ){
		my $prior =  $reverse_edges->[$j] ;
		my $real = $reverse_corr_c1->[$j] ;	

		if( $prior * $real > 0 ){
			#print STDERR $real, ' ', $prior, ' :: ' ;
			$c1_subNumEdges ++ ;
		}else{
			#print STDERR " :: ";
			last ;
		}
	}



	### Check maximum correlation length for class 2
	if( scalar @$edges != scalar @$reverse_corr_c2 ) {
		print STDERR "$p:$beginId:$gsSubpathId\t",'error_-2_corrC2',"\n";
		exit(-2) ;
	}
	my $c2_subNumEdges = 0 ;
	#print STDERR 'c2 ';
	foreach my $j ( 0 .. (scalar @$reverse_edges - 1) ){
		my $prior =  $reverse_edges->[$j] ;
		my $real = $reverse_corr_c2->[$j] ;	

		if( $prior * $real > 0 ){
			#print STDERR $real, ' ', $prior, ' :: ' ;
			$c2_subNumEdges ++ ;
		}else{
			#print STDERR " :: ";
			last ;
		}
	}





	### LRT 
	my $minSubNumEdges = ( $c1_subNumEdges > $c2_subNumEdges ) ? $c2_subNumEdges : $c1_subNumEdges ;

	if($minSubNumEdges == 0 ) {
		#print STDERR "$p:$beginId:$gsSubpathId\t","error_noMatchedSubEdegs\n" ; #No matched subEges in terms of fisher transformed correlation between c1 and c2";
		next ;
	}

	my $c1_sub_corr = [ @$reverse_corr_c1 [0 .. ($minSubNumEdges-1)] ] ;
	my $c2_sub_corr = [ @$reverse_corr_c2 [0 .. ($minSubNumEdges-1)] ] ;
	my $cnull_sub_corr = [ @$reverse_corr_null [ 0 .. ($minSubNumEdges-1) ] ] ;	


	### t-test when minSubNumEdges >= 3 	
	if($minSubNumEdges >= 3){
		my $c1_str = join("\t", @$c1_sub_corr) ;
		my $c2_str = join("\t", @$c2_sub_corr) ;




		####### Modified in 2012-05-27#######
		print join(':',  $beginId, $gsSubpathId, $c1_str, $c2_str, $c1_subNumEdges, $c2_subNumEdges) , "\n";
		####### #######





	} else {
		#print STDERR join(':', $p, $beginId, join(' ', @$subpath),  $gsSubpathId,'minSubNumLen3'),"\n";
	}
	


}






sub make2DExprMatToGeneHash {
	my $twoDExprMat = shift @_ ;
	my $genes = shift @_ ;
	my $idx = shift @_ ;

	my $h_exprArr = {} ;

	foreach my $i ( 0 .. ( scalar @$genes - 1  ) ){

		my $row = $twoDExprMat->[$i] ;
		$h_exprArr->{ $genes->[$i] } = [ @$row [ @$idx ] ]   ;
	}

	return $h_exprArr ;
}
