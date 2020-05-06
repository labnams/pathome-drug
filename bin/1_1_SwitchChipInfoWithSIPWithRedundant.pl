#!/usr/bin/perl
=pod

=head2 Make .genesymbol.redundant.sip from a redundant sip file; Redundancy still existed; This script was generated for PATHOME-webserver testing.

=head2 Input files

=over 1

=item *
SIP format file

=item *
CHIP format file

=item *
Option: already log2 transformed?

=back

=head2 Output file

=over 1

=item *
Redundant SIP format file with the switched gene symbol

=back



=head2 History

=over 1 


=item *
2014-11-19 2_MakeNRExprData.pl was modified to this script for generating redundant gene symbol sip format. It was used for PATHOME web-server input file testing; This file was originally located in KISTI:/pwork01/seokjong/home_backup_darthvader

=back


=cut

# Hisotry
# created by tonamswish
use strict ;

use lib '/var/www/software/pathome/lib' ; # '/home/seokjong/lib/perl5/site_perl' ;


use MMIA::Preprocessing qw();
use MMIA::Util qw(getClassesAndSamplesFromSIPFormat);
use Getopt::Long;


my $sipFile = '/pwork01/seokjong/home_backup_darthvader/DrParkMaterial/Materials/GSE13861.sip';
my $chipFile = '/pwork01/seokjong/home_backup_darthvader/DrParkMaterial/Materials/ilmn_HumanWG_6_V3_0_R3_11282955_A.chip';
my $log2 = 1; # set to 1('-l' option) if data is already log2 transformed
my $verbose = 0;
GetOptions("sip|i=s" => \$sipFile,
	"chip|c=s" => \$chipFile,
	"log2|l" => \$log2,
	"verbose|v" => \$verbose);

if( ! $sipFile || ! -r $sipFile ){
	die "cannot read SIP file";
}
if( ! $chipFile || ! -r $chipFile ){
	die "cannot read CHIP file";
}

### Read a sip file
my $content = MMIA::Preprocessing::readSipFile ($sipFile) ;
my $exprMat = MMIA::Preprocessing::transform1DSipFormatTo2DMatrix ($content) ;
my $rowNames = MMIA::Preprocessing::getGeneNames ($content) ;
print STDERR join(' ', 'First', scalar @$content, scalar @$exprMat, scalar @$rowNames) , "\n";

### Remove Unnecessary probes like controls
my $annotRowIds = MMIA::Preprocessing::getAnnotatedProbesInSipProbeNamesGivenCHIPFormat ($chipFile, $rowNames) ;
$rowNames = [ @$rowNames [@$annotRowIds] ]   ; ## probeset
$exprMat =  [ @$exprMat [@$annotRowIds] ] ; 
print STDERR join(' ', 'Second', scalar @$rowNames) , "\n";

my $geneIndex;
my $log2ExprMat;


#### log2 transfromation
if( $log2 == 0 ){
	($geneIndex, $log2ExprMat) = @{ MMIA::Preprocessing::log2Transform ($exprMat) } ;
	$rowNames = [ @$rowNames [@$geneIndex] ] ; ## probeset
	print STDERR join (' ', 'Third' , scalar @$rowNames ), "\n";
} else {
	$log2ExprMat = $exprMat;
}
### Assign a gene symbol into each row name.
### $a_index, $a_geneSymbol are the same order.
my ($a_index, $a_geneSymbol) = @{MMIA::Preprocessing::assignGeneNamesToProbesByCHIPFormat($chipFile, $rowNames)} ; # index, and gene_symbol
$rowNames = [ @$rowNames [@$a_index] ]   ; # affy probeset
$log2ExprMat = [ @$log2ExprMat [@$a_index]  ] ;
print STDERR join(' ', 'Fourth', scalar @$rowNames, scalar @$a_geneSymbol), "\n";






### 3) Write non-redundant sip
my $top2Lines = MMIA::Util::getClassesAndSamplesFromSIPFormat ($sipFile) ;

foreach my $i (@$top2Lines){
        print join("\t", @$i) ,"\n";
}

foreach my $i (0 .. ( scalar @$a_index - 1 )) {
        print join("\t", $a_geneSymbol->[$i], @{$log2ExprMat->[$i]}),"\n";
}

