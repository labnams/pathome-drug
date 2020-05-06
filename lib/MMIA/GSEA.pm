package MMIA::GSEA ;

use strict ;
use lib  '/home/seokjong/lib/perl5/site_perl/MMIA' ;
use DBI ;
use POSIX ":sys_wait_h";
#use lib qw(./ /home/tonamswish/lib/perl5/site_perl/5.8.5 /home/tonamswish/lib/perl5/site_perl/5.8.5/i386-linux-thread-multi) ;
use Term::ProgressBar;
use Text::NSP::Measures::2D::Fisher::right ;
use Time::HiRes qw(gettimeofday);
use MMIA::Util ;

my $chipDir = '/xchip/projects/vdb';	
my %h_chipPlatform = () ;
$h_chipPlatform{ 'HG_U133_Plus_2' } = $chipDir . '/HG_U133_Plus_2.chip' ;
$h_chipPlatform{'HG_U133A' }    = $chipDir . '/HG_U133A.chip' ;
$h_chipPlatform{'HG_U133A_2'}   = $chipDir . '/HG_U133A_2.chip';
$h_chipPlatform{'HG_Focus'}     = $chipDir . '/HG_Focus.chip' ;
$h_chipPlatform{'HG_U133B'}     = $chipDir . '/HG_U133B.chip' ;
$h_chipPlatform{'HG_U95Av2'}    = $chipDir . '/HG_U95Av2.chip' ;
$h_chipPlatform{'HG_U95B'}      = $chipDir . '/HG_U95B.chip';
$h_chipPlatform{'HG_U95C'}      = $chipDir . '/HG_U95C.chip';
$h_chipPlatform{'HG_U95D'}      = $chipDir . '/HG_U95D.chip' ;
$h_chipPlatform{'HG_U95E'}      = $chipDir . '/HG_U95E.chip' ;
$h_chipPlatform{'Hu6800'}       = $chipDir . '/Hu6800.chip' ;
$h_chipPlatform{'RefSeq_human'} = $chipDir . '/RefSeq_human.chip' ;
$h_chipPlatform{'RefSeq_NP_Human'} = $chipDir . '/RefSeq_NP_Human.chip';
$h_chipPlatform{'Seq_Accession'} = $chipDir . '/Seq_Accession.chip';

my $pvalCutoff = 0.05 ;
my $fuxiaoSetMin = 1 ;
my $fuxiaoSetMax = 50000 ;

sub collapseIdsUsingMITChipFormatWithMappingInfo{
	##The first column in chipFile would be the same case with the elements in $a_Id
        my ($chipFile, $a_Id, $rcFile) = @_ ;
        my $h_map = importMITChipFormat( $chipFile ) ;
        my $h_rc = {} ;

        foreach my $id (@$a_Id){
                next unless ( exists($h_map->{ $id  }) ) ;

                my $a = $h_map->{ $id  } ;
                foreach my $j (@$a){

                        next if( uc($j) eq 'NA' ||  uc($j) eq '---') ;

                        $h_rc->{$j}->{$id} ++ ;
                }
        }
        return(-1) if(Util::isEmptyHash($h_rc) < 0) ;
        open(OUT, '>', $rcFile) or return (-1) ; ## error occurs, return an negative
	foreach my $k (keys(%$h_rc)){
		my $h_rc2 = $h_rc->{$k} ;
		print OUT join("\t",$k, join(' /// ',keys(%$h_rc2))),"\n";
	}
	close(OUT) ;
	sleep(0.1) ;
	return(1) ;
}

sub collapseIdsUsingMITChipFormat {
	##The first column in chipFile would be the same case with the elements in $a_Id
        ##Obtain elements in $a_id overlapped with $chipFile and store the result into $rcFile
        my ($chipFile, $a_Id, $rcFile) = @_ ;
        my $h_map = importMITChipFormat( $chipFile ) ;
        my $h_rc = {} ;

        foreach my $id (@$a_Id){
		next unless ( exists($h_map->{ $id  }) ) ;

                my $a = $h_map->{ $id  } ;
                foreach my $j (@$a){

			next if( uc($j) eq 'NA') ;
			next if( uc($j) eq '---') ; # Added in 20090127
                        $h_rc->{$j} ++ ;
                }
        }
	return(-1) if(Util::isEmptyHash($h_rc) < 0) ;
        open(OUT, '>', $rcFile) or return (-1) ; ## error occurs, return an negative
        print OUT  join("\n", keys(%$h_rc) );
        close(OUT) ;
        return(1) ;
}

sub importMITChipFormat{
	return Util::importMITChipFormat ( shift @_ ) ;
}

sub convertMITChipFormatEntryToHashKeyArrayValue {
	# input :  hash
        # ex) key : V$COUP_01, value : P10589 /// P41235
	# output : hash
	# ex) key : V$COUP_01, value : ['P10589', 'P41235'] 
	my $h_in = shift @_ ;
	my $h_out = {} ;
	foreach my $k (keys(%$h_in)){
		my $arr = [ split /\s\/\/\/\s/ , $h_in->{$k} ];
		$h_out->{$k} = $arr ;
	}
	return($h_out) ;

}

sub runMITGSEA{

	my ($cls, $gct, $gmx, $chipplatform, $reportDir ) = @_ ;
	my ($numC1, $numC2) = @{ Preprocessing::getNumOfSamplesForEachClassFromClsFormat ($cls) } ;
        my $permute = '';
	
	if($numC1 < 0 || $numC2 < 0){
		return(-1) ; # CLS file format error
	}	

        if( $numC1 > 2 && $numC2 > 2 ){ # phenotype based permutation (default MIT GSEA)
                $permute = 'phenotype' ;
        }else{ # gene_set based permutation
                $permute = 'gene_set' ;
        }

	return( runMITGSEAGivenPermutationInfo($cls, $gct, $gmx, $chipplatform, $reportDir , $permute) ); # $permute would be either 'phenotype' (default) and 'gene_set' 
}

sub runMITGSEA_deprecated20081206{ ## permute sample lables (columns), recommended

	my ($cls, $gct, $gmx, $chipplatform, $reportDir ) = @_ ;

	my $chip = $h_chipPlatform{$chipplatform} ;

	my $command = "/usr/bin/java -Xmx512m -cp /xchip/projects/xtools/gsea2.jar xtools.gsea.Gsea  -out $reportDir -res $gct  -gmx $gmx -cls $cls -permute phenotype -chip $chip > /dev/null 2>&1";
	
	my $countMax = 300 ;	
	my $progress = Term::ProgressBar->new({name  => 'GSEA processing', count => $countMax, ETA => 'linear' });
	my $i =  0 ;
	$progress->minor($i) ;
	my $commPid = open(COMM, '-|', $command) or return(-1);
	print 'MIT GSEA still processing ' ;	
	if ($commPid){	
		my $t0 = [ gettimeofday ]  ;
		my $kid  = -3;
		
		do{	
			if( Util::mitGSEATimer($t0, 60 ) ){
				print '<font color=red face=arial size=2>|</font>';
				sleep(1) ;
			}	
		
			$kid = waitpid($commPid, WNOHANG) ;
		}while $kid >= 0 ;
		print '<br />' ;
		$progress->update($countMax) ;
	
	}

	close(COMM) ;
	sleep(0.1) ;
	return(1) ;
}

sub runMITGSEAGivenPermutationInfo{
	my ($cls, $gct, $gmx, $chipplatform, $reportDir , $permute) = @_ ; # $permute would be either 'phenotype' (default) and 'gene_set' 
	
	my $chip = $h_chipPlatform{$chipplatform} ;

	my $command = "/usr/bin/java -Xmx512m -cp /xchip/projects/xtools/gsea2.jar xtools.gsea.Gsea -out $reportDir -res $gct  -gmx $gmx -cls $cls -permute $permute -chip $chip -set_min 9 > /dev/null 2>&1";
	
	my $countMax = 300 ;	
	my $progress = Term::ProgressBar->new({name  => 'GSEA processing', count => $countMax, ETA => 'linear' });
	my $i =  0 ;
	$progress->minor($i) ;
	my $commPid = open(COMM, '-|', $command) or return(-2);
	print 'MIT GSEA still processing ' ;	
	if ($commPid){	
		my $t0 = [ gettimeofday ]  ;
		my $kid  = -3;
		
		do{	
			if( Util::mitGSEATimer($t0, 60 ) ){
				print '<font color=red face=arial size=2>|</font>';
				sleep(1) ;
			}	
		
			$kid = waitpid($commPid, WNOHANG) ;
		}while $kid >= 0 ;
		print '<br />' ;
		$progress->update($countMax) ;
	
	}

	close(COMM) ;
	sleep(0.1) ;
	return(1) ;

}



sub runMITGSEAByGenePermutation{ ## permute gene lables (rows), recommended for the total number of samples < 7 in two classes

	my ($cls, $gct, $gmx, $chipplatform, $reportDir ) = @_ ;

	
	my $chip = $h_chipPlatform{$chipplatform} ;

	my $command = "/usr/bin/java -Xmx512m -cp /xchip/projects/xtools/gsea2.jar xtools.gsea.Gsea -out $reportDir -res $gct  -gmx $gmx -cls $cls -permute gene_set -chip $chip > /dev/null 2>&1";
	
	my $countMax = 300 ;	
	my $progress = Term::ProgressBar->new({name  => 'GSEA processing', count => $countMax, ETA => 'linear' });
	my $i =  0 ;
	$progress->minor($i) ;
	my $commPid = open(COMM, '-|', $command) or return(-1);
	print 'MIT GSEA still processing ' ;	
	if ($commPid){	
		my $t0 = [ gettimeofday ]  ;
		my $kid  = -3;
		
		do{	
			if( Util::mitGSEATimer($t0, 60 ) ){
				print '<font color=red face=arial size=2>|</font>';
				sleep(1) ;
			}	
		
			$kid = waitpid($commPid, WNOHANG) ;
		}while $kid >= 0 ;
		print '<br />' ;
		$progress->update($countMax) ;
	
	}

	close(COMM) ;
	sleep(0.1) ;
	return(1) ;
}


sub makeGSEAInputFiles{

	my $rawGSEAInputFile = shift @_ ;
	my $clsFile = $rawGSEAInputFile.'.cls' ;
	my $gctFile = $rawGSEAInputFile.'.gct' ;
	my $command = "perl /home/MMIA/WebServer/src/fromSipToCLS.pl --fname $rawGSEAInputFile > $clsFile";

	my $commPid = open(COMM1, '-|', $command) or die "cannot execute $command\n";
        my $kid  = -3;
        do{
                $kid = waitpid($commPid, WNOHANG) ;
        }while $kid >= 0 ;
        close(COMM1) ;

	$command = "perl /home/MMIA/WebServer/src/fromSipToGCT.pl --fname $rawGSEAInputFile > $gctFile";

        $commPid = open(COMM2, '-|', $command) or die "cannot execute $command\n";
        $kid  = -3 ;
       
	do{
                $kid = waitpid($commPid, WNOHANG) ;
        }while $kid >=0 ;

        close(COMM2) ;
	sleep(0.1);

	return(1) ;

}

sub getUnnecessaryProbesets{
	my $chip = shift( @_ ); # Affy chip platform table name prefix
        my $dsn_affy = 'DBI:mysql:database=Affy;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf';
        my $dbh_affy = DBI->connect($dsn_affy,'MMIA') or die $DBI::errstr;

        my $chipSeqType = $chip.'_Table_SeqType' ;
	my $sql = "select probeset from $chipSeqType where SeqType = \'Control sequence\'" ;
	my $sth_seqType = $dbh_affy->prepare($sql) ;
	$sth_seqType->execute() ;
	my $t_arr = $sth_seqType->fetchall_arrayref ;

	my $arr = [] ;
	foreach my $i (0 .. (scalar @$t_arr -1)){
		my $tt = $t_arr->[$i] ;
		push @$arr, $tt->[0] ;
	}
	$sth_seqType->finish;
	$dbh_affy->disconnect;
	return($arr) ;
}

sub affy2Entrez{  ## for hsa, mmu, rno mRNA affy array
	my $chip = shift( @_ ); # Affy chip platform table name prefix
	my $unnecessaryProbesets = getUnnecessaryProbesets($chip) ;
	my $dsn_affy = 'DBI:mysql:database=Affy;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf';
        my $dbh_affy = DBI->connect($dsn_affy,'MMIA') or die $DBI::errstr;

	my $chipEntrez = $chip.'_Table_Entrez' ;
	my $sql = "select probeset, entrez from $chipEntrez" ;
	my $sth_entrez = $dbh_affy->prepare($sql) ;
	$sth_entrez->execute ;
	my $t_arr = $sth_entrez->fetchall_arrayref() ;
	my $entrez = {} ;
	foreach my $i (0 .. (scalar @$t_arr -1)){
		my ($probeset, $t_entrez) = @{$t_arr->[$i]};
		my @t = grep {$_ eq $probeset} @$unnecessaryProbesets ;
		next if (scalar @t) ;
		$entrez->{$probeset} = $t_entrez  ;
	}
	$sth_entrez->finish;
	$dbh_affy->disconnect ;
	return($entrez) ;
}

sub array2Hash{
	my $arr = shift @_ ;
	my $h ;
	foreach my $i (@$arr){
		$h->{$i} ++ ;	
	}
	return $h ;
}

sub hash2Array{
	my $h = shift @_ ;
	my $arr ;
	foreach my $i (keys %$h){
		push @$arr, $i ;
	}
	return $arr ;
}

sub runFuxiaoKeggGSEA{
	my ($fileId, $outDir, $mRNASigGeneFile, $targetProbeSets, $chipPlatform) = @_ ;	      
	my $outFile = $outDir.'/'. $fileId  .'_fuxiaogsea' ;	
	my $pathwayTable = 'keggHsaGeneToPathway' ;
	my $pathwayNameTable = 'keggMapTitle' ;
##keggHsaGeneToPathway , hg_TargetScanS4_2_miRNATargetLocusLink
	my $mRNASigGenes = Util::readLineByLineFormat($mRNASigGeneFile) ; # sig. probesets
	my $affyProbeToEntrez = affy2Entrez($chipPlatform) ;
	
	my $h_npp = {} ; #npp
	my $h_np1 = {} ; #np1
	my $npp = 0 ;
	my $np1 = 0 ;

#
#                      2 by 2 table
#                     up. reg. mRNAs
#                  target    not(target)      total
#  TGF-beta       12(n11)                     23(n1p)
#not(TGF-beta)    
#  total          535(np1)                   3297(npp)
#

	# get npp 	
	foreach my $i (0 .. (scalar @$mRNASigGenes -1)){
		if(exists ($affyProbeToEntrez->{$mRNASigGenes->[$i]})){
			$h_npp->{$affyProbeToEntrez->{$mRNASigGenes->[$i]}}++ ; 
		}
	}

	# get np1
	my $h_mRNASigGenes = array2Hash($mRNASigGenes);
	foreach my $i (0 .. (scalar @$targetProbeSets -1)){
		my $affy = $targetProbeSets->[$i] ;
		if(exists ($affyProbeToEntrez->{$affy})){
			if(exists ($h_mRNASigGenes->{$affy})){
				my $entrez  = $affyProbeToEntrez->{$affy} ;
				$h_np1->{$entrez} ++ ; 
			}
		}
	}
	$h_mRNASigGenes = {} ; # dump memory
		

	my $dsn_path = 'DBI:mysql:database=Pathway;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf';
        my $dbh_path = DBI->connect($dsn_path,'MMIA') or die $DBI::errstr ;
	my $sql = "select pathway from $pathwayTable where gene = ?" ;
	my $sth_path = $dbh_path->prepare($sql)  or die $dbh_path->errstr ;
	my $selectedPath ;
	foreach my $entrez (keys(%$h_np1)){
		my $keggGene =  'hsa:' . $entrez   ;
		$sth_path->execute ($keggGene) ;
		my $rc = $sth_path->fetchall_arrayref() ;
		next if (scalar @$rc == 0);
		foreach my $j (@$rc){
			$selectedPath->{$j->[0]} ++ ;
		}	
	}
	$sth_path->finish;

	unless ($selectedPath){
		$dbh_path->disconnect ;
		# It should be assigned to error code
		print STDERR 'No available KEGG pathways for Fuxiao GSEA.',"\n"; 	
		return (-1) ;
	}


	$np1 = scalar keys (%$h_np1) ;
	$npp = scalar keys (%$h_npp) ;
	# get n1p, n11 for each pathway obtained from the above section
	$sql = "select gene from $pathwayTable where pathway = ?";
	$sth_path = $dbh_path->prepare($sql)  or die $dbh_path->errstr ;
	my $sql_title = 'select title from '. $pathwayNameTable . " where map = ?";
	my $sth_title = $dbh_path->prepare($sql_title) or die $dbh_path->errstr ;

	my $a_npp = hash2Array ( $h_npp ) ; 

	open(OUT,'>'. $outFile) or die "cannot open a file $outFile\n";
	foreach my $k (keys %$selectedPath){
		$sth_path->execute($k) ;
		my $rc = $sth_path->fetchall_arrayref() ;
		next if (scalar @$rc == 0) ;
		my $pathwayGenes = [] ;
		foreach my $m (@$rc){
			push @$pathwayGenes, removeKeggGenePrefix($m->[0]) ;
		}
		# get n1p = npp intersect pathway_geneEntries
		my $h_n1p= Util::getIntersection($a_npp,$pathwayGenes) ;
		my $n1p = scalar keys %$h_n1p ;
		
		# get n11 = n1p intersect np1
		my $a_n1p = hash2Array ($h_n1p) ;
		my $a_np1 = hash2Array ($h_np1) ;
		my $h_n11 =Util::getIntersection($a_n1p, $a_np1) ;
		my $n11 = scalar keys %$h_n11  ; 
		if ($n11 *  $n1p == 0) {
			#print STDERR "No test n11 $n11, n1p $n1p, np1 $np1, npp $npp\n";
			next ;
		}
		my $pval = getRightFisherTest($n11, $n1p, $np1, $npp ) ;
		if($pval < 0.05 && $pval >=0 ){
			my $mapName = '' ;
			if($k =~ /.*?(\d+)$/){
				$mapName = $1 ;
			}
			$sth_title->execute($mapName) ;
			my $rc_name = $sth_title->fetchrow_arrayref() ;
			my $mapTitle = $rc_name->[0] ;	
			#print OUT "pval $pval mapTitle $mapTitle  n11 $n11, n1p $n1p, np1 $np1, npp $npp\n";
			print OUT "$mapTitle,,,$n11,,,$n1p,,,$np1,,,$npp,,,$pval\n";
		}
	}
	close(OUT) ;
	$sth_title->finish ;
	$sth_path->finish ;
	$dbh_path->disconnect ;
	
}

sub getRightFisherTest{

	my ($n11, $n1p, $np1, $npp ) = @_ ;
	my $right_value = -1 ;	
	eval{
		$right_value = calculateStatistic( n11=> $n11,
					      n1p=> $n1p,
					      np1=> $np1,
					      npp=> $npp ) ;
	};
	if($@){ 
		# it should be assigned to Error code
		my $errorCode = getErrorCode() ;
    		#print STDERR $errorCode." - ".getErrorMessage();
		return (-1) ;
	}
  	
	return($right_value) ;
}

sub removeKeggGenePrefix {
	my $a = shift @_ ;
	my $rc = '' ;
	if($a  =~ /.*?:(\d+)/){
		$rc = $1 ;
	}
	
	return ($rc) ;
}


sub countBasedFuxiaoGSEAGivenNPPAndNP1Files{ # tsv format
	## Some entries in gmtFile is not contained in the nppFile.
        ## So, n1p set should be redefined by intersection between npp and gmtFile each gene set.
        ## It is assumed that np1($a_nplGenes) and nppFile ($a_nppGenes) be  already prepared properly.
	my ($gmtFile, $np1File, $nppFile , $outFname ,$n1pAndN11OutFile) = @_ ;

	#              up.predicted     up.non_pred     total
        # pathA          $n11                           $n1p(= intersection of each gene set(gmt) and npp)
        # non_pathA
        # total        $np1($a_nplGenes)                $npp     

        my $gmt = [] ;
	my $a_nplGenes  = [] ;  
	my $a_nppGenes = [] ;
        $gmt = Util::readLineByLineFormat($gmtFile) or return(-1) ;
	$a_nplGenes  = Util::readLineByLineFormat($np1File) or return(-2); #np1 gene entries
	$a_nppGenes = Util::readLineByLineFormat($nppFile) or return(-3) ; # npp gene entries
	my $npp = scalar(@$a_nppGenes) ;
	my $np1 = scalar(@$a_nplGenes) ;
	
	my $numList = 0 ;
	my $rc =  [] ;
	my $rc_n1p_n11 = [] ;
	my $numGmts = scalar @$gmt ;

	foreach my $i ( 0 .. ( $numGmts -1 ) ){

		my @t_a_gmt =  split /\t/, $gmt->[$i]  ; 
		next if (scalar @t_a_gmt < 3) ;

                my $a_gmt = [] ;
		eval{
			$a_gmt = [ @t_a_gmt[ 2 .. $#t_a_gmt ] ] ; 
		};
		if($@){
			next ;
		}
		next if(Util::isEmptyArray($a_gmt) < 0) ;
		
		#### getting n1p genes
		my $a_n1pGenes = [] ; # n1p gene entries
                my $a_One = [ @$a_nppGenes  ] ;
                my $a_Two = [ @$a_gmt ]  ;
                my $h_isect = Util::getIntersectionWithCaseOption ($a_One , $a_Two, 'i') ;
                if(Util::isEmptyHash($h_isect) < 0){
	        	next ;
                } else { 
			$a_n1pGenes = [ keys(%$h_isect)  ]; # n1p gene entries
                	$a_One = [] ; $a_Two = [] ; $h_isect = {} ; # dump memory
                }
		my $n1p = scalar @$a_n1pGenes ;


		#### getting n11 genes
		my $a_n11Genes = [] ;
		$a_One = [ @$a_n1pGenes ] ;	
		$a_Two = [ @$a_nplGenes ];
		$h_isect = Util::getIntersectionWithCaseOption ($a_One , $a_Two, 'i') ;
		if(Util::isEmptyHash($h_isect) < 0){
                        next ;
                } else {
			$a_n11Genes = [ keys(%$h_isect)  ]; # npp gene entries		
			$a_One = [] ; $a_Two = [] ; $h_isect = {} ; # dump memory
		}	
		my $n11 = scalar @$a_n11Genes ;		

		#### Right Fisher exact p-value
		if( ! ( $n1p >= $fuxiaoSetMin && $n1p <= $fuxiaoSetMax  ) ){ next ;}
                my $pval = getRightFisherTest($n11, $n1p, $np1, $npp ) ;
		next unless ($pval) ;
		
				

		if( $pval < $pvalCutoff && $pval >= 0 ){
			$numList ++ ;
			my $categoryName = $t_a_gmt[0] ;
			push @$rc,[ $categoryName, $n11, $n1p, $np1, $npp, $pval] ;
			push @$rc_n1p_n11 , [ $categoryName , $a_n1pGenes, $a_n11Genes ];
		}

	}
	return(-5) if (Util::isEmptyArray($rc) < 0) ;
	return(-6) if (Util::isEmptyArray($rc_n1p_n11) < 0) ;
	open(OUT, '>', $outFname) or return(-3) ;
	foreach my $i (@$rc){
		print OUT join("\t",@$i),"\n";
	}
	close(OUT) ;

	open(OUT, '>', $n1pAndN11OutFile) or return(-4) ;
	foreach my $i (@$rc_n1p_n11){
		my ($name, $a_n1p, $a_n11) = @$i ;
		my $n1pText = join(',', @$a_n1p) ;
		my $n11Text = join(',', @$a_n11) ;
		print OUT join("\t", $name, $n1pText, $n11Text),"\n";
	
	}
	close(OUT) ;

	return($numList) ; # return the number of sig. sets
}

sub countBasedGSEAVer2{
	### Watch out!! The function is used to microRNA GSEA.
	## It doesn't use MySql
	## The entries in the gmt file and gene file should follow same IDs.
	## npp should be properly obtained before the subroutine

	my ( $gmtFile , $genesFile , $fname , $fnameN11N1p , $npp ) = @_ ;  #  $geneFile corresponds to "np1".
	my $gmt = [] ;
	my $a_genes = [] ;
	$gmt = Util::readLineByLineFormat($gmtFile) or return(-1) ;
	$a_genes = Util::readLineByLineFormat($genesFile) or return(-2);
	my $numGmts = scalar @$gmt ;
	my $np1 = scalar(@$a_genes) ;

	my $numList = 0 ;
	my $rc = [] ;
	my $rcN11N1p = [] ;

	foreach my $i (0 .. ($numGmts -1 )){
		my @t_a_gmt =  split /\t/, $gmt->[$i]  ;
		my $a_gmt = [ @t_a_gmt[ 2 .. $#t_a_gmt ] ] ;
		my $h_isect = Util::getIntersectionWithCaseOption (  $a_gmt, $a_genes, 'i' );

		# Category means TF or Pathway or GO.
		#                      				2 by 2 table
		#                     				reg. miRNA/mRNA	
		#                  		selected_miRNA/mRNA    not(selected_miRNA/mRNA)         total
		# Category_A(GMT file)       	5(n11)                     				54(n1p)
		# not(Category_A)
		#  total                        17(np1)                   				696(npp)

		my $n11 = scalar( keys(%$h_isect) );
		my $n1p = scalar(@$a_gmt) ;
                if ($n11 *  $n1p == 0) {
                        #print STDERR "No test n11 $n11, n1p $n1p, np1 $np1, npp $npp\n";
                        next ;
                }
		if( ! ( $n1p >= $fuxiaoSetMin && $n1p <= $fuxiaoSetMax  ) ){ next ;}
                my $pval = getRightFisherTest($n11, $n1p, $np1, $npp ) ;
		next unless ($pval) ;
	
                if( $pval < $pvalCutoff && $pval >= 0 ){
			$numList ++ ;
			my $categoryName = $t_a_gmt[0] ;
			push @$rc,[ $categoryName, $n11, $n1p, $np1, $npp, $pval] ;
			my $t_n11 = join(',',  keys(%$h_isect))  ;
			my $t_n1p = join(',', @$a_gmt) ;  ;
	
			push @$rcN11N1p, [$categoryName,  $t_n11, $t_n1p ] ;
		}
		else{

		}
	}

	return(-4) if(Util::isEmptyArray($rc) < 0) ;
	open(OUT, '>', $fname) or return(-3) ;
	foreach my $i (@$rc){
		print OUT join(',',@$i),"\n";
	}
	close(OUT) ;
	open(OUT2, '>', $fnameN11N1p ) or return(-4) ;
	foreach my $i (@$rcN11N1p){
		print OUT2 join("\t", @$i), "\n";
	}
	close(OUT2) ;

	return($numList) ; # return the number of sig. sets

}

sub countBasedGSEA { 
	### Watch out!! The function is used to microRNA GSEA.
	## It doesn't use MySql
	## The entries in the gmt file and gene file should follow same IDs.
	## npp should be properly obtained before the subroutine

	my ($gmtFile , $genesFile, $fname, $npp ) = @_ ;  #  $geneFile corresponds to "np1".
	my $gmt = [] ;
	my $a_genes = [] ;
	$gmt = Util::readLineByLineFormat($gmtFile) or return(-1) ;
	$a_genes = Util::readLineByLineFormat($genesFile) or return(-2);
	my $numGmts = scalar @$gmt ;
	my $np1 = scalar(@$a_genes) ;

	my $numList = 0 ;
	my $rc = [] ;

	foreach my $i (0 .. ($numGmts -1 )){
		my @t_a_gmt =  split /\t/, $gmt->[$i]  ;
		my $a_gmt = [ @t_a_gmt[ 2 .. $#t_a_gmt ] ] ;
		my $h_isect = Util::getIntersectionWithCaseOption (  $a_gmt, $a_genes, 'i' );

		# Category means TF or Pathway or GO.
		#                      				2 by 2 table
		#                     				reg. miRNA/mRNA	
		#                  		selected_miRNA/mRNA    not(selected_miRNA/mRNA)         total
		# Category_A(GMT file)       	5(n11)                     				54(n1p)
		# not(Category_A)
		#  total                        17(np1)                   				696(npp)

		my $n11 = scalar( keys(%$h_isect) );
		my $n1p = scalar(@$a_gmt) ;
                if ($n11 *  $n1p == 0) {
                        #print STDERR "No test n11 $n11, n1p $n1p, np1 $np1, npp $npp\n";
                        next ;
                }
		if( ! ( $n1p >= $fuxiaoSetMin && $n1p <= $fuxiaoSetMax  ) ){ next ;}
                my $pval = getRightFisherTest($n11, $n1p, $np1, $npp ) ;
		next unless ($pval) ;
	
                if( $pval < $pvalCutoff && $pval >= 0 ){
			$numList ++ ;
			my $categoryName = $t_a_gmt[0] ;
			push @$rc,[ $categoryName, $n11, $n1p, $np1, $npp, $pval] ;
		}
		else{
			#$numList ++ ;
			#my $categoryName = $t_a_gmt[0] ;
			#push @$rc,[ $categoryName, $n11, $n1p, $np1, $npp, $pval] ;
		}
	}

	return(-4) if(Util::isEmptyArray($rc) < 0) ;
	open(OUT, '>', $fname) or return(-3) ;
	foreach my $i (@$rc){
		print OUT join(',',@$i),"\n";
	}
	close(OUT) ;

	return($numList) ; # return the number of sig. sets
}






##### mRNA specific functions
sub writeSubsetSIPFormat{
        my ($clsHeader, $sampleHeader, $geneNames, $TwoDExpressionMatrix, $outFile, $a_subsetGeneNames) = @_ ;
        my @rowIndex = () ;
        my $subsetGeneNames = GSEA::array2Hash ($a_subsetGeneNames) ;
        foreach my $i ( 0 .. (scalar @$geneNames -1 )){
                if( exists( $subsetGeneNames->{$geneNames->[$i]}) ){
                        push @rowIndex, $i ;
                }
        }

        $geneNames =  [ @$geneNames[@rowIndex]  ];
        $TwoDExpressionMatrix = [ @$TwoDExpressionMatrix[@rowIndex] ];

        Preprocessing::writeSIPFormatForCRANHCluster($clsHeader, $sampleHeader, $geneNames, $TwoDExpressionMatrix, $outFile, 0);
        return(1) ;
}


sub FuxiaoGSEAWithMITFileFormats{
	my ($gmtFile, $chipFile, $geneInputFile, $resultFile, $npp) = @_ ;


}



############## Test subroutines
sub TestCountBasedGSEA{
	print countBasedGSEA( '/home/MMIA/WebServer/GSEA/CoustomSigDB/hg18_constfbs_mirna.gmt', 'TestDat/127.0.0.1_1227218573_1242/mRNA_1227218573_1242_sig_down', 'tmp.txt' ,500) ;
}

sub TESTGSEA{
        my $command = "java -Xmx512m -cp /xchip/projects/xtools/gsea2.jar xtools.gsea.Gsea -res TMP/mRNA_1224704128_7510_gseaRawInput.gct -gmx /home/MMIA/WebServer/GSEA/MSigDB/c2.kegg.v2.5.symbols.gmt -cls TMP/mRNA_1224704128_7510_gseaRawInput.cls -chip HG_U133_Plus_2" ;
        my $commPid = open (COMM, '-|', $command) ;
	
       	my @tmp =<COMM> ;
	print STDERR 'GSEA split out ', scalar @tmp ; 
	my $kid  = -3;
        do{
                $kid = waitpid($commPid, WNOHANG) ;
		print 'kid ',$kid,"\n"; 
        } while $kid >= 0 ;
        close(COMM) ;
        return(1) ;
}



1;
