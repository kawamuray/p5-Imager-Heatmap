use strict;
use warnings;
use Test::More;
use Test::Exception;

use Imager::Heatmap;

my $hmap = Imager::Heatmap->new( xsize => 300, ysize => 300 );

subtest "Behavior of new" => sub {
    dies_ok sub { Imager::Heatmap->new( xsize => 100 ) }, "Die if ysize not specified";
    dies_ok sub { Imager::Heatmap->new( ysize => 100 ) }, "Die if xsize not specified";

    local %Imager::Heatmap::DEFAULTS = (
        xsigma           => 10.0,
        ysigma           => 5.0,
        correlation      => 1.0,
    );

    my $hmap;
    lives_ok sub { $hmap = Imager::Heatmap->new( xsize => 100, ysize => 100 ) };

    is $hmap->xsize, 100;
    is $hmap->ysize, 100;
    is $hmap->xsigma, 10.0;
    is $hmap->ysigma, 5.0;
    is $hmap->correlation, 1.0;

    throws_ok sub {
        Imager::Heatmap->new( xsize => 100, ysize => 100, foobar => 1 )
    }, qr/unkown options.*foobar/, "Die if unkowon options ware specified";
};

subtest "Behavior of xsize and ysize" => sub {
    dies_ok sub { $hmap->xsize(-1) }, "Negative number is not allowed for xsize";

    lives_ok sub { $hmap->xsize(100) }, "xsize should be a positive number";
    is $hmap->xsize, 100, "Accessor xsize worked";

    dies_ok sub { $hmap->ysize(-1) }, "Negative number is not allowed for ysize";

    lives_ok sub { $hmap->ysize(100) }, "ysize should be a positive number";
    is $hmap->ysize, 100, "Accessor ysize worked";
};

subtest "Behavior of xsigma and ysigma" => sub {
    dies_ok sub { $hmap->xsigma(-1.0) }, "Negative number is not allowed for xsigma";

    lives_ok sub { $hmap->xsigma(1.0) }, "xsigma should be a positive number";
    is $hmap->xsigma, 1.0, "Accessor xsigma worked";

    dies_ok sub { $hmap->ysigma(-1.0) }, "Negative number is not allowed for ysigma";

    lives_ok sub { $hmap->ysigma(1.0) }, "ysigma should be a positive number";
    is $hmap->ysigma, 1.0, "Accessor ysigma worked";
};

subtest "Behavior of correlation" => sub {
    dies_ok sub { $hmap->correlation(-1.1) }, "Number less    than -1 is not allowed for correlation";
    dies_ok sub { $hmap->correlation( 1.1) }, "Number greater than  1 is not allowed for correlation";

    lives_ok sub { $hmap->correlation(-1) }, "correlation can be -1";
    lives_ok sub { $hmap->correlation( 1) }, "correlation can be  1";
    lives_ok sub { $hmap->correlation(0.0) }, "correlation can be 0.0";

    is $hmap->correlation, 0.0, "Accessor ysigma worked";
};

done_testing;
