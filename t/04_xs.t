use strict;
use warnings;
use Test::More;
use Test::Exception;

use t::Util;

subtest "Invalid datas" => sub {
    my $hmap = hmap;

  SKIP: {
      skip "Currently Imager::Heatmap does not die when undef passed(just finish processing";
      throws_ok sub {
          $hmap->insert_datas(undef);
      }, qr/array reference/, "Die if insert_datas contain undef";
    }

    throws_ok sub {
        $hmap->insert_datas('foobar');
    }, qr/array reference/, "Die if insert_datas non-ref value";

    throws_ok sub {
        $hmap->insert_datas({ hoo => 'bar' });
    }, qr/array reference/, "Die if insert_datas non-ARRAYref value";

    throws_ok sub {
        $hmap->insert_datas([1]);
    }, qr/array reference/, "Die if point data length is less than 2";
};

done_testing;
