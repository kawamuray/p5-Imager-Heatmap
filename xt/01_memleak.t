use strict;
use warnings;
use Test::More;
use Test::LeakTrace;

use t::Util;

my @insert_datas = ([ 10, 10 ], [ 20, 20 ], [ 30, 30 ]);

no_leaks_ok {
    hmap->insert_datas(@insert_datas);
};

done_testing;
