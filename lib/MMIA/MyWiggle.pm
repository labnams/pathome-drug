package MMIA::MyWiggle ;

use strict ;
use lib  '/home/seokjong/lib/perl5/site_perl/MMIA' ;
use POSIX ":sys_wait_h";
use MMIA::Util ;


sub getDataPoints {

	my ($lcd, $wigName, $posString, $outName) = @_ ; # Postion coord could be a 1-based.

	#sh runHgWiggle.sh /home/tonamswish/Research2009/MCF7TR_MCF7_ChIPSeq/WIGWIBPAIR -position=chr1:1-247249719 JW01.wig /tmp/my.temp

	my $command =  "sh /home/tonamswish/PERLLIB/runHgWiggle.sh  $lcd  -position=${posString} $wigName  $outName" ;

	#print STDERR  $command, "\n";

        my $commPid = open(COMM2, '-|', $command) or die "cannot execute $command\n";
        my $kid  = -3 ;

        do{
                $kid = waitpid($commPid, WNOHANG) ;
        }while $kid >=0 ;

        close(COMM2) ;

	sleep(0.1) ;

	return;
}

sub getDataPointsGivenBed{

	my ($lcd, $bedInput, $wigName, $outFile) = @_ ;

	my $command = "sh /home/tonamswish/PERLLIB/runHgWiggleGivenBed.sh $lcd $bedInput $wigName  $outFile" ;	

	my $commPid = open (COMM2, '-|', $command) or die "cannot execute $command\n";
	my $kid = -3 ;

	do{
		$kid = waitpid ($commPid, WNOHANG) ;
	} while $kid >= 0 ;
		
	close(COMM2) ;

	sleep(0.1) ;

	return ;	
}


sub readTwoColWigAndMakeHashWithSpanOne{
	my $wigFile = shift @_ ;
	my $h_rc = {} ;

	return $h_rc if(!( -e  $wigFile ) || -z $wigFile) ;
	open(IN, $wigFile) or die "serious error in reading\n" ;

	while(<IN>){
		chomp;
		next if (/^#/) ;
		if(/^variableStep/ || /^fixedStep/ ){
			#print STDERR join ("\t", $wigFile, $_) ,"\n";
			next ;
		}
		
		my @info = split /\s+/ , $_ ;
		
		$h_rc->{ $info[0] } = $info[1] ;
	}


	return($h_rc) ;
}


1 ;



