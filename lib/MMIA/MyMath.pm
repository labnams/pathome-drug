package MMIA::MyMath ;

use strict ;
use Statistics::Descriptive;
use Term::ProgressBar;

sub getFoldChangeBetweenTwoClassesGivenOneDataRowAndClassLabelWithOption{
	my ($dataRow, $classLabel, $scale) = @_ ;

	if($scale eq 'log2'){
		my $tmp = [];
		foreach my $i (@$dataRow){
			push @$tmp, 2**$i ;
		}
		return ( getFoldChangeBetweenTwoClassesGivenOneDataRowAndClassLabel($tmp, $classLabel) ) ;
	} else { # linear scale
		return ( getFoldChangeBetweenTwoClassesGivenOneDataRowAndClassLabel($dataRow, $classLabel) ) ;
	}
}


sub getFoldChangeBetweenTwoClassesGivenOneDataRowAndClassLabel{
	## The data assumes a linear scale
	my ($dataRow, $classLabel) = @_ ;
	my $h_class ={} ;	
	my $firstClass = $classLabel->[0] ;
	my $secondClass = '' ;
	foreach my $e (@$classLabel){
		$h_class->{$e} ++ ;
	}
	return (-0.5) unless (Util::is_numeric ($dataRow) ) ;
	return (-1) if(scalar( keys(%$h_class) ) != 2)  ; # error happens and return a negative value.
	return (-2) if (scalar(@$dataRow) != scalar (@$classLabel)) ; # num of data discrepancy, return a negative value.
	foreach my $k (keys(%$h_class)){
		next if ($k eq $firstClass) ;
		$secondClass = $k ;
	}
	my $c1Arr = [] ; 
	my $c2Arr = [] ;
	foreach my $id (0 .. (scalar(@$dataRow)-1) ){
		
		if($dataRow->[$id] <= 0 ){
			return( -2.5) ;
		}

		if( $firstClass eq $classLabel->[$id] ){
			push @$c1Arr , $dataRow->[$id] ;	
		} else {
			push @$c2Arr , $dataRow->[$id] ;	
		}	
	}	

	my $stat = Statistics::Descriptive::Full->new() ;
	$stat->add_data($c1Arr) ;
	my $c1Med = $stat->median() ;
	$stat = Statistics::Descriptive::Full->new() ;
	$stat->add_data($c2Arr) ;
	my $c2Med = $stat->median() ;

	if(Util::is_numeric ($c1Med) && Util::is_numeric($c2Med) ){
		if ($c1Med != 0 ){
			return($c2Med/$c1Med) ;
		}else {
			return(-3) ;
		}

	} else {
		return(-4) ;
	}	
}


sub getDescriptiveStatisticsExtended {
# obtain    mean, [0, 5, 10, 25, 50, 75, 90, 95, 100] percentiles
	my $data = shift @_ ;
	
	my $percents = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100] ;
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data ($data) ;
	$stat->sort_data() ;
	$stat->presorted() ;
	
	my $a_rc = [] ;

	push @$a_rc , $stat->mean() ;
	foreach my $p (@$percents){
		
		my $val_index = [] ;

		if($p == 0) {
			push @$a_rc , $stat->min() ;
		} elsif ($p == 100) {
			push @$a_rc , $stat->max() ;
		} else {
			$val_index = [ $stat->percentile($p) ] ;
			push @$a_rc, $val_index->[0] ; 
		}
	}

	return( $a_rc );	

}


sub getDescriptiveStatistics {
# obtain mean, [0, 5, 10, 25, 50, 75, 90, 95, 100] percentiles
	my $data = shift @_ ;
	
	my $percents = [0, 5, 10, 25, 50, 75, 90, 95, 100] ; 
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data ($data) ;
	$stat->sort_data() ;
	$stat->presorted() ;
	
	my $a_rc = [] ;

	push @$a_rc , $stat->mean() ;
	foreach my $p (@$percents){
		
		my $val_index = [] ;

		if($p == 0) {
			push @$a_rc , $stat->min() ;
		} elsif ($p == 100) {
			push @$a_rc , $stat->max() ;
		} else {
			$val_index = [ $stat->percentile($p) ] ;
			push @$a_rc, $val_index->[0] ; 
		}
	}

	return( $a_rc );	

}


sub getPercentiles{

	my ($data, $percents) =@_ ;
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data ($data) ;
	$stat->sort_data() ;
	$stat->presorted() ;
	
	my $a_rc = [] ;

	foreach my $p (@$percents){
		
		my $val_index = [] ;

		if($p == 0) {
			push @$a_rc , $stat->min() ;
		} elsif ($p == 100){
			push @$a_rc , $stat->max() ;
		} else{
			$val_index = [ $stat->percentile($p) ] ;
			push @$a_rc, $val_index->[0] ; 
		}
	}
	return( $a_rc );	
}

sub getSD { # division by n-1.

	my $data = shift @_ ;
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data ($data) ;
	my $sd = $stat->standard_deviation() ;
	return ($sd) ;
}

sub getMedian{

	my $data = shift @_ ;
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data ($data) ;
	my $median = $stat->median() ;	
	return ($median) ;
}


sub getMin{

	my $data = shift @_ ;
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data ($data) ;
	my $min = $stat->min() ;
	return ($min) ;
}


sub getMean{

	my $data = shift @_ ;
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data ($data) ;
	my $mean = $stat->mean() ;
	return ($mean) ;

}

sub getMax{

	my $data = shift @_ ;
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data ($data) ;
	my $max = $stat->max() ;
	return ($max) ;
}


sub getLog2Array {

	my $data = shift @_ ; # array reference
	my $a_rc = []; 

	foreach my $a ( @$data ) {
		push @$a_rc , log($a)/log(2) ;
	}

	return ($a_rc) ;
}


sub oneMinusCos{

	my ($vec1, $vec2) = @_ ;
	return( 1 - inner($vec1,$vec2) / norm ($vec1) / norm ($vec2) ) ;
}

sub myCosine {

	my ($vec1, $vec2) = @_ ;
	return(  inner($vec1,$vec2) / norm ($vec1) / norm ($vec2) ) ;
}

sub inner {

	my ($vec1, $vec2) = @_ ;
	my $sum = 0 ;

	foreach my $i ( 0 .. (scalar @$vec1 -1 ) ){
		$sum += $vec1->[$i] * $vec2->[$i] ;
	}

	return ( $sum ) ;

}

sub norm {

	my $vec = shift @_ ;
	my $sqSum = 0 ;

	foreach my $i (@$vec){
		$sqSum += $i ** 2
	}

	return ( $sqSum ** 0.5 );

}

sub getLog2 {
	my $a = shift(@_)  ;

	return ( log($a) / log(2) ) ;
}


sub zNormalize {
        my ($mean, $sd, $val) = @_ ;

        return(  ($val - $mean)/ $sd ) ;
}



1 ;
