#!/usr/bin/perl

package MMIA::Preprocessing ;

#use 5.10.0 ;
use strict;

use lib  '/home/seokjong/lib/perl5/site_perl/MMIA' ;

#use Env qw (@INC) ;
#push @INC , '/home/seokjong/lib/perl5/site_perl/MMIA' ;
#push @INC , '/Users/yoon/lib/Yoon';
#push @INC , '/Users/yoon/lib/MMIAPERLLIB';
#push @INC , '/Users/yoon/lib/perl5/site_perl/Text/Graph';


use POSIX ":sys_wait_h";
use Statistics::Descriptive;
use Term::ProgressBar;
use DBI ;
use MMIA::Util ;
use Time::HiRes qw(gettimeofday);
my $errorLog =0 ;

my $R = '/opt/R/bin/R';
my $execDir = '/home/MMIA/WebServer/src';
my $sigGeneModule = $execDir. '/'. 'siggeneFinder.R';
my $clusterModule = $execDir. '/CRANCluster.R' ;

sub thresholding{ ## it's optional. Usually, for Affy.  See Bioconductor basics tutorial 2002
	my ($ceiling, $floor, $twoDMatrix) = @_ ;
	
	if(MMIA::Util::isEmptyArray($twoDMatrix) < 0){
		return([]) ;
	}

	my $countMax = scalar(@$twoDMatrix) ;
	my $progress = Term::ProgressBar->new({name  => 'Preprocessing(Thresholding)', count => $countMax, ETA => 'linear' });
	$progress->minor(0);
	#print STDERR 'countMax ',$countMax ;

	foreach my $i (0 .. (scalar @$twoDMatrix -1)){
		my $row = $twoDMatrix->[$i] ;
		foreach my $j (0 .. (scalar @$row -1)){
			if($twoDMatrix->[$i]->[$j] > $ceiling){
				$twoDMatrix->[$i]->[$j] = $ceiling ;
			}
			if($twoDMatrix->[$i]->[$j] < $floor ){
				$twoDMatrix->[$i]->[$j] = $floor ;
			}
		}
		if( $i == int((scalar @$twoDMatrix -1)/4) || $i == int((scalar @$twoDMatrix -1)/2) || $i == int((scalar @$twoDMatrix -1)*3/4) ){
			$progress->update($i);
		}
	}

	$progress->update($countMax);
	
	return($twoDMatrix) ;
}

sub filtering{ ## it's optional. Usually, for Affy.  See Bioconductor basics tutorial 2002
	my ($r, $d, $twoDMatrix)= @_  ;
	my $rowIndex = [] ;

	if(MMIA::Util::isEmptyArray($twoDMatrix) < 0){
		return([]) ;
	}
	
	my $countMax = scalar(@$twoDMatrix) ;
	my $progress = Term::ProgressBar->new({name  => 'Preprocessing(Filtering)', count => $countMax, ETA => 'linear' });
	$progress->minor(0);

	foreach my $i (0 .. (scalar@$twoDMatrix -1)){
		my $row = $twoDMatrix->[$i] ;
		my $stat = Statistics::Descriptive::Sparse->new() ;
		$stat->add_data($row) ;	
		my $min = $stat->min() ;
		my $max = $stat->max() ;
		if($max/$min > $r && $max-$min > $d ){
			push @$rowIndex, $i ;
		}
		if( $i == int((scalar @$twoDMatrix -1)/4) || $i == int((scalar @$twoDMatrix -1)/2) || $i == int((scalar @$twoDMatrix -1)*3/4) ){
			$progress->update($i);
		}
	}

	$progress->update($countMax ) ;

	## You need error handling.
        ## Because, if $rowIndex is empty, you don't go to further analysis.
	return($rowIndex)
}

###BEGIN : added in 10062009
sub iqrStandardizationGivenPercentiles{ #it's optional but recommend. Usually, for Affy.  See Bioconductor basics tutorial 2002 

	my $twoDMatrix = shift @_ ;

	if(MMIA::Util::isEmptyArray($twoDMatrix) < 0){
		return([]) ;
	}
	my $lowerPercentile = shift @_ ; # e.g., 25 %
	my $upperPercentile = shift @_ ; # e.g., 75 %

	my $numCol = scalar( @{$twoDMatrix->[0]} ) ;
	my $countMax = $numCol ;
	my $progress = Term::ProgressBar->new({name  => 'Preprocessing(Standardization)', count => $countMax, ETA => 'linear' });
	$progress->minor(0);

	####BEGIN: added in 04082009
	my $firstChipIqr = 0 ;
	###END: added

	####BEGIN: added in 04272009
	my $firstChipMed = 0 ;
	###END: added

	foreach my $j (0 .. ($numCol -1)){
		my $stat = Statistics::Descriptive::Full->new();
		foreach my $i ( 0 .. (scalar(@$twoDMatrix)-1) ){
			$stat->add_data( $twoDMatrix->[$i]->[$j] ) ;
		}
		my $median = $stat->median() ; 
		my $iqrUp = $stat->percentile($upperPercentile);
		my $iqrDown = $stat->percentile($lowerPercentile) ;
		my $iqr = $iqrUp - $iqrDown ;

		#####BEGIN: added in 04082009 and 04272009
		$firstChipIqr = $iqr if( $j == 0 );
		$firstChipMed = $median if ($j == 0 );
		#####END: added

		foreach my $i (0 .. (scalar(@$twoDMatrix)-1) ){
			eval{
				#####BEGIN: modified in 04082009 and 04272009
				$twoDMatrix->[$i]->[$j] = ( $twoDMatrix->[$i]->[$j] - $median ) / $iqr * $firstChipIqr + $firstChipMed;
				#####END: modified
			};
			if($@){
				## Error code should be assigned.
				#print STDERR 'Standardization error. You need to filter your data',"\n";
				#print STDERR 'iqrUp ',$iqrUp ,"\n";
				$twoDMatrix =  [] ;
				return($twoDMatrix) ;
			}
		}	
		if($j == int(($numCol -1)/4) || $j == int(($numCol -1)/2) || $j == int(($numCol -1)*3/4) ){
			$progress->update($j) ;
		}
	}

	$progress->update($countMax) ;	
	return($twoDMatrix) ;
}
### END : added

### BEGIN : modified in 10062009
sub iqrStandardization{ #it's optional but recommend. Usually, for Affy.  See Bioconductor basics tutorial 2002 

	my $twoDMatrix = shift @_ ;

	if(MMIA::Util::isEmptyArray($twoDMatrix) < 0){
		return([]) ;
	}

	my $lowerPercentile = shift @_ ; # e.g., 25 % , 10 %
	my $upperPercentile = shift @_ ; # e.g., 75 % , 90 %

	return ( iqrStandardizationGivenPercentiles ($twoDMatrix, 10, 90 ) ) ;

}
### END : modified 


sub standardization{ #it's optional but recommend. Usually, for Affy.  See Bioconductor basics tutorial 2002 

	my $twoDMatrix = shift @_ ;
	if(MMIA::Util::isEmptyArray($twoDMatrix) < 0){
		return([]) ;
	}

	my $numCol = scalar( @{$twoDMatrix->[0]} ) ;
	my $countMax = $numCol ;
	my $progress = Term::ProgressBar->new({name  => 'Preprocessing(Standardization)', count => $countMax, ETA => 'linear' });
	$progress->minor(0);

	foreach my $j (0 .. ($numCol -1)){
		my $stat = Statistics::Descriptive::Sparse->new();
		foreach my $i ( 0 .. (scalar(@$twoDMatrix)-1) ){
			$stat->add_data( $twoDMatrix->[$i]->[$j] ) ;
		}
		my $mean = $stat->mean() ;
		my $sd = $stat->standard_deviation();

		foreach my $i (0 .. (scalar(@$twoDMatrix)-1) ){
			eval{
				$twoDMatrix->[$i]->[$j] = ( $twoDMatrix->[$i]->[$j] - $mean )/$sd ;
			};
			if($@){
				# Error code should be assigned. 
				#print STDERR 'Standardization error. You need to filter your data',"\n";
				$twoDMatrix = [] ;
				return ($twoDMatrix) ;
			}
		}	
		if($j == int(($numCol -1)/4) || $j == int(($numCol -1)/2) || $j == int(($numCol -1)*3/4) ){
			$progress->update($j) ;
		}
	}

	$progress->update($countMax) ;	
	return($twoDMatrix) ;
}

###BEGIN: added in 04272009
sub standardizationVer2 {

	my $twoDMatrix = shift @_ ;
	if(MMIA::Util::isEmptyArray($twoDMatrix) < 0){
		return([]) ;
	}

	my $numCol = scalar( @{$twoDMatrix->[0]} ) ;
	my $countMax = $numCol ;
	my $progress = Term::ProgressBar->new({name  => 'Preprocessing(Standardization)', count => $countMax, ETA => 'linear' });
	$progress->minor(0);

	my $firstChipSd = 0 ;
	my $firstChipMean = 0;

	foreach my $j (0 .. ($numCol -1)){
		my $stat = Statistics::Descriptive::Sparse->new();
		foreach my $i ( 0 .. (scalar(@$twoDMatrix)-1) ){
			$stat->add_data( $twoDMatrix->[$i]->[$j] ) ;
		}
		my $mean = $stat->mean() ;
		my $sd = $stat->standard_deviation();

		$firstChipSd = $sd if ($j == 0) ;
		$firstChipMean = $mean if ($j == 0) ;

		foreach my $i (0 .. (scalar(@$twoDMatrix)-1) ){
			eval{
				$twoDMatrix->[$i]->[$j] = ( $twoDMatrix->[$i]->[$j] - $mean )/$sd * $firstChipSd + $firstChipMean ;
			};
			if($@){
				# Error code should be assigned. 
				#print STDERR 'Standardization error. You need to filter your data',"\n";
				$twoDMatrix = [] ;
				return ($twoDMatrix) ;
			}
		}	
		if($j == int(($numCol -1)/4) || $j == int(($numCol -1)/2) || $j == int(($numCol -1)*3/4) ){
			$progress->update($j) ;
		}
	}

	$progress->update($countMax) ;	
	return($twoDMatrix) ;
}
###END: added in 04272009

sub log2Transform{
	my $twoDExpression = shift(@_) ;
	if(MMIA::Util::isEmptyArray($twoDExpression) < 0){
		return([[], []]) ;
	}

	my $geneIndex = [] ;
	my $log2_TwoDExpression = [] ;


        my $countMax = scalar @$twoDExpression ;
        my $progress = Term::ProgressBar->new({name  => 'Preprocessing(log2 transform)', count => $countMax, ETA => 'linear' });
        $progress->minor(0);


	foreach my $i ( 0  .. (scalar @$twoDExpression -1)){
		my $row = $twoDExpression->[$i] ;
		my $t_row = [] ;
		foreach my $j (0 .. (scalar @$row -1)){
			my $t = 0;
			eval{
				$t = log2( $row->[$j] );
			};
			if($@){
				last ;
			}
			if(! is_numeric ($t)){
				last;
			}
			push @$t_row, $t ;
		}
		if( scalar @$row == scalar @$t_row ){
			push @$geneIndex, $i ;
			push @$log2_TwoDExpression, $t_row ;
		}
		
		if($i == int( (scalar @$twoDExpression -1)/4 ) || $i == int( (scalar @$twoDExpression -1)/2 ) || $i == int(  (scalar @$twoDExpression -1)*3/4 ) ){
			$progress->update($i) ;
		}
	}
	$progress->update($countMax) ;
	return [$geneIndex , $log2_TwoDExpression];
}

sub log2{
        return (log($_[0])/log(2)) ;
}

sub getnum{
        use POSIX qw(strtod) ;
        my $str= shift ;
        $str = ''.$str ;
        $str =~ s/^\s+// ;
        $str =~ s/\s+$// ;
        $! =0 ;
        my ($num, $unparsed) = strtod($str) ;
        if (($str eq '') || ($unparsed != 0) || $!){
                return ;
        }else{
                return $num ;
        }
}

sub is_numeric{
        defined scalar &getnum
}

sub removeUnnecessaryProbeSipFile{ ## filter "Control sequence" in the Affy mRNA chip

        my ( $iFile,$tablePrefix) = @_ ;

        my @content = @{ readSipFile($iFile)} ;
        my @titleSip = @content[0 .. 1];

        my $filteredContent = [] ;
        my $dsn ="DBI:mysql:database=Affy;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dbh = DBI->connect($dsn,'MMIA') or die $DBI::errstr ;
        my $seqTypeTable = $tablePrefix.'_Table_SeqType';
        my $sql = "select probeSet from $seqTypeTable where seqType="."\'"."Control sequence"."\'" ;
        my $sth = $dbh->prepare($sql) or die $dbh->errstr ;
        $sth->execute() ;
        my $rows = $sth->fetchall_arrayref() ;
        foreach my $elm (@content[2 .. $#content]){
                my @a_elm = split /\t/, $elm ;
                my $probeSet = $a_elm[0] ;
                my @temp = grep { $_->[0] eq $probeSet } @$rows ;
		@temp = () if ( MMIA::Util::isEmptyArray(\@temp) < 0 ) ; # modified 20090104
                if ( scalar(@temp) > 0 ){
                        next;
                }else{
                        push @$filteredContent, $elm ;
                }
        }
        $sth->finish();
        $dbh->disconnect() ;

        my $filtered = [] ;
        push @$filtered, @titleSip ;
        push @$filtered, @$filteredContent ;
	sleep (0.1) ;
        return $filtered ; # 1-D array including sip headers

}

####BEGIN : 06292009
sub getControlProbes {
	my $tablePrefix = shift @_ ;

        my $dsn ="DBI:mysql:database=Affy;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dbh = DBI->connect($dsn,'MMIA') or die $DBI::errstr ;
        my $seqTypeTable = $tablePrefix.'_Table_SeqType';
        my $sql = "select distinct probeSet from $seqTypeTable where seqType="."\'"."Control sequence"."\'" ;
        my $sth = $dbh->prepare($sql) or die $dbh->errstr ;
        $sth->execute() ;
        my $rows = $sth->fetchall_arrayref() ;
	
	my $h_rc = {} ;
	foreach my $k (@$rows){
		foreach my $k2 (@$k) {
			$h_rc->{$k2} ++ ;
		}
	}	

        $sth->finish();
        $dbh->disconnect() ;

	sleep(0.1) ;
	return($h_rc) ;
}
####END


sub readSipFile{

        my $iFile = shift @_  ;

	return( MMIA::Util::readLineByLineFormat($iFile)   ) ;
}

sub transform1DSipFormatTo2DMatrix{
        my $content = shift(@_) ; # content: It doesn't matter whether or not the 1-D array has the header lines
        my $TwoDMatrix = [] ;
        foreach my $i (@$content){
                if($i =~ /^#/){next;}
                my @info = split /\t/, $i ;
                push @$TwoDMatrix , [@info[1 .. $#info]] ;
        }

        return ($TwoDMatrix) ;
}

sub getGeneNames{
        my $content = shift(@_) ; # content: It doesn't matter whether or not the 1-D array has the header lines
        my $geneSet = [] ;
        foreach my $i (@$content){
                if($i =~ /^#/){next;}
                my @info = split /\t/, $i ;
                push @$geneSet, $info[0] ;
        }
        return($geneSet) ;
}

sub writeSIPFormatForCRANHCluster{
        my ($clsHeader, $sampleHeader, $geneNames, $TwoDExpressionMatrix, $outFile, $log2) = @_ ;

        if(scalar(@$geneNames) != scalar(@$TwoDExpressionMatrix)){
                #print STDERR 'serious error in writing input. dimension problem',"\n";
		#Error occurs
		return(-1) ; 
        }
        open(OUT, '>', $outFile) or return(-2); #Error code -2 returns if opening fails
        my @tmp = split /\t/,$clsHeader;
        print OUT join("\t",@tmp),"\n";
        @tmp = split /\t/,$sampleHeader;
        print OUT join("\t",@tmp),"\n";

        if($log2 == 1){
                foreach my $i (0 .. (scalar @$geneNames -1)){
                        my @row = @{$TwoDExpressionMatrix->[$i]} ;
                        my $pos_count =0 ;
                        my @arrLog2 =() ;
                        foreach my $j (@row){
                                if($j <= 0){
                                        last ;
                                }else{
                                        my $t_log2 = log2 ($j) ;
                                        unless ( is_numeric($t_log2) ){
                                                last ;
                                        }
                                        push @arrLog2 , $t_log2 ;
                                }
                        }
                        if(scalar @arrLog2  == scalar @row){
                                print OUT join ("\t", ,$geneNames->[$i], @arrLog2),"\n";
                        }
                }
        }else{
                foreach my $i (0 .. (scalar @$geneNames -1) ){
                        print OUT join("\t",$geneNames->[$i],@{$TwoDExpressionMatrix->[$i]}),"\n";
                }
        }
        close OUT;
	sleep(1) ;

        return(1) ;
}


sub hashTo2DExpressionMatrix{
	my $myHash = shift(@_) ;
	my $geneNames =[] ;
	my $TwoDMatrix = [] ;
	foreach my $k (keys(%$myHash)){
		my $row = $myHash->{$k} ;
		push @$TwoDMatrix, [@$row] ;
		push @$geneNames, $k ;
	}
	return ([$geneNames, $TwoDMatrix]) ;
}



sub obtain2ColMedExprBetween2Classes {
        ## Make sure that exprMat values are pos values in linear scale
        ## or log2ExprMant shouldn't be -Inf.
        ## Return median values for the classes in each row.	

	my ($exprMat, $cls1idx, $cls2idx) = @_ ; ;
        my $progress = Term::ProgressBar->new({name  => 'Making 2ColExprMat', count => 100, ETA => 'linear' });
	$progress->minor(0) ;

	my $rc_2ColMat = [] ;
	foreach my $row (@$exprMat) {

		my $stat = Statistics::Descriptive::Full->new();
		$stat->add_data( [ @$row [@$cls1idx] ] ) ;
		
		my $cls1_med = $stat->median ;

		$stat = Statistics::Descriptive::Full->new();
		$stat->add_data ( [ @$row [@$cls2idx] ] ) ;

		my $cls2_med = $stat->median ;

		push @$rc_2ColMat, [$cls1_med, $cls2_med] ;
	}

	
	$progress->update(100) ;

	return ($rc_2ColMat) ;

}


sub removeRedundantGenesBySelectingHighAbsChangesInLog2Data {
	# $gNames can be gene names or probe names including redundant names.
	# $TwoColMat is a two column matrix including median vlaues for the classes in each gene name.
	# Remove redundacy by selecting the  highest  absolute log2 difference between the two classes.
        # Return the sorted nonredundant index

	my ($gNames, $TwoColMat) = @_ ;
	my $rc_index = [] ;	
	
	if( scalar @$gNames != scalar @$TwoColMat ) {
		print STDERR '#Serious Error. $gNames and $TwoColMat have different number of rows.',"\n";
		return([]) ;
	}	

        my $progress = Term::ProgressBar->new({name  => 'Redundancy Filtering', count => 100, ETA => 'linear' });
	$progress->minor(0) ;

	my $h_duplicated = {} ;
	foreach my $i ( 0 .. (scalar @$gNames -1) ) {
		push @{ $h_duplicated->{ $gNames->[$i] } }, $i ;
	}


	$progress->update(25) ;

	my $nonRed_idx = [] ;
	foreach my $g ( keys %$h_duplicated ) {

		my @rowIdx = @{ $h_duplicated->{$g} } ;
		my $maxDiff = -1000000000000;
		my $maxId = -2 ;

		foreach my $id (@rowIdx){

			my $absDiff = abs ( $TwoColMat->[$id]->[0] -  $TwoColMat->[$id]->[1] ) ;
			
			if($absDiff > $maxDiff){
				$maxDiff = $absDiff ;
				$maxId = $id ;
			}

		}	
		push @$nonRed_idx, $maxId ;
	}
	
	$progress->update(90) ;


	my $a_sorted_rc = [sort {$a <=> $b} @$nonRed_idx ];
	
	$progress->update(100) ;

	return $a_sorted_rc ;
}


sub removeRedundantGenesAndMakeTheirMedian{
	my $TwoDMatrix = $_[0] ;
	my $geneNames = $_[1] ;
	if(MMIA::Util::isEmptyArray($TwoDMatrix) < 0){
		return({}) ;
	}

	my $firstRow = $TwoDMatrix->[0] ;
	my $numCol = scalar @$firstRow;
	my $numRow = scalar @$TwoDMatrix ;
	my $rcHash = {} ;


        my $countMax = $numCol ; 
        my $progress = Term::ProgressBar->new({name  => 'Data rearranging', count => $countMax, ETA => 'linear' });
        $progress->minor(0);

	print 'Data rearranging processing ' ;

	foreach my $j (0 .. ($numCol -1)){

		my $geneHash = {} ;
		foreach my $i (0 ..($numRow -1)){
			my $gene = $geneNames->[$i] ;
			unless(exists($geneHash->{$gene})){
				my $stat = Statistics::Descriptive::Full->new();
				$stat->add_data($TwoDMatrix->[$i]->[$j]);
				$geneHash->{$gene} = $stat ;
			}else{
				my $stat = $geneHash->{$gene} ;
				$stat->add_data($TwoDMatrix->[$i]->[$j]);
			}	
		}
	
		foreach my $k (keys(%$geneHash)){
			my $stat = $geneHash->{$k} ;
			$rcHash->{$k}->[$j] = $stat->median() ;			
		}	
		if($j == int( ($numCol -1) /4 ) || $j == int( ($numCol -1) /2) || $j == int( ($numCol -1)*3/4 )){
			 print '<font color=red face=arial size=2>|</font>';
			$progress->update($j) ;
		}
	}
	print '<br />';
	$progress->update($countMax) ;
	return($rcHash);
}

sub getAnnotatedProbesInSipProbeNamesGivenCHIPFormat  {
	# The IDs in $chipFile and $probeNames of the SIP file should be the same platform 
	my ($chipFile, $probeNames) = @_ ;

	my $chip = MMIA::Util::importMITChipFormat ($chipFile) ;

	#print STDERR '# probes ', scalar keys %$chip ,"\n";

	my $rc = [] ;

	my $i = 0 ;
	for (@$probeNames) {

		push @$rc, $i if (exists ($chip->{$_}) ) ;
		$i ++ ;

	}

	# return annotated index in probesets in the Sip file	
	return ($rc) ;
}


sub assignGeneNamesToProbesByCHIPFormat {
	## probes : probes on the chip or exprMat
        ## chipFile : MIT CHIP platform file

	my ( $chipFile, $probes ) = @_ ;
	my $chip = MMIA::Util::importMITChipFormat ($chipFile) ;

	my $a_index = [] ;
	my $a_gnames = [] ;

	my $i = 0 ;
	for (@$probes ) {

		if( exists($chip->{$_}) ){
			
			my $gs = join (' /// ', @{$chip->{$_}}) ;
			push @$a_index, $i ;
			push @$a_gnames, $gs ;
	
		}		

		$i ++ ;

	}

	return ( [ $a_index, $a_gnames ] ) ;	

}


sub convertCustomProbesToAffyHgu133plus2 {
	my $customSipFile = shift @_ ;
	my $customArrayExprs = MMIA::Util::readLineByLineFormat( $customSipFile ) ;
	my $firstLine = shift @$customArrayExprs ;
	my $secondLine = shift @$customArrayExprs ;
	my $ids = [] ;
	foreach my $iids (@$customArrayExprs) {
		####BEGIN : modified 05182009 and  06012009
		next if ( $iids =~ /^#/ ) ;
	        my @info = split /\t/ , $iids ;
	        push @$ids,  uc (  MMIA::Util::removeQuotes( $info[0]) ) ;
		print STDERR uc(MMIA::Util::removeQuotes ($info[0])) ,"\n" if($errorLog == 1) ;
		####END
	}
	my $h_customIdToKg = HSA::mapCustomIdToKgGivenCustomId($ids, 'hg18') ; # key (custom arrary probe info) , value (an array reference with it corresponding Kg's)
	my $h_kgToCustomId = MMIA::Util::switchHashKeyAndArrayedValue($h_customIdToKg ) ;
	my $h_kgToHgu133plus2 = HSA::mapKgToHgu133plus2([ keys(%$h_kgToCustomId) ], 'hg18') ;

	my $h_transformed = {} ;
	foreach my $i (@$customArrayExprs){
	        my @info = split /\t/ , $i ;
		##BEGIN: modified in 06012009
	        #my $id = $info[0] ;
	        #my $kgs  = $h_customIdToKg->{$id} ;

                my $id = uc( $info[0] ) ;
                my $kgs = [];
                $kgs  = $h_customIdToKg->{$id} if (exists($h_customIdToKg->{$id} ) ) ;
                ##END
                #print STDERR 'info ', scalar(@info), ' kgs ',scalar(@$kgs) , ' id ',$id,"\n"   if ($errorLog == 1) ;



      		foreach my $j (@$kgs) {
	                my $probes = $h_kgToHgu133plus2->{$j} ;
       		        foreach my $k (@$probes){
                	        $h_transformed->{ join("\t", $k , @info[1 .. $#info])} ++;
                	}
        	}
	}
	
	my $a_rc = [] ;
	push @$a_rc, $firstLine ;
	push @$a_rc, $secondLine ;
	push @$a_rc, keys(%$h_transformed) ;
	$h_transformed = {} ; # dump memory

	return($a_rc) ;
}

sub removeSIPHeader{
	my $content = shift (@_) ; # content: 1-D array with the two header lines
	my $result = [@$content] ;
	shift(@$result) ; # pop up the class line
	shift(@$result) ; # pop up the sample line
	return($result) ;
}


sub runSiggeneFindRScript{
	my ($inFile, $log2, $pCutoff, $test, $multiple, $foldCutoff, $qCutoff, $siggeneOutFile) = @_ ;
	my $command = "$R --no-save -q --slave --args -p $pCutoff -l $log2 -t $test -m $multiple -f $foldCutoff -q $qCutoff -i $inFile -o  $siggeneOutFile < $sigGeneModule > /dev/null 2> ${siggeneOutFile}.err " ;
	my $commPid = open(COMM, '-|', $command) or return(-1)  ;
	eval{
		my $kid = -3 ;
	        my $t0 = [ gettimeofday ];
		print 'Sig. Gene. Test processing ' ;
		do{
			if( MMIA::Util::mitGSEATimer($t0, 300 ) ){
				print '<font color=red face=arial size=2>|</font>';
                                sleep(1.5) ;
			
			}
			$kid = waitpid($commPid, WNOHANG) ;
		} while $kid >= 0 ;
                print '<br />' ;


	};
	if($@){
		##Error happens
		close(COMM) ;
		sleep(0.1) ;
		return(-2) ;
	}
	close(COMM) ;
	sleep(0.1) ;
	return(1) ;
}

sub CRANHClusterWrapper{
	my ($inFile,  $bicluster, $outFilePrefix) = @_ ;
	my $command = "$R --no-save -q --slave --args -i $inFile -b $bicluster -o $outFilePrefix < $clusterModule";
	eval{
		my $commPid = open(OUT, '-|', $command) or return(-1);
		my $kid = -3 ;
		while(<OUT>){;}
		do{
			<OUT> ;
			$kid = waitpid($commPid, WNOHANG) ;
		}while  $kid >= 0 ;
	
		close(OUT) ;
	};
	if($@){
		##Error happens
		return(-2) ;
	}
	return(1) ;
}

sub filterMirSipFile{
        my ($species, $iFile) = @_ ;
        my @content = @{ readSipFile($iFile) } ;
        my @titleSip = @content[0 .. 1];

        my $filteredContent = [] ;

        if($species eq 'hsa'){
                $filteredContent = [ grep {$_ =~ /^hsa-mir/i || $_ =~ /^hsa-let/i } @content ];
        }elsif($species eq 'mmu'){
                $filteredContent = [ grep {$_ =~ /^mmu-mir/i || $_ =~ /^mmu-let/i } @content ];
        }else{
                $filteredContent = [ grep {$_ =~ /^rno-mir/i || $_ =~/^rno-let/i } @content ];
        }

        my $filtered = [] ;
        push @$filtered, @titleSip ;
        push @$filtered, @$filteredContent ;

        return $filtered ; # 1-D array including sip headers 
}

sub filterMirSipFileVer2{
        my ($species, $iFile) = @_ ;
        my @content = @{ readSipFile($iFile) } ;
        my @titleSip = @content[0 .. 1];

        my $filteredContent = [] ;

        if($species eq 'hsa'){
                $filteredContent = [ grep {$_ =~ /^hsa-mir/i || $_ =~ /^hsa-let/i } @content ];
        }elsif($species eq 'mmu'){
                $filteredContent = [ grep {$_ =~ /^mmu-mir/i || $_ =~ /^mmu-let/i } @content ];
        }else{
                $filteredContent = [ grep {$_ =~ /^rno-mir/i || $_ =~/^rno-let/i } @content ];
        }
	
	foreach my $i (0 .. ( scalar(@$filteredContent) -1 ) ){
		my @line = split /\t/, $filteredContent->[$i] ;
		my $mirName = $line[0] ;
		$mirName =~ s/\-star$|star$/\*/i ;
		$line[0]  = $mirName ;	
		$filteredContent->[$i] = join("\t", @line) ;
	}

        my $filtered = [] ;
        push @$filtered, @titleSip ;
        push @$filtered, @$filteredContent ;

        return $filtered ; # 1-D array including sip headers 
}


sub getNumOfSamplesForEachClassFromClsFormat{
	my $clsFile = shift @_ ;
	my $content = [];
	eval{
		 $content = MMIA::Util::readLineByLineFormat($clsFile) ;
	};
	if($@){
		return ([-1, -1]) ;
	}
	return ( getNumOfSamplesForEachClass ("#Class ". $content->[2]));
}

sub getNumOfSamplesForEachClass{
	# for example $cls ='#Class 0 0 1 0 1 1';
	my $cls = shift @_ ;
	my $a = [ split /\t/, $cls ] ;
	shift(@$a) ; # remove '#Class'

	my $h = {} ;
	my $total = scalar (@$a) ;
	my $n1 = $a->[0] ;
	foreach my $i (@$a){
		$h->{$i} ++ ;
	}
	
	my @t = grep {$_ eq $n1} @$a ;
	
	my $numC1 = scalar @t ;
	my $numC2 = $total - $numC1 ;
	
	return([$numC1, $numC2]) ;
}

sub getSampleIdsForEachClassFromSIP{
	# for example $cls ='#Class 0 0 1 0 1 1';
	my $sipFile = shift @_ ;
	my $cls = '' ;

	open (INPUT, $sipFile) or return([-1,-1]) ; 
	while(<INPUT>){
		chomp ;
		$_ = MMIA::Util::myTrim ($_) ;
		$cls = $_ ;
		last ;
	}
	close(INPUT) ;

	my $a = [ split /\t/, $cls ] ;
	shift(@$a) ; # remove '#Class'

	my $i = 0 ;

	my $c1_idx = [] ;
	my $c2_idx = [] ;

	my @samples = map { [$i ++ , $_] } @$a ;
	my $n1 = $a->[0] ;

	for (@samples) {
		if(  $n1 eq $_->[1]  ) {
			push @$c1_idx,  $_->[0] ;
		} else {

			push @$c2_idx, $_->[0] ;
		}

	}
	
	return ([$c1_idx, $c2_idx]) ;
}

sub getSampleIdsForEachClassFromSIPGivenClass1 {

	# for example $cls ='#Class c2 c1 c1 c1 c2 c2';
	my ($sipFile, $class1) = @_ ;
	my $cls = '' ;

	open (INPUT, $sipFile) or return([-1,-1]) ; 
	while(<INPUT>){
		chomp ;
		$_ = MMIA::Util::myTrim ($_) ;
		$cls = $_ ;
		last ;
	}
	close(INPUT) ;

	my $a = [ split /\t/, $cls ] ;
	shift(@$a) ; # remove '#Class'

	my $i = 0 ;

	my $c1_idx = [] ;
	my $c2_idx = [] ;

	my @samples = map { [$i ++ , $_] } @$a ;
	my $n1 = $class1 ; # Name for class 1

	for (@samples) {
		if(  $n1 eq $_->[1]  ) {
			push @$c1_idx,  $_->[0] ;
		} else {

			push @$c2_idx, $_->[0] ;
		}

	}
	
	return ([$c1_idx, $c2_idx]) ;
}



sub getProbesetToRefSeqGivenProbesetByAffyAnnotTable {

	my ($a_probes, $tablePrefix) = @_ ;
	my $table = $tablePrefix.'_Table_RefSeq_Gene' ;

	if(MMIA::Util::isEmptyArray($a_probes) < 0 ) {
		return({}) ;
	} 
	my $h_rc = {} ;

        my $dsn ="DBI:mysql:database=Affy;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dbh = DBI->connect($dsn,'MMIA') or die $DBI::errstr ;
	my $sql = "select distinct probeset, RefSeq_Gene from $table where probeSet in (\'". join("\',\'", @$a_probes  ) . "\')" ;	
	my $sth = $dbh->prepare($sql) or die $dbh->errstr ;
	$sth->execute ;
	my $a_rc_t = $sth->fetchall_arrayref ;

	foreach my $i (@$a_rc_t){
		my ($p , $r) = @$i ;
		push @{$h_rc->{$r }}, $p ;
	}
	
	$sth->finish ;
	$dbh->disconnect ;
	sleep(0.1) ;
	return($h_rc) ;

}


sub getProbesetToEntrezGivenProbesetByAffyAnnotTable {

	my ($a_probes, $tablePrefix) = @_ ;
        my $table = $tablePrefix.'_Table_Entrez';

	if(MMIA::Util::isEmptyArray($a_probes) < 0 ) {
		return({}) ;
	} 
	my $h_rc = {} ;

        my $dsn ="DBI:mysql:database=Affy;host=129.79.233.81;mysql_read_default_file=/etc/my.cnf";
        my $dbh = DBI->connect($dsn,'MMIA') or die $DBI::errstr ;
	my $sql = "select distinct probeset, entrez from $table where probeSet in (\'". join("\',\'", @$a_probes  ) . "\')" ;	
	my $sth = $dbh->prepare($sql) or die $dbh->errstr ;
	$sth->execute ;
	my $a_rc_t = $sth->fetchall_arrayref ;
	
	foreach my $i (@$a_rc_t){
		my ($p , $e) = @$i ;
		push @{$h_rc->{$e }}, $p ;
	}
	
	$sth->finish ;
	$dbh->disconnect ;
	sleep(0.1) ;
	return($h_rc) ;
}


1;
