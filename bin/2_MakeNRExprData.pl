#!/usr/bin/perl
=pod

=head2 Make .nr.sip from a redundant sip file.

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
Non-redundant SIP format file

=back



=head2 History

=over 1 

=item *
2012-04-16 /cluster/bio/MMIA/1_GEOtoNRSIP/2_MakeNRExprData.pl was copied here. Library path was rearranged.

=back


=cut

# Hisotry
# created by tonamswish
use strict ;

use lib '/var/www/software/pathome/lib' ; # '/home/seokjong/lib/perl5/site_perl' ;


use MMIA::Preprocessing qw();
#use GSEA;
use MMIA::Util qw(getClassesAndSamplesFromSIPFormat);
use Getopt::Long;

my $sipFile = '/home/seokjong/DrParkMaterial/Materials/GSE13861.sip';
my $chipFile = '/home/seokjong/DrParkMaterial/Materials/ilmn_HumanWG_6_V3_0_R3_11282955_A.chip';
my $log2 = 0; # set to 1('-l' option) if data is already log2 transformed
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
print STDERR $log2 , "\n";
if( $log2 == 0 ){
	print STDERR "LOG2-TRANSFORM\n";
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

### Remove redundant gene symbols by high or low fold changes
### 1) get medians between two classes
my ($c1idx, $c2idx) = @{MMIA::Preprocessing::getSampleIdsForEachClassFromSIP($sipFile)} ;
my $twoColExprMat = MMIA::Preprocessing::obtain2ColMedExprBetween2Classes ($log2ExprMat , $c1idx, $c2idx) ;
print STDERR join(" ",'class1idx',  @$c1idx) ,"\n";
print STDERR join(" ", 'class2idx', @$c2idx), "\n";

### 2) select high abs change genes between the two classes for the duplicated probes
if( scalar @$a_geneSymbol != scalar @$twoColExprMat ){
        print STDERR 'ERROR_000100: Serious Error. @$a_geneSymbol != scalar @$twoColExprMat',"\n";
        exit(-1) ;
}
my $nonRed_idx = MMIA::Preprocessing::removeRedundantGenesBySelectingHighAbsChangesInLog2Data ($a_geneSymbol, $twoColExprMat) ;
print STDERR join(' ', 'Fifth', scalar @$nonRed_idx), "\n";
my @nonRed_gs = @$a_geneSymbol [@$nonRed_idx] ;
my @probesForNonRed_gs = @$rowNames[@$nonRed_idx] ;
my $nonRed_log2ExprMat = [ @$log2ExprMat [@$nonRed_idx] ] ;

### 3) Write non-redundant sip
my $top2Lines = MMIA::Util::getClassesAndSamplesFromSIPFormat ($sipFile) ;

foreach my $i (@$top2Lines){
        print join("\t", @$i) ,"\n";
}

foreach my $i (0 .. $#nonRed_gs) {
        print join("\t", $nonRed_gs[$i], @{$nonRed_log2ExprMat->[$i]}),"\n";
#       print join("\t", $probesForNonRed_gs[$i], @{$nonRed_log2ExprMat->[$i]}),"\n";
}

