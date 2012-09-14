package t::Util;
use strict;
use warnings;

use parent 'Exporter';
our @EXPORT = qw/ hmap /;

use Imager::Heatmap;

sub hmap {
    return Imager::Heatmap->new( xsize => 300, ysize => 300 );
}

1;
