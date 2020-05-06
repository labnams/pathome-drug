#Human specific analysis package
package MMIA::HSA ;

use strict;
use lib  '/home/seokjong/lib/perl5/site_perl/MMIA' ;

use POSIX ":sys_wait_h";
use MMIA::GSEA ;
use MMIA::Util ;
use DBI ;
use MMIA::Preprocessing ;
use Term::ProgressBar ;

my $nppGeneSymbolInKgXref = 29370 ;
my $nppMirnaTf = 676 ;
my $nppMirnaMir2Disease  = 299 ;
my $mir2diseaseDb = '/home/tonamswish/GSEA/CoustomSigDBExternalDB/mir2disease_diseaseList.txt' ;
my $hsaKeggDb = '/home/tonamswish/GSEA/CoustomSigDBExternalDB/hsa_kegg_map_title.tab';

my $errorLog = 1 ;

### BEGIN : added in 2009/Mar/22
sub getRefSeqGivenProteins{ ## UCSC genome browser
	my $prot = shift @_ ;
	my $h_rc = {} ;

	my $inClause = "(\'". join("\' , \'", @$prot) . "\')" ;
        my $sql = "select distinct uniProt, refSeq from hgncXref where uniProt in ". $inClause ;
        my $dsn ="DBI:mysql:database=proteome;host=genome-mysql.cse.ucsc.edu;mysql_read_default_file=/etc/my.cnf";

        my $dbh = DBI->connect($dsn,'genome') or die $DBI::errstr ;
        my $sth = $dbh->prepare($sql) or die $dbh->errstr ;
        $sth->execute;
        my $rc_sth = $sth->fetchall_arrayref ;

        foreach my $i (@$rc_sth){
                my ($name, $id) = @$i ;
                if($id eq 'N') { next ;}
		
		if( exists($h_rc->{$name}) ){ 
			$h_rc->{$name} .= " /// $id" ;
		}else{
                	$h_rc->{$name} = $id ;
		}
        }

        $sth->finish ;
        $dbh->disconnect ;
	sleep(1) ;
        return($h_rc) ;
}
### END

### BEGIN : added in 2009/Apr/23
sub getGeneSymbolGivenProteins{ ## UCSC genome browser
	my $prot = shift @_ ;
	my $h_rc = {} ;

	my $inClause = "(\'". join("\' , \'", @$prot) . "\')" ;
        my $sql = "select distinct uniProt,  symbol  from hgncXref where uniProt in ". $inClause ;
        my $dsn ="DBI:mysql:database=proteome;host=genome-mysql.cse.ucsc.edu;mysql_read_default_file=/etc/my.cnf";

        my $dbh = DBI->connect($dsn,'genome') or die $DBI::errstr ;
        my $sth = $dbh->prepare($sql) or die $dbh->errstr ;
        $sth->execute;
        my $rc_sth = $sth->fetchall_arrayref ;

        foreach my $i (@$rc_sth){
                my ($name, $id) = @$i ;
                if($id eq 'N') { next ;}
		
		if( exists($h_rc->{$name}) ){ 
			$h_rc->{$name} .= " /// $id" ;
		}else{
                	$h_rc->{$name} = $id ;
		}
        }

        $sth->finish ;
        $dbh->disconnect ;
	sleep(1) ;
        return($h_rc) ;
}
### END




sub getTfNames{ ## my db 
        my $tfs = shift @_ ;
        my $h_rc = {} ;

        my $inClause = "(\'". join("\' , \'", @$tfs) . "\')" ;
        my $sql = "select distinct name, id from tfbsConsFactors where species=\'human\' and name in ". $inClause ;
        my $dsn ="DBI:mysql:database=hg18;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dbh = DBI->connect($dsn,'MMIA') or die $DBI::errstr ;
        my $sth = $dbh->prepare($sql) or die $dbh->errstr ;
        $sth->execute;
        my $rc_sth = $sth->fetchall_arrayref ;

        foreach my $i (@$rc_sth){
                my ($name, $id) = @$i ;
                if($id eq 'N') { next ;}
		
		### BEGIN : modified in 2009/Mar/22
		if( exists($h_rc->{$name}) ){ 
			$h_rc->{$name} .= " /// $id" ;
		}else{
                	$h_rc->{$name} = $id ;
		}
		### END
        }

        $sth->finish ;
        $dbh->disconnect ;
	sleep(0.1) ;
        return($h_rc) ;
}



sub getProbeSetsForPredictedTargetMRNAInHuman{

        my ($miRFile, $targetTable, $kgToChip) = @_ ;

        my $dsn_kg = "DBI:mysql:database=hg18;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dsn_target ="DBI:mysql:database=miRNATarget;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dbh_kg = DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
        my $dbh_target = DBI->connect($dsn_target,'MMIA') or die $DBI::errstr ;

        open(IN, $miRFile) or die "cannot open a file $miRFile\n";
        my @mirs = <IN>  ;
        chomp(@mirs) ;
        @mirs = grep {$_ !~ /^#/} @mirs  ;
        close(IN) ;

	my $inClause = "(\'" . join("\',\'", @mirs) . "\')" ;
        my $sth_target = $dbh_target->prepare("select distinct locusLink from $targetTable where miRNA in $inClause") or die $dbh_target->errstr ;
	my $rc_target = [];
	$sth_target->execute() ;
	$rc_target = $sth_target->fetchall_arrayref()  ;
	if(scalar @$rc_target == 0){
		$sth_target->finish() ;
		$dbh_target->disconnect ;
		$dbh_kg->disconnect ;
		return([]) ; ## no data
	}

	my $targetLocus = Util::getElemFrom2DArray($rc_target, 0) ;
	$inClause = "(\'" . join("\',\'", @$targetLocus) .  "\')" ;
	my $sth_kg = $dbh_kg->prepare("select distinct name from knownToLocusLink where value in $inClause") or die $dbh_kg->errstr ;
	$sth_kg->execute ;
	my $rc_kg = $sth_kg->fetchall_arrayref ;
	if(scalar @$rc_kg == 0){
		$sth_target->finish() ;
		$sth_kg->finish() ;
		$dbh_target->disconnect ;
                $dbh_kg->disconnect ;
                return([]) ; ## no data
	}

	my $targetKg =  Util::getElemFrom2DArray($rc_kg, 0) ;
	$inClause = "(\'" . join("\',\'", @$targetKg) .  "\')" ;
	my $sth_kgToChip = $dbh_kg->prepare("select distinct value from $kgToChip where name in $inClause") or die $dbh_kg->errstr ;
	$sth_kgToChip->execute ;
	my $rc_kgToChip = $sth_kgToChip->fetchall_arrayref ;
	if(scalar @$rc_kgToChip == 0){
		$sth_kg->finish() ;
		$sth_target->finish() ;
		$sth_kgToChip->finish ;
                $dbh_target->disconnect ;
                $dbh_kg->disconnect ;
		return([]) ; ## no data
	}	
	my $targetProbe = Util::getElemFrom2DArray($rc_kgToChip, 0) ;

	$sth_target->finish() ;
	$sth_kg->finish() ;
	$sth_kgToChip->finish() ;
	$dbh_target->disconnect ;
	$dbh_kg->disconnect ;
	sleep(0.1) ;
	return ($targetProbe) ;
}


sub getProbeSetsForPredictedTargetMRNAInHuman_deprecated20081122{

        my ($miRFile, $targetTable, $kgToChip) = @_ ;

        my $dsn_kg = "DBI:mysql:database=hg18;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dsn_target ="DBI:mysql:database=miRNATarget;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dbh_kg = DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
        my $dbh_target = DBI->connect($dsn_target,'MMIA') or die $DBI::errstr ;

        open(IN, $miRFile) or die "cannot open a file $miRFile\n";
        my @mirs = <IN>  ;
        chomp(@mirs) ;
        @mirs = grep {$_ !~ /^#/} @mirs  ;
        close(IN) ;

        my $sth_target = $dbh_target->prepare("select distinct locusLink from $targetTable where miRNA = ?") or die $dbh_target->errstr ;
        my $sth_kg =  $dbh_kg->prepare("select distinct name from knownToLocusLink where value = ? " ) or die $dbh_kg->errstr ;
        my $sth_kgToChip = $dbh_kg->prepare("select distinct value from $kgToChip where name =?") or die $dbh_kg->errstr ;


        my $countMax = scalar @mirs ;
        my $progress = Term::ProgressBar->new({name  => 'Finding target expression', count => $countMax, ETA => 'linear' });
        $progress->minor(0) ;

        my $probeSets = {} ;
        foreach my $mir_i (0 .. $#mirs){
                if($mirs[$mir_i] eq ''){ next;}
                $sth_target->execute($mirs[$mir_i]) ;
                my $mir_arr = $sth_target->fetchall_arrayref() ;
                foreach my $j (@$mir_arr){
                        my $locusVal = $j->[0] ;
                        $sth_kg->execute($locusVal);
                        my $kg_arr = $sth_kg->fetchall_arrayref() ;
                        foreach my $k (@$kg_arr){
                                my $kgName = $k->[0] ;
                                $sth_kgToChip->execute($kgName) ;
                                my $probeSet_arr = $sth_kgToChip->fetchall_arrayref() ;
                                foreach my $kk (@$probeSet_arr){
                                        $probeSets->{ $kk->[0] } ++ ;
                                }
                        }
                }

		if( $mir_i == int( $#mirs / 4 ) || $mir_i == int( $#mirs / 2 ) || $mir_i == int($#mirs * 3 / 4) ){
                	$progress->update($mir_i) ;
		}
        }
        $progress->update($countMax) ;

        $sth_target->finish() ;
        $sth_kg->finish() ;
        $sth_kgToChip->finish() ;

        $dbh_kg->disconnect ;
        $dbh_target->disconnect ;
	sleep(0.1) ;
        my $rc = [keys (%$probeSets) ] ;

        return($rc) ;

}

sub getKeggIDForFuxiaoKegg{
        my $h_rc = {} ;
        open(INPUT, $hsaKeggDb) or die "cannot open a file $hsaKeggDb\n";

        while(<INPUT>){
                chomp ;
		next if(/^\s{0,}$/) ;
                my @info = split /\t/ ;
                $h_rc->{$info[1]} = $info[0] ;
        }
        close(INPUT) ;

        return($h_rc) ;
}

sub countBasedGSEAMirnaTf{

	my ($gmtFile, $genesFile, $outFile) = @_ ;
	my $rc = GSEA::countBasedGSEA($gmtFile, $genesFile, $outFile, $nppMirnaTf ) ;
	return($rc) ; # number of sig gene sets or minus error code

}

sub countBasedGSEAMirnaTfVer2{

	my ($gmtFile, $genesFile, $outFile, $outFileN11N1p) = @_ ;
	my $rc = GSEA::countBasedGSEAVer2($gmtFile, $genesFile, $outFile,  $outFileN11N1p, $nppMirnaTf ) ;
	return($rc) ;

}

sub countBasedGSEAMir2Disease{

	my ($gmtFile, $genesFile, $outFile)  = @_ ;
	my $rc = GSEA::countBasedGSEA($gmtFile, $genesFile, $outFile, $nppMirnaMir2Disease) ;
        return($rc) ; # number of sig gene sets or minus error code

}

sub countBasedGSEAMir2DiseaseVer2{
	
	my ($gmtFile, $genesFile, $outFile, $outFileN11N1p) = @_ ;	
	my $rc = GSEA::countBasedGSEAVer2($gmtFile, $genesFile, $outFile,  $outFileN11N1p,  $nppMirnaMir2Disease) ;
	return ($rc) ; # number of sig gene sets or minus error code

}

sub getDiseaseIDForMir2Disease{
        my $rcHash = {} ;
        open(INPUT, $mir2diseaseDb) or return({}) ;
        while(<INPUT>){
                chomp() ;
                if(/^disease ontology/){next;}
		next if(/^\s{0,}$/) ;
		next if($_ eq '') ;
                my @info = split /\t/;
                if($info[0] =~ /DOID:(\d+)/){
                        $rcHash->{$info[1]} = $1 ;
                }
        }
        close(INPUT) ;
        return($rcHash) ;
}

sub getTargetRefSeqListForPicTarOrPITA{
	my ($mirList, $targetTable, $fname) =  @_ ;
	my $h_rc = {} ;

        my $dsn_target = "DBI:mysql:database=miRNATarget;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
	my $dbh_target = DBI->connect( $dsn_target , 'MMIA' ) or die $DBI::errstr ;
	my $inClause  = "(\'" . join("\',\'",@$mirList)   ."\')" ;	
	my $sql = 'select miRNA, refSeq from '. $targetTable .' where miRNA in ' . $inClause ;
	my $sth_target = $dbh_target->prepare($sql) or die $dbh_target->errstr() ;
	$sth_target->execute ;
	my $rc_target = $sth_target->fetchall_arrayref() ;
	
	foreach my $i (@$rc_target){
		$h_rc->{$i->[0]} = $i->[1] ;
	}	
	$rc_target = [] ; #dump memory
	$sth_target->finish ;
	$dbh_target->disconnect ;

	#if you want to store the miRNA-refSeq in a text format, uncomment
	open(OUTPUT , '>' , $fname) or return({}) ;
	foreach my $k (keys(%$h_rc)){
		print OUTPUT join("\t", $k , $h_rc->{$k}),"\n";
	}
	close(OUTPUT) ;

	sleep(0.1) ;
	return($h_rc) ;
}



sub getTargetLocusLinkForTargetScanS{

	my ($mirList, $targetTable, $fname) =  @_ ;
	my $h_rc = {} ;
	my $h_tmp = {} ;	

        my $dsn_target = "DBI:mysql:database=miRNATarget;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
	my $dbh_target = DBI->connect( $dsn_target , 'MMIA' ) or die $DBI::errstr ;
	my $inClause  = "(\'" . join("\',\'",@$mirList)   ."\')" ;	
	my $sql = 'select distinct miRNA, locusLink from ' . $targetTable . ' where miRNA in '. $inClause ;
	my $sth_target = $dbh_target->prepare($sql) or die $dbh_target->errstr ;
	$sth_target->execute ;
	my $rc_target = $sth_target->fetchall_arrayref() ;

        foreach my $i (@$rc_target){
		my ( $miRNA, $locusLink ) = @$i ;
		$h_tmp->{$miRNA}->{$locusLink} ++ ;
	}
	foreach my $j (keys(%$h_tmp)){
		my $h_t2 = $h_tmp->{$j} ;
		$h_rc->{ $j } = join(',',keys(%$h_t2)) ;
	}
	$rc_target = [] ; #dump memory
	$sth_target->finish ;
	$dbh_target->disconnect ;

	#if you want to store the miRNA-locusLink in a text format, uncomment
	open(OUTPUT , '>' , $fname) or return({}) ;
	foreach my $k (keys(%$h_rc)){
		print OUTPUT join("\t", $k , $h_rc->{$k}),"\n";
	}
	close(OUTPUT) ;

	sleep(0.1) ;
	return($h_rc) ;
}

sub mapKgToRefSeq{
        my ($refSeqList, $organism ) =  @_ ;
        my $dsn_kg = "DBI:mysql:database=${organism};host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $inClause =  "(\'" .  join ("\' , \'" , @$refSeqList)  . "\')" ;
        my $sql = 'select distinct name, value from knownToRefSeq ' . ' where value  in ' . $inClause  ;
	#print STDERR $sql,"\n" if ($errorLog == 1) ;

        my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
        my $sth_kg = $dbh_kg->prepare($sql ) or die $dbh_kg->errstr ;
        $sth_kg->execute() ;
        my $rc_kg = $sth_kg->fetchall_arrayref() ;

        my $h_result = {} ;
        foreach my $i (@$rc_kg){
                my ($kg, $refSeq ) = @$i ;
                push @{$h_result->{$kg}}, $refSeq ;
        }

        $sth_kg->finish ;
        $dbh_kg->disconnect ;
        sleep(0.1) ;
        return($h_result) ;
}

sub mapKgToLocusLinkGivenEntrezList{
	my ($entrezList, $organism) = @_ ;
        my $dsn_kg = "DBI:mysql:database=${organism};host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
	my $inClause =  "(\'" .  join ("\',\'" , @$entrezList)  . "\')" ;
        my $sql = 'select distinct name, value from knownToLocusLink ' . ' where value  in ' . $inClause  ;
	#print STDERR $sql,"\n" if ($errorLog == 1) ;

	my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr ;
        my $sth_kg = $dbh_kg->prepare($sql ) or die $dbh_kg->errstr ;
        $sth_kg->execute() ;
        my $rc_kg = $sth_kg->fetchall_arrayref() ;

        my $h_result = {} ;
	foreach my $i (@$rc_kg){
		my ($kg, $entrez) = @$i ;
		push @{$h_result->{$kg}} , $entrez ;
	}

        $sth_kg->finish ;
        $dbh_kg->disconnect ;
        sleep(0.1) ;

        return($h_result) ;
}

sub mapKgToEnsemble {
	my ($enstList, $organism) = @_ ;	
	my $dsn_kg = "DBI:mysql:database=${organism};host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $inClause =  "(\'" .  join ("\',\'" , @$enstList )  . "\')" ;
        my $sql = 'select distinct name, value from knownToEnsembl  ' . ' where value  in ' . $inClause  ;
	#print STDERR $sql,"\n" if ($errorLog == 1) ;

        my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr ;
        my $sth_kg = $dbh_kg->prepare($sql ) or die $dbh_kg->errstr ;
        $sth_kg->execute() ;
        my $rc_kg = $sth_kg->fetchall_arrayref() ;

        my $h_result = {} ;
        foreach my $i (@$rc_kg){
                my ($kg, $enst) = @$i ;
                push @{$h_result->{$kg}} , $enst ;
        }

        $sth_kg->finish ;
        $dbh_kg->disconnect ;
        sleep(0.1) ;

        return($h_result) ;
}

####BEGIN: added in 20090514
sub getKgGivenMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable {
	my ($ids, $organism ,$fieldName) = @_ ;  # $fieldName is one of mRNA, SpId, SpDisplayId, geneSymbol, Protacc(NP_), and refSeq(NM_).
	my $dsn_kg = "DBI:mysql:database=${organism};host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
	my $inClause =  "(\'" . join("\' , \'", @$ids ) . "\')" ;
	my $sql = "select distinct kgId, $fieldName from kgXref where $fieldName != \'\' and $fieldName  in " .  $inClause ;
	#print STDERR $sql,"\n" if ($errorLog == 1) ;

        my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
	my $sth_kg =  $dbh_kg->prepare($sql) or die $dbh_kg->errstr ;
	$sth_kg->execute();
	my $rc_kg = $sth_kg->fetchall_arrayref() ;

        my $h_result = {} ;
        foreach my $i (@$rc_kg){
                my ($kg, $otherId) = @$i;
		push @{$h_result->{$kg}} ,$otherId ;
	}	

	$sth_kg->finish ;
	$dbh_kg->disconnect ;
	sleep(0.1) ;
	return($h_result) ;
}
#####END

sub mapKgToMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable {
	my ($ids, $organism ,$fieldName) = @_ ;  # $fieldName is one of mRNA, SpId, SpDisplayId, geneSymbol, Protacc(NP_), and refSeq(NM_).
	my $dsn_kg = "DBI:mysql:database=${organism};host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
	my $inClause =  "(\'" . join("\' , \'", @$ids ) . "\')" ;
	my $sql = "select distinct kgId, $fieldName from kgXref where $fieldName != \'\' and kgId in  $inClause" ;
	#print STDERR $sql,"\n" if ($errorLog == 1) ;

        my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
	my $sth_kg =  $dbh_kg->prepare($sql) or die $dbh_kg->errstr ;
	$sth_kg->execute() ;
	my $rc_kg = $sth_kg->fetchall_arrayref() ;

        my $h_result = {} ;
        foreach my $i (@$rc_kg){
                my ($kg, $otherId) = @$i;
		push @{$h_result->{$kg}} ,$otherId ;
	}	

	$sth_kg->finish ;
	$dbh_kg->disconnect ;
	sleep(0.1) ;
	return($h_result) ;
}


sub mapKgToLocusLinkGivenKglist {
        my ( $kgList, $organism ) =  @_ ;
        my $dsn_kg = "DBI:mysql:database=${organism};host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $inClause =  "(\'" . join("\' , \'", @$kgList ) . "\')" ;
        my $sql = 'select distinct name, value from knownToLocusLink where name in ' . $inClause ;  
	#print STDERR $sql,"\n" if ($errorLog == 1) ;

        my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
        my $sth_kg = $dbh_kg->prepare($sql ) or die $dbh_kg->errstr ;
        $sth_kg->execute() ;
        my $rc_kg = $sth_kg->fetchall_arrayref() ;

        my $h_result = {} ;
        foreach my $i (@$rc_kg){
                my ($kg, $entrez) = @$i ;
                push @{$h_result->{$kg}} , $entrez ;
        }

        $sth_kg->finish ;
        $dbh_kg->disconnect ;
        sleep(0.1) ;
        return($h_result) ;
}

sub mapKgToHgu133plus2{
	# return value (hash)
	my ( $kgList, $organism ) =  @_ ;
        my $dsn_kg = "DBI:mysql:database=${organism};host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $inClause =  "(\'" . join("\',\'", @$kgList ) . "\')" ;
	my $sql = 'select distinct name, value from knownToU133Plus2 where name in ' . $inClause ;
	my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
        my $sth_kg = $dbh_kg->prepare($sql ) or die $dbh_kg->errstr ;
        $sth_kg->execute() ;
        my $rc_kg = $sth_kg->fetchall_arrayref() ;

        my $h_result = {} ;

        foreach my $i (@$rc_kg){
		my ($kg, $affy ) = @$i ;
		push @{$h_result->{$kg}} , $affy ;
        }

        $sth_kg->finish ;
        $dbh_kg->disconnect ;
        sleep(0.1) ;
        return($h_result) ; 
}

sub getProbeSetsGivenKnownGeneList { 
	## genernal version of "mapKgToHgu133plus2"
	my ($kgList, $kgToChipTable ) = @_ ;
	my $inClause =  "(\'" .   join("\',\'", @$kgList ) . "\')" ;
	my $dsn_kg = "DBI:mysql:database=hg18;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
	my $sql =  'select distinct name, value from ' . $kgToChipTable	. ' where name in ' . $inClause ;
	my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
        my $sth_kg = $dbh_kg->prepare( $sql ) or die $dbh_kg->errstr ;
        $sth_kg->execute() ;
        my $rc_kg = $sth_kg->fetchall_arrayref() ;

	my $h_result = {} ;
	foreach my $i (@$rc_kg){
		my ($kg, $affy) = @$i ;
		push @{$h_result->{$kg}} , $affy ;
	}

	$sth_kg->finish ;
        $dbh_kg->disconnect ;
        sleep(0.1) ;
        return($h_result) ;
}

sub getKgToProbeSetsGivenProbeSetList{
	my ($probeSetList, $kgToChipTable ) = @_ ;
        my $inClause =  "(\'" .   join("\',\'", @$probeSetList ) . "\')" ;
        my $dsn_kg = "DBI:mysql:database=hg18;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $sql =  'select distinct name, value from ' . $kgToChipTable . ' where value in ' . $inClause ;
	my $dbh_kg =  DBI->connect($dsn_kg,'MMIA') or die $DBI::errstr;
        my $sth_kg = $dbh_kg->prepare( $sql ) or die $dbh_kg->errstr ;
        $sth_kg->execute() or return {} ;
        my $rc_kg = $sth_kg->fetchall_arrayref() ;

        my $h_result = {} ;
        foreach my $i (@$rc_kg){
		my ($kg, $probe) = @$i ;
		push @{$h_result->{$kg}} , $probe ;
	}
	$sth_kg->finish ;
        $dbh_kg->disconnect ;
        sleep(0.1) ;
        return($h_result) ;  # hash : key (kg) , value (array reference of probeSets)
}

sub getRefSeqToLocusLink{ # 
	my ($refseqs, $db) = @_ ;
	my $h_result = {} ;

	my $inClause =  "(\'" .   join("\',\'", @$refseqs ) . "\')" ;
        my $dsn_hg18_suppl ="DBI:mysql:database=${db};host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
	my $sql = 'select distinct refSeq, locusLink from hg18_refSeq2LocusLink where refSeq in '. $inClause ;
	my $dbh_hg18_suppl =  DBI->connect($dsn_hg18_suppl, 'MMIA') or die $DBI::errstr;
	my $sth = $dbh_hg18_suppl->prepare($sql) or die $dbh_hg18_suppl->errstr ;
	$sth->execute ;
	my $rc = $sth->fetchall_arrayref ;
	foreach my $i (@$rc){
		my ($seq, $entrez) = @$i ;
		push @{$h_result->{$seq}} , $entrez ;
	}
	$sth->finish ;
	$dbh_hg18_suppl->disconnect ;
	sleep(0.1) ;
	return($h_result) ; # hash key (kg), value (array reference of entrez genes)	
}


sub mapCustomIdToKgGivenCustomId {
	my %h_customIdToKg = () ;
	my ($customIds, $organism) = @_ ;
	my $a_uniqCustomIdNotMapped = Util::getUniqListFromArray($customIds) ;

	my $a_uniqCustomIdMapped = [] ;
	my $h_tryKgToOther = {} ;
	my $h_tmp = {};

	# find entrez gene id
	$h_tryKgToOther = mapKgToLocusLinkGivenEntrezList ($a_uniqCustomIdNotMapped , $organism) ;
	$a_uniqCustomIdMapped = Util::getAllUniqHashValuesInHashCommSepValFormat( $h_tryKgToOther ) ;
	$a_uniqCustomIdNotMapped = Util::getSetAMinusSetB ( $a_uniqCustomIdNotMapped , $a_uniqCustomIdMapped ) ;
	$h_tmp = Util::switchHashKeyAndArrayedValue ($h_tryKgToOther) ;
	$h_tryKgToOther = {} ; # dump memory
	@h_customIdToKg{ keys(%$h_tmp) } =  values(%$h_tmp) ;

	# find refSeq
	$h_tryKgToOther = mapKgToRefSeq ($a_uniqCustomIdNotMapped, $organism) ;
	$a_uniqCustomIdMapped = Util::getAllUniqHashValuesInHashCommSepValFormat( $h_tryKgToOther ) ;
	$a_uniqCustomIdNotMapped = Util::getSetAMinusSetB ( $a_uniqCustomIdNotMapped , $a_uniqCustomIdMapped ) ;	
	$h_tmp = Util::switchHashKeyAndArrayedValue ($h_tryKgToOther) ;
	$h_tryKgToOther = {} ; # dump memory
	@h_customIdToKg{ keys(%$h_tmp) } =  values(%$h_tmp) ;
	print STDERR 'mapCustomIdToKgGivenCustomId ', 'RefSeq ', scalar(keys(%h_customIdToKg) ),"\n" if($errorLog == 1);

	# find mRNA 
	####BEGIN: modified in 20090514
	$h_tryKgToOther = getKgGivenMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable ($a_uniqCustomIdNotMapped , $organism, 'mRNA' );
	#$h_tryKgToOther = mapKgToMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable($a_uniqCustomIdNotMapped , $organism, 'mRNA' );
	####END
	$a_uniqCustomIdMapped = Util::getAllUniqHashValuesInHashCommSepValFormat( $h_tryKgToOther ) ;
	$a_uniqCustomIdNotMapped = Util::getSetAMinusSetB ( $a_uniqCustomIdNotMapped , $a_uniqCustomIdMapped ) ;
	$h_tmp = Util::switchHashKeyAndArrayedValue ($h_tryKgToOther) ;
	$h_tryKgToOther = {} ; # dump memory
	@h_customIdToKg{ keys(%$h_tmp) } =  values(%$h_tmp) ;
	print STDERR 'mapCustomIdToKgGivenCustomId ', 'mRNA ', scalar(keys(%h_customIdToKg) ),"\n" if($errorLog == 1);

	# find Spid
	####BEGIN: modified in 20090514
	$h_tryKgToOther = getKgGivenMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable ($a_uniqCustomIdNotMapped , $organism, 'spID') ;
	#$h_tryKgToOther = mapKgToMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable($a_uniqCustomIdNotMapped , $organism, 'spID' );
	####END
	$a_uniqCustomIdMapped = Util::getAllUniqHashValuesInHashCommSepValFormat( $h_tryKgToOther ) ;
        $a_uniqCustomIdNotMapped = Util::getSetAMinusSetB ( $a_uniqCustomIdNotMapped , $a_uniqCustomIdMapped ) ;
	$h_tmp = Util::switchHashKeyAndArrayedValue ($h_tryKgToOther) ;
	$h_tryKgToOther = {} ; # dump memory
	@h_customIdToKg{ keys(%$h_tmp) } =  values(%$h_tmp) ;
	print STDERR 'mapCustomIdToKgGivenCustomId ', 'spID ', scalar(keys(%h_customIdToKg) ),"\n" if($errorLog == 1);

	# find gene symbol
	####BEGIN: modified in 20090514
	$h_tryKgToOther = getKgGivenMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable ($a_uniqCustomIdNotMapped , $organism, 'genesymbol') ;
	#$h_tryKgToOther = mapKgToMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable($a_uniqCustomIdNotMapped , $organism, 'genesymbol') ;
	####END
	$a_uniqCustomIdMapped = Util::getAllUniqHashValuesInHashCommSepValFormat( $h_tryKgToOther ) ;
        $a_uniqCustomIdNotMapped = Util::getSetAMinusSetB ( $a_uniqCustomIdNotMapped , $a_uniqCustomIdMapped ) ;
	$h_tmp = Util::switchHashKeyAndArrayedValue ($h_tryKgToOther) ;
	$h_tryKgToOther = {} ; # dump memory
	@h_customIdToKg{ keys(%$h_tmp) } =  values(%$h_tmp) ;
	print STDERR 'mapCustomIdToKgGivenCustomId ', 'Gene symbol ', scalar(keys(%h_customIdToKg) ),"\n" if($errorLog == 1);

	# find ncbi protein acc (NP_)
	####BEGIN: modified in 20090514
	$h_tryKgToOther = getKgGivenMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable ($a_uniqCustomIdNotMapped , $organism, 'protAcc') ;
	#$h_tryKgToOther = mapKgToMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable($a_uniqCustomIdNotMapped , $organism, 'protAcc') ;
	####END
	$a_uniqCustomIdMapped = Util::getAllUniqHashValuesInHashCommSepValFormat( $h_tryKgToOther ) ;
        $a_uniqCustomIdNotMapped = Util::getSetAMinusSetB ( $a_uniqCustomIdNotMapped , $a_uniqCustomIdMapped ) ;
	$h_tmp = Util::switchHashKeyAndArrayedValue ($h_tryKgToOther) ;
	$h_tryKgToOther = {} ; # dump memory
	@h_customIdToKg{ keys(%$h_tmp) } =  values(%$h_tmp) ;
	print STDERR 'mapCustomIdToKgGivenCustomId ', 'RefSeq prot ', scalar(keys(%h_customIdToKg) ),"\n" if($errorLog == 1);

	# find ensemble transcript (ENST)
	$h_tryKgToOther = mapKgToEnsemble ( $a_uniqCustomIdNotMapped, $organism  );
	$a_uniqCustomIdMapped = Util::getAllUniqHashValuesInHashCommSepValFormat( $h_tryKgToOther ) ;
        $a_uniqCustomIdNotMapped = Util::getSetAMinusSetB ( $a_uniqCustomIdNotMapped , $a_uniqCustomIdMapped ) ;
	$h_tmp = Util::switchHashKeyAndArrayedValue ($h_tryKgToOther) ;
	$h_tryKgToOther = {} ; # dump memory
	@h_customIdToKg{ keys(%$h_tmp) } =  values(%$h_tmp) ;
	print STDERR 'mapCustomIdToKgGivenCustomId ', 'ENST ', scalar(keys(%h_customIdToKg) ),"\n" if($errorLog == 1);


	$h_tryKgToOther ={} ; # dump memory 
	$a_uniqCustomIdMapped = [] ;  # dump memory
	$a_uniqCustomIdNotMapped = [] ; # dump memory

	return(\%h_customIdToKg) ;	
}

sub makeMrnaDataTableFromRefSeq {

	my $h_refSeqToMir = shift @_ ;
	my $a_table = [] ;
	my $h_kgToRefSeq = mapKgToRefSeq ([ keys(%$h_refSeqToMir)] , 'hg18' )  ; 
	my $h_refSeqToKg = Util::switchHashKeyAndArrayedValue ( $h_kgToRefSeq ) ;
	my $h_kgToGeneSymbol = mapKgToMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable  ( [keys(%$h_kgToRefSeq) ] ,  'hg18', 'geneSymbol') ;
	my $h_kgToLocusLink = mapKgToLocusLinkGivenKglist ([keys(%$h_kgToRefSeq)], 'hg18' ) ;	
	my $countMax = scalar(keys(%$h_refSeqToMir)) ;
        my $progress = Term::ProgressBar->new({name  => 'Making mRNA target table from refSeq target Ids', count => $countMax, ETA => 'linear' });
        $progress->minor(0) ;
	foreach my $refseq (keys(%$h_refSeqToMir)){
		my $row = [] ;
		# i) first column, locuslink
		if(exists($h_refSeqToKg->{$refseq})){
			my $a_kg = $h_refSeqToKg->{$refseq} ;
			my $h_temp = {} ;	
			foreach my $kg (@$a_kg){
				next unless (exists ($h_kgToLocusLink->{$kg}) ) ;
				my $a_locusLink = $h_kgToLocusLink->{$kg} ;
				foreach my $locusLink ( @$a_locusLink ) {
					$h_temp->{ $locusLink } ++ ;		
				} 	
			}

			if(Util::isEmptyHash($h_temp) < 0){
				push @$row , [''] ;
			}else{
				push @$row , [ keys(%$h_temp) ] ;
			}					
		}else{
				push @$row, [''] ;
		}
		# ii) second column, refSeq
		push @$row, [$refseq] ;
		# iii) third column, Gene Symbol	
		if(exists($h_refSeqToKg->{$refseq})){
			my $a_kg = $h_refSeqToKg->{$refseq}   ;
                        my $h_temp = {} ;
                        foreach my $kg (@$a_kg){
                                next unless(exists ($h_kgToGeneSymbol->{$kg}) );
				my $a_symbol = $h_kgToGeneSymbol->{$kg} ;
				foreach my $symbol (@$a_symbol){
					$h_temp->{$symbol} ++ ;
				}
			}
			if(Util::isEmptyHash($h_temp) < 0){
                                push @$row, [''] ;
                        } else{
                                push @$row , [ keys(%$h_temp) ];
                        }

		}else{
                	push @$row, [''] ;
		}
		# iv) fourth column, mirna info
		push @$row , $h_refSeqToMir->{$refseq} ; 

		push @$a_table, $row ;
	}

	$progress->update($countMax) ;
	$h_kgToRefSeq = {} ;
	$h_refSeqToKg = {} ;
	$h_kgToGeneSymbol = {} ;
	return($a_table) ;
}


sub makeMrnaDataTableFromEntrez {

	my $h_entrezToMir = shift @_  ;  
	my $a_table = [] ;
	my $h_kgToEntrez =  mapKgToLocusLinkGivenEntrezList([keys(%$h_entrezToMir )] ,'hg18' ) ;
	my $h_entrezToKg = Util::switchHashKeyAndArrayedValue($h_kgToEntrez );
	my $h_kgToRefSeq = mapKgToMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable  ( [keys(%$h_kgToEntrez)] ,  'hg18', 'refSeq') ; 	  
	my $h_kgToGeneSymbol = mapKgToMRNAOrSpidOrSpdisplayidOrRefseqOrGenesymbolOrProtaccUsingKgXRefTable  ( [keys(%$h_kgToEntrez ) ] ,  'hg18', 'geneSymbol') ;
	my $countMax = scalar (keys(%$h_entrezToMir)) ;
        my $progress = Term::ProgressBar->new({name  => 'Making mRNA target table from entrez target Ids', count => $countMax, ETA => 'linear' });
        $progress->minor(0) ;
	foreach my $entrez (keys(%$h_entrezToMir)){
		
		my $row =  [] ;
		# i) first column, locuslink
		push @$row, [$entrez] ;
		# ii) second column, refSeq
		if( exists ($h_entrezToKg->{$entrez} )){
			my $a_kg = $h_entrezToKg->{$entrez}   ;
			my $h_temp = {} ;
			
			foreach my $kg (@$a_kg){
				next unless(exists ($h_kgToRefSeq->{$kg})) ;
				my $a_refSeq = $h_kgToRefSeq->{$kg} ;
				foreach my $seq ( @$a_refSeq ){
					$h_temp->{$seq} ++ ;
				}
			}
			if(Util::isEmptyHash($h_temp) < 0){ 
				push @$row, [''] ;
			} else{
				push @$row , [ keys(%$h_temp) ];
			}
		}else{
			push @$row, [''] ;
		}
		# iii) third column, Gene Symbol
		if( exists ($h_entrezToKg->{$entrez} )){
			my $a_kg = $h_entrezToKg->{$entrez}   ;
                        my $h_temp = {} ;
                        foreach my $kg (@$a_kg){
                                next unless(exists ($h_kgToGeneSymbol->{$kg}) );
				my $a_symbol = $h_kgToGeneSymbol->{$kg} ;
				foreach my $symbol (@$a_symbol){
					$h_temp->{$symbol} ++ ;
				}
			}
			if(Util::isEmptyHash($h_temp) < 0){
                                push @$row, [''] ;
                        } else{
                                push @$row , [ keys(%$h_temp) ];
                        }

		}else{
			push @$row, [''] ;
		}
		# iv) fourth column, mirna information
		push @$row, $h_entrezToMir->{$entrez} ;	
		
		push @$a_table, $row ;
	}
	$progress->update($countMax) ;
	$h_kgToEntrez = {} ;
	$h_kgToRefSeq = {} ;
	$h_kgToGeneSymbol = {} ;

	return($a_table) ;
}


sub makeExtendedMrnaDataTableFromEntrez{

	my ($h_entrezToMir , $mRNAUpSig, $mRNADownSig, $tablePrefix ) = @_ ;	
	my $a_table = [] ;
	$a_table = makeMrnaDataTableFromEntrez( $h_entrezToMir ) ;

	my $h_mRNAUpSig = Preprocessing::getProbesetToEntrezGivenProbesetByAffyAnnotTable($mRNAUpSig, $tablePrefix ) ;
	my $h_mRNADownSig =  Preprocessing::getProbesetToEntrezGivenProbesetByAffyAnnotTable($mRNADownSig, $tablePrefix) ;

	foreach my $num (0 .. (scalar(@$a_table)-1)){
		my $i = $a_table->[$num] ;
		my $expression = '' ;	
		if(exists($i->[0]->[0])){
			my $entrez = $i->[0]->[0] ;	
			if(exists($h_mRNAUpSig->{$entrez})){
				$expression = 'Up' ;
			}elsif(exists($h_mRNADownSig->{$entrez})){
				$expression = 'Down' ;
			}else{
				;
			}
		}else{
			;
		}
		push @$i, $expression ;
		$a_table->[$num] = $i ;
	}	

	return($a_table) ;

}

sub makeExtendedMrnaDataTableFromRefSeq {

	my ($h_refSeqToMir , $mRNAUpSig, $mRNADownSig, $tablePrefix ) = @_ ;	
	my $a_table = [] ;
	$a_table =  makeMrnaDataTableFromRefSeq ( $h_refSeqToMir  ) ;
	
	my $h_mRNAUpSig = Preprocessing::getProbesetToRefSeqGivenProbesetByAffyAnnotTable ($mRNAUpSig,$tablePrefix) ;
	my $h_mRNADownSig =  Preprocessing::getProbesetToRefSeqGivenProbesetByAffyAnnotTable ( $mRNADownSig, $tablePrefix ) ;
        foreach my $num (0 .. (scalar(@$a_table)-1)){
                my $i = $a_table->[$num] ;
                my $expression = '' ;
                if(exists($i->[1]->[0])){
                        my $refseq = $i->[1]->[0] ;
                        if(exists($h_mRNAUpSig->{$refseq})){
                                $expression = 'Up' ;
                        }elsif(exists($h_mRNADownSig->{$refseq})){
                                $expression = 'Down' ;
                        }else{
                                ;
                        }
                }else{
                        ;
                }
                push @$i, $expression ;
                $a_table->[$num] = $i ;
        }

        return($a_table) ;

}



1;
