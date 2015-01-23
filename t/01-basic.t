use v6;

use Test;
use eigmip6;

my $a = Note.new(:name(Notes::A), :freq(440e0));

is ($a + 1).perl, Note.new(:name(Notes::As), :freq(466.16e0)).perl, 'infix:<+> works';

my $scale = Scale.new(:root($a), :steps([2,2,1,2,2,2,1]));
is $scale.succ-note($a).perl, ($a + 2).perl, 'scale and succ-note seems to work';

is $scale.tritone($a).perl, ($a.perl, ($a + 4).perl, ($a + 7).perl), 'trione from a scale works';

done;
