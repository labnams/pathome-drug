use strict ;

use lib '/pwork01/seokjong/home_backup_darthvader/lib/perl5/site_perl' ; # '/home/seokjong/lib/perl5/site_perl' ;

use MMIA::Preprocessing ;
use MMIA::Util ;
use Getopt::Long ;

print getnum('10.1' ) ,"\n";


sub getnum {
    use POSIX qw(strtod);
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    $! = 0;
    my($num, $unparsed) = strtod($str);
    if (($str eq '') || ($unparsed != 0) || $!) {
        return;
    } else {
        return $num;
    } 
} 

sub is_numeric { defined scalar &getnum } 
