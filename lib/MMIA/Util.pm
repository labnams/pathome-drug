package MMIA::Util ;

use strict ;

use lib  '/home/seokjong/lib/perl5/site_perl/MMIA' ;
use Time::HiRes qw(gettimeofday tv_interval);

sub makeDir {
	my $folder = shift @_ ;
	
	eval{
		if(! -e $folder ){
			system "mkdir $folder" ;	
		}
	};
	if($@){
		# assign system error code
		return (-1) ;
	} 
	return(1) ;
}

sub cpLocalFiles {
        my ($fName, $outDir) =  @_ ;
	eval{
        	system "cp $fName ${outDir}/" ;
	};
	if($@){
		# assign system error code 
		return (-1) ;
	}
        return(1) ;
}

sub checkHTTPREFERER{
	my $origin = $ENV{'HTTP_REFERER'} ;
	if($origin =~ m#^http://129\.79\.233\.81/#){
		;
	}elsif ($origin =~ m#^http://localhost/#) {
		;
	}else{
		## warning maybe a hacker
		return(-1) ;
	}
	return(1) ;
}

sub isEmptyArray{
	my $a = shift (@_) ;
	return(-1) unless ($a) ; # empty
	if (scalar @$a == 0){
		return(-2) ; #empty
	}
	return(1) ; # not empty
}

sub isEmptyHash{
	my $h = shift (@_) ;
	return (-1) unless ($h) ; # empty
	if( scalar( keys(%$h) ) == 0 ){
		return(-2) ; # empty
	}
	return(1) ; # not empty
}

sub sanitize {
    my $name = shift @_;
    my($safe) = $name=~/([a-zA-Z0-9._~#,]+)/;
    unless ($safe) {
	return(-1);
    }
    return (1);
}

sub timeInterval {
	my $t0 = shift @_ ;
	my $elapsed = tv_interval($t0);
	return($elapsed) ; ## seconds
}

sub mitGSEATimer{
	## $t0 : gettimeofday , $interval : interval secs ;
	my ($t0,  $interval ) =  @_ ;
        my $elapsed =  timeInterval( $t0 ) ;
        return( $elapsed % $interval  == 0   && int ($elapsed/$interval) > 0 ) ;	
}

sub measureProgress {
	my ($maxPos, $currentPos, $t0) = @_ ;
	my $completed = $currentPos / $maxPos  ;
	my $leftTime = 90 ; #  sec

	my $elapsed = timeInterval($t0) ; # floating secs
	if($currentPos < 1  ){
		;
	}elsif ($currentPos < $maxPos) {		
		$leftTime = (1-$completed)/$completed * $elapsed ;
	}else{
		$completed = 1 ;
		$leftTime = $elapsed ;
	}
	if($completed == 1){
		return [ $completed*100, $leftTime ] ;
	}
	return [ $completed*100, $leftTime*2 ] ; # completed percents, left time (sec)
}

sub progressUpdate{
	my ($maxPos, $currentPos, $t0, $msg) = @_ ;
	my ($completed, $leftTime) = @{ measureProgress($maxPos, $currentPos, $t0 ) } ;
	my $min = int($leftTime / 60 ) ;
	my $sec = int($leftTime - $min * 60) ;	
	if($completed == 100){
		return return( "$msg : ". int($completed) .' % completed '. $min .'  min '. $sec .' sec elapsed') ;
	}	
	return( "$msg : ". int($completed) .' % completed '. $min .'  min '. $sec .' sec left' );
}

######BEGIN: added in 04092009
sub progressUpdateGivenTime{
	my ($maxPos, $currentPos, $t0, $msg, $givenTime) = @_ ;  # givenTime is a reference of array such as [ 10 , 4 ]. 10(min) 4(sec)
	my ($completed, $leftTime) = @{ measureProgress($maxPos, $currentPos, $t0 ) } ;
	my $min = int($leftTime / 60 ) ;
	my $sec = int($leftTime - $min * 60) ;	
	if($completed == 100){
		return return( "$msg : ". int($completed) .' % completed '. $min .'  min '. $sec .' sec elapsed') ;
	}	
	return( "$msg : ". int($completed) .' % completed '. $givenTime->[0] .'  min '. $givenTime->[1] .' sec left' );

}
#####END: added


sub isFileChecked{ # proper file name check, file existed, file non-empty

	my $fname = shift (@_) ;
	if(! -f $fname ){ return(-1) ; }
	if( sanitize($fname) < 0 ) { return(-2) ; }
	if( ! -e $fname ) { return(-3) ; }
	if ( -z $fname ) { return(-4) ; } 

	open(IN, $fname) or return(-5) ;
	my $cc = [] ;
	my $numLineToRead =  3 ;
	my $i  = 0 ;
	while(<IN>){
		chomp() ;
		push @$cc, $_ ;
		if($i == $numLineToRead){ last ;}
	}
	close(IN) ;

	return(-6) if(isEmptyArray($cc) < 0) ;

	return(1) ;
}

sub getOnlyFileName{

	my $fname = shift @_ ;
	if($fname =~ m#.*/(.*?)$#){
		return($1) ;
	}

}

sub readLineByLineFormat{

	my $fname = shift( @_ ) ;
	my $rc = [] ;
	open(INPUT, $fname) or return($rc) ; # when an error occurs, return an empty array ref
	while(<INPUT>){
		chomp() ;
		next if(  /^\s{0,}$/ ) ;
		next if ( $_ eq '') ;
		my $trimmed = myTrim($_) ;
		push @$rc, $trimmed ;
	}	
	chomp(@$rc) ;
	close(INPUT) ;
		
	return($rc) ;
}

sub getClassDescriptionFromSIPFile{

	my $fname = shift(@_) ;
	my $rc = []  ;
	open(INPUT, $fname) or return ($rc) ; #When an error occurs, return an empty array ref
	my $i = 0 ;
	my $firstClass = '' ;
	my $secondClass = '' ;
	my $classLabel = [] ;

	while(<INPUT>){
		chomp() ;
		$_ = myTrim($_) ;
		if($i == 0 ){
			my @info = split /\t/ ;
			$classLabel = [ @info[1 .. $#info] ] ;
			$firstClass = $info[1] ;

			my %tmpHash = () ;
			foreach my $j ( @$classLabel ){
				$tmpHash{$j} ++ ;
			}
			delete $tmpHash{$firstClass} ;
			my @tmp = keys(%tmpHash) ;	
			
			$secondClass = shift( @tmp );
			
			$i ++ ;
			next ;

		}
		if($i == 1){

			my @sample = split /\t/ ;
			my $sampleLabel = [ @sample[1 .. $#sample] ];
			my $c1 = [] ;
			my $c2 = [] ;
			if( scalar(@$sampleLabel) != scalar(@$classLabel) ){
				print 'Big problem in SIP format <br />';
				exit(0) ;
			}			

			foreach my $j (0 .. (scalar @$sampleLabel -1)){
				if($classLabel->[$j] eq $firstClass){
					push @$c1 , $sampleLabel->[$j] ;	
				}else{
					push @$c2 ,  $sampleLabel->[$j] ;
				}
			}
			$rc = [$c1, $c2];
			last ;
		}	
	}

	close(INPUT) ;
	
	return($rc) ;	

}

sub readMyCSV{
        my $fname = shift @_ ;
        my $rc = [] ;
        open(IN, $fname ) or die "cannot open a file $fname" ;
        while(<IN>){
                chomp;
		if(  /^\s{0,}$/ ){ next ;}
                my $t = [ split /,/ ];
                push @$rc, $t ;
        }
        close(IN) ;
        return($rc) ;
}

sub readMyTSV {
        my $fname = shift @_ ;
        my $rc = [] ;
        open(IN, $fname ) or die "cannot open a file $fname" ;
        while(<IN>){
 		chomp;
		if(  /^\s{0,}$/ ){ next ;}
		my $t = [ split /\t/ ] ;
		push @$rc, $t ;	
	}
	close (IN) ;
	return ($rc) ;
}



sub readMyTripleCSV{
        my $fname = shift @_ ;
        my $a_rc = [] ;
        open(INPUT, $fname) or die "cannot open a file $fname\n";
        while(<INPUT>){
                chomp() ;
		if(  /^\s{0,}$/ ){ next ;}
		next if($_ eq '') ;
                my $info = [split /\,{3}/] ;
                push @$a_rc ,$info ;
        }
        close(INPUT) ;
        return($a_rc) ;
}

sub readTSV{
	my $fname = shift @_ ;
        my $a_rc = [] ;
        open(INPUT, $fname) or die "cannot open a file $fname\n";
        while(<INPUT>){
                chomp() ;
		if(  /^\s{0,}$/ ){ next ;}
		next if($_ eq '') ;
                my $info = [split /\t/] ;
                push @$a_rc ,$info ;
	}
        close(INPUT) ;
        return($a_rc) ;

}

sub getElemFrom2DArray{
	my ($twoDArr, $indexToFetch)  = @_ ;  # $indexToFetch : 0-based 
	my $rc = [] ;
	foreach my $i (@$twoDArr){
		push @$rc, $i->[ $indexToFetch ] ;
	}

	return($rc) ;
}

sub getSetAMinusSetB { # set A - set B
	# pre-condition
        # $setA and $setB are array containing uniq elements

	my ($setA, $setB ) = @_ ;
	my $h_isect = getIntersection($setA, $setB) ;
	if(isEmptyHash($h_isect) < 0 ){ # no intersection exists
		return($setA) ;
	}
	my $AMinusB = [ grep { ! exists( $h_isect->{$_} ) } @$setA ] ;	
	return( [] ) unless($AMinusB) ;
	return($AMinusB) ;
}

sub getIntersection{
	# return hash
        # pre-condition
        # Each set has non-redundant elements. Also case insensitive comparison
	# $setA and $setB are array containing uniq elements
        my ($setA, $setB)  = @_ ; 
        my $h_union  ;
        my $h_intersection  ;

        foreach my $e (@$setA, @$setB){
                $h_union->{uc $e} ++ && $h_intersection->{uc $e} ++
        }

        if($h_intersection){
                return ($h_intersection) ;
        }else{
                return({}) ; # no elements in intersection
        }
}

sub getIntersectionWithCaseSensitive{
        # return hash
        # pre-condition
        # Each set has non-redundant elements. Also case sensitive comparison
        # $setA and $setB are array containing uniq elements
        my ($setA, $setB)  = @_ ;
        my $h_union  ;
        my $h_intersection  ;

        foreach my $e (@$setA, @$setB){
                $h_union->{$e} ++ && $h_intersection->{$e} ++
        }

        if($h_intersection){
                return ($h_intersection) ;
        }else{
                return({}) ; # no elements in intersection
        }
}


sub getIntersectionWithCaseOption{
	my ($setA, $setB, $caseOption) = @_ ;
	if($caseOption eq 'i'){ # case insensitive
		getIntersection($setA, $setB) ;
	}else{
		getIntersectionWithCaseSensitive($setA, $setB ) ;
	}
}

###BEGIN : added in 03/22/2009
sub getAllUniqHashValuesInHashTripleSlashSepValFormat{
        my $h_h = shift @_ ;
        my $h_t ={} ;
        my $a_rc = [] ;
        foreach my $i (keys(%$h_h)){
                my $val = $h_h->{$i} ;
                my $a_tmp = [ split /\s\/\/\/\s/, $val ];
                foreach my $j (@$a_tmp){
                        $h_t->{$j} ++ ;
                }
        }
        $a_rc = [ keys(%$h_t) ];

        return($a_rc) ;
}
###END

sub getAllUniqHashValuesInHashCommSepValFormat{
        my $h_h = shift @_ ;
        my $h_t ={} ;
	my $a_rc = [] ;
        foreach my $i (keys(%$h_h)){
		my $val = $h_h->{$i} ;
		my $a_tmp = [ split /,/, $val ];
		foreach my $j (@$a_tmp){
			$h_t->{$j} ++ ;
		}
	}
	$a_rc = [ keys(%$h_t) ];

	return($a_rc) ;
}

sub getAllUniqHashValuesInHashArrayFormat{
	my $h_h = shift @_ ;
	my $h_t = {} ;
	foreach my $i (keys(%$h_h)){
		my $arr = $h_h->{$i} ;
		foreach my $j (@$arr){
			$h_t->{$j} ++ ;
		}
	}	
	my $a_rc = [];
	$a_rc = [keys(%$h_t)];
	$h_t ={} ; # dump memory
	return($a_rc) ;
}

sub switchHashKeyAndArrayedValue{

	my $h_in = shift @_ ; ### value is an array reference
	my $h_rc= {} ;
	my $h_tmp = {} ;
	return {} if(isEmptyHash($h_in) < 0) ;
	foreach my $k ( keys(%$h_in) ) {
		my $val = $h_in->{ $k } ;
		foreach my $j (@$val){
			$h_tmp->{ $j }->{ $k }++ ;
		}
	}
	foreach my $k ( keys(%$h_tmp) ) {
		my $h_t2 = $h_tmp->{ $k } ;
		$h_rc->{$k}  = [ keys(%$h_t2) ];		
	}
	return($h_rc) ;

}

sub getUniqListFromArray{
	my $a = shift @_ ;
	my %seen = () ;
	my $a_uniq = [ grep { ! $seen{$_} ++ } @$a ];	
	return($a_uniq) ;
}

sub getUniqListFromHashKey{
	my $h = shift @_ ;
	return( getUniqListFromArray([keys(%$h)]) );
}

sub getUniqListFromArrayInCaseInsensitive {
	my $a = shift @_ ;
	my %seen = () ;
	my $a_uniq = [ grep { ! $seen{uc $_} ++ } @$a ] ;
	return($a_uniq) ;	

}

sub writeLineByLineFormat {
	my ($a_content, $fname) =  @_ ;

	open(OUT, '>' , $fname) or return (-1) ; # error occurs 
	print OUT join("\n", @$a_content) ,"\n" ;
	close(OUT) ;

	sleep(0.1) ;
	return(1) ;
}


sub makeHashFromTwoColTSV{ # should be first column unique. 
	## watch out hash key was converted to uppercase.
        my $iFile = shift @_ ;

        my $h_rc = {} ;
        my $a_rc = readLineByLineFormat($iFile) ;

        return($h_rc) if (isEmptyArray($a_rc) < 0) ;

        foreach my $i (@$a_rc){
                my @t = split /\t/ , $i ;
                $h_rc->{uc($t[0])} = $t[1] ;
        }
        return($h_rc) ;
}


sub transform1DFormatTo2DMatrix{
        my $content = shift(@_) ; # content: It doesn't matter whether or not the 1-D array has the header lines
        my $TwoDMatrix = [] ;
        foreach my $i (@$content){
                if($i =~ /^#/){next;}
                my @info = split /\t/, $i ;
                push @$TwoDMatrix , [@info[1 .. $#info]] ;
        }

        return ($TwoDMatrix) ;
}




sub makeHashFromGivenTwoColIndexWithFileName { # should be the key column unique ; idx should be 0-based
	my ($fname, $keycolidx, $valcolidx) = @_ ; 
	my $content = readLineByLineFormat ($fname) ;
	
	my $h_rc = {}; 
	for ( @$content ) {
		$_ = [ split /\t/ ];
		my $k = $_->[$keycolidx] ;
		my $v =  $_->[$valcolidx] ;
		$h_rc->{$k}= $v ;
	} 

	return $h_rc ;
}

sub makeHashFromTwoColTSVWithFirstColUniqIdAndSecondColCommaSep{ # should be first column unique
	my $iFile = shift @_ ;

        my $h_rc = {} ;
        my $a_rc = readLineByLineFormat($iFile) ;

        return($h_rc) if (isEmptyArray($a_rc) < 0) ;

        foreach my $i (@$a_rc){
		my @tt = split /\t/, $i ;
		my $name = $tt[0] ;
                my @t = split /,/ , $tt[1] ;
		$h_rc->{ $name } = [@t] ;
	}

	return($h_rc) ;
}

sub describe2By2TableToSentence{
        my $array2D = shift @_ ;  # array of [description ,n11, n1p, np1, npp] ;
        my $a_rc = [] ;
        foreach my $i (@$array2D){
                my ($d, $n11, $n1p, $np1, $npp, $p) = @$i ;
                push @$a_rc ,[$d, [$n11, $n1p], [$np1, $npp], $p] ; # description , n11 out of n1p (observation), np1 out of npp (background), p-val
        }
        return($a_rc) ;
}

sub upperCaseToHashKeys{
	my $h = shift @_ ;
	my $h_rc = {} ;
	foreach my $k (keys(%$h)){
		$h_rc->{uc $k} = $h->{$k} ;
	}
	return($h_rc) ;
}



### BEGIN : added in Mar/22/2009
sub linkTwoHashes{
	# watch out  character case
	# hashOne->{ keyA } = "id_1 /// id2" ;
	# hashTwo->{id_1} = "val_1 /// val_2" ;
        # hashTwo->{id_2} = "val_2 /// val_4" ;
	# => h_rc -> {keyA} = "val_1 /// val_2 /// val_4" 
	my ($h_one, $h_two) = @_ ;
	my $h_rc = {} ;
	

	foreach my $k (keys(%$h_one)){

		my $arr = [split /\s\/\/\/\s/, $h_one->{$k} ] ;
		my $h_tmp = {} ;

		foreach my $e (@$arr){
			my $a_t = [ split  /\s\/\/\/\s/, $h_two->{$e} ] ;						
			foreach my $e2 (@$a_t){
				$h_tmp->{uc $e2 } ++ ;
			}
		}
		next if(isEmptyHash($h_tmp) < 0 );
		$h_rc->{$k} = join(" /// ", keys(%$h_tmp) ) ;
	}

	return($h_rc) ;
}
### END

sub replaceEquivKeysFromTwoHashes{
	## hashOne->{ keyA } = valueA ; 
        ## hashTwo->{keyA} = [newKeyA.1 , newKeyA.2 ];
	## => result : hashOne -> {newKeyA.1} = valueA
	my ($hashOne, $hashTwo) = @_ ;
	my $h_rc = {} ;
	$hashOne = upperCaseToHashKeys($hashOne) ;
	$hashTwo = upperCaseToHashKeys($hashTwo) ;
	
	foreach my $k (keys(%$hashOne)){
		next unless(exists($hashTwo->{$k})) ;
		my $a_temp = $hashTwo->{$k} ;
		foreach my $e (@$a_temp){
			$h_rc->{$e} = $hashOne->{$k} ;	
		}
	}
	return ($h_rc) ;
}


sub getNumOfSamplesForClass{
	# before calling the function, "isCorrectMySIPFormat" would be called first
	my  $sipFile = shift @_ ;
	open( IN, $sipFile) or return ([]) ;
	my $t_h = {} ;
	while(<IN>){
		chomp() ;
		$_ = myTrim($_) ;
		my @info = split /\t/ ;
		foreach my $j (@info[ 1 .. $#info ]){
			$t_h->{$j} ++ ;
		}
		last ;	
	}
	close(IN) ;
	return([values(%$t_h)]) ;
}

sub isCorrectMySIPFormat{
	my $sipFile = shift @_ ;
	if(isFileChecked($sipFile) < 0){
		return(-1) ;
	}
		
	my $a_content = readLineByLineFormat ( $sipFile ) ;
	if(isEmptyArray( $a_content) < 0){
		return(-2) ;
	}
	if( scalar(@$a_content) < 3 ){
		return(-3) ;
	}
	my $numSamples = 0 ;
	foreach my $i (0 .. (scalar(@$a_content) -1)){
		my $line =  $a_content->[$i]  ;
		chomp($line) ;
		if($line eq ''){ next ;}

		if($i == 0){
			my @info = split /\t/, $line ;
			$numSamples = scalar(@info) -1 ;
			my $h_t = {} ;
			if( $line =~ /^#Class/ ){
				foreach my $i (@info[ 1 .. $#info] ){
					$h_t->{$i} ++ ;
				}	
				return (-3.1) if(scalar(keys(%$h_t)) != 2) ; ### check two class format
				
			}else{
				return(-4) ;
			}

		}elsif($i == 1 ){
			my @info = split /\t/, $line ;
			my $t_numSamples = scalar(@info) -1 ;
			return (-5) if( $numSamples != $t_numSamples ) ; 

			if ($line =~ /^#NAME/){
				;
			}else{
				return(-6) ;
			}
		}else{
			my @info = split /\t/, $line ;	
			my $t_numSamples = scalar(@info) -1 ;
			return (-7 )  if( $numSamples != $t_numSamples ) ;
			foreach my $elm (@info[ 1 .. $#info ] ){
				return (-8) unless (is_numeric($elm)) ;
			}
		}

	}
	$a_content = [];
	return(1) ;

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
		if($num == 0) {$num="0.0";}
                return $num ;
        }
}

sub is_numeric{
        defined scalar &getnum
}



sub myTrim{
	my $string = shift @_ ;
	$string =~ s/^\s+|\s+$//g ;
	return($string) ;	
}



####BEGIN : 05182009 added
sub removeQuotes {
	my $a = '';
	eval{
	
		$a = shift @_ ;
		$a= myTrim ($a) ;
		$a =~ s/'|"//g ;
		return ($a) ;
	};
	if($@){
		$a= 'dummy' ;
	} 
	
	
	return ($a) ;
}
###END


####BEGIN : 06292009 added
sub makeHashFromTwoColFormatByTripleSemiColon {
	### Before calling the function, check whether or not the input file has contents.
        # input format ( for example: /home/tonamswish/RAWDATA/AffyAnnotation/hgu133plus2/hgu133plus2_Table_RefSeq_Gene )
        # First column doesn't need to be unique
	# All data was transformed to "uppercase"
        # Ouput : h_rc : key "AffyId;;;NM_xxxxx", value : number of occurrence

	my ($iFile , $numOfSkipped)  =  @_ ;


	my $h_rc = {} ;

	my $content =  readLineByLineFormat ($iFile) ;

	return $h_rc if( scalar (@$content) <=  $numOfSkipped ) ; 
	
	$content = [ @$content [ $numOfSkipped .. (scalar @$content -1  ) ] ] ;

	foreach my $i (@$content){
		$h_rc->{uc $i} ++ ;
	}
	
	return($h_rc) ;


}
####END



sub importMITChipFormat{
        # The first column in the chip format should be unique according to MIT GSEA
        my $chipFile = shift @_ ;
        my $h_rc = {} ;
        open(CHIP, $chipFile) or return({}) ; # error occurs and return an empty hash
        while(<CHIP>){
                chomp ;
		$_ = myTrim ($_) ;
                if(/^Probe/){ next ;}
                my @info = split /\t/ ;
                my $probe = $info[0] ;
		next if($info[1] eq '') ;
                next if($info[1] eq '---') ;
		next if($info[1] eq 'NA') ;
                my $a_gs = [split /\s\/\/\/\s/ , $info[1] ] ;
                $h_rc->{$probe} = $a_gs ;
        }
        close(CHIP) ;
        return($h_rc) ;
}


sub getClassesAndSamplesFromSIPFormat {
	my $sipFile = shift @_ ;

	open(INPUT, $sipFile) or return([]) ;

	my $i = 0;
	my $descriptions = [] ;

	while(<INPUT>){
		last if ($i > 1) ;
		chomp ;
		$_ = myTrim ($_) ;

		my $info = [ split /\t/ , $_ ]  ;	
		push @$descriptions , $info ;		


		$i ++ ;
	}
	close(INPUT) ;

	return $descriptions ;
}


sub fisherTransformationOfCorr{

	my $r = shift (@_) ;

	if($r == 1 ){
		$r = 0.999999 ;
	}
	if($r == -1 ){
		$r = -0.999999 ;
	}

	return 0.5* log( (1+$r) / (1-$r) ) ;

}


sub calCorrCoef {
        my ($vec1, $vec2) = @_ ;

        my $stat = Statistics::Descriptive::Full->new() ;
        $stat->add_data($vec1) ;
        my ($q, $m, $r, $rms) = (0, 0, 0, 0) ;
        eval {
                ($q, $m, $r, $rms) = $stat->least_squares_fit( @$vec2 ) ;

                if( (abs $r) > 1) {
                        $r = -4 ; # error_code
                }
        } ;

        if($@){
                $r= -6; # error_code
        }

        if(! defined $r ){
                $r = -7 ; # error_code
        }

        return $r ;
}

sub isFileNonzero {
        my $fname = shift @_ ;
        if( -e $fname ){
                if ( -s $fname  ) {
                        return 1 ;
                }

        }
        return -1 ;
}


1;
