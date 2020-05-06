=pod

=head2 Make a Cytoscape SIF format from Step3_3_sig_pval_subpath.txt.

=head2 Input files

=over 1

=item *
Step3_3_sig_pval_subpath.txt

=item *
Command example:  perl Step5...pl -f Step3_3_sig_pval_subpath.txt 


=back


=head2 Output file

=over 1

=item *
SIF file

=back

=head2 History

=over 1

=item *
2012-04-05: The original file name "Step6_parse_sig_pval_subpath_To_SIF.pl" was changed to "Step5_parse_sig_pval_subpath_To_SIF.pl".

=item *
2012-06-04: A serious bug was found.

=back

=cut





use strict ;

use lib '/var/www/software/pathome/lib' ;  # '/home/seokjong/lib/perl5/site_perl' ;
use Getopt::Long ;


######[Input parameters]#########
my $f = ''; # 'Step3_3_sig_pval_subpath.txt' ;
#################################






my $verbose = '';
my $myOptions = GetOptions (
				'sigPaths|f=s' => \$f ,
				'verbose|v' => \$verbose
			);




my $keggid = '' ;
my $nPath = '' ; # numeric path



if($f eq '') {print STDERR "Input file not defined.\n" ; exit(0) ;}





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


	### Modified in 2012-06-04
	my $minEdges = $a_line[$#a_line ] > $a_line[$#a_line - 1] ? $a_line[$#a_line - 1] : $a_line[$#a_line] ;	

	

	########## all information  #######
	# print join(' // ', $keggid, $nPath, $line), "\n";


	my @a_Path = split /\s+/ , $line ;
	shift @a_Path ;
	pop @a_Path ;
	pop @a_Path ;
	pop @a_Path ;

	########### Modified in 2012-06-04
	my $subLen =  $minEdges * 2 + 1  ;	
	my $startIndex =  scalar @a_Path  - $subLen ;
	#print STDERR $startIndex ,' ', $#a_Path , "\n";
	############ END


	foreach my $ii ( $startIndex .. ($#a_Path -2 )) {


		if ($ii % 2 == 1) { next ; }


		my $ii2 = $ii + 2 ;	


		if ($ii2 > $#a_Path) {
			last ;
		}


		my $i = $a_Path [$ii] ;
		my $etype = $a_Path [$ii + 1]  ;
		my $i1 = $a_Path [$ii2 ];
		my $e = '' ;


		if ($etype eq 'ac') {
			$e = 'ac'  ;
		}

		if ($etype eq 're') {
			$e = 're' ;
		}
		$e = $e . '_' . $keggid  ;
		 
		print join("\t", $i, $e, $i1) , "\n";
	}

	
	###################################

}


close(INPUT) ;




