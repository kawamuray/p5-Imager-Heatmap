use strict;
use warnings;
use Test::More;
use Test::Warn;
use Imager::Test qw/ is_image /;
use Imager;
use File::Spec;
use File::Basename;

use t::Util;
use Imager::Heatmap;

my $resources_dir = File::Spec->catdir(File::Basename::dirname(__FILE__), 'resources');

sub read_img {
    my $img_file = shift;

    return Imager->new( file => File::Spec->catfile($resources_dir, $img_file) );
}

sub get_data_src {
    my $src_file = shift;

    my $path = File::Spec->catfile($resources_dir, $src_file);
    open my $fh, '<', $path or die "Can't open file $path: $!";

    my @insert_datas;
    while (my $line = <$fh>) {
        chomp $line;
        push @insert_datas, [ split /\s/, $line ];
    }

    return @insert_datas;
}

my $hmap = Imager::Heatmap->new(
    xsize  => 1000,
    ysize  => 1000,
    xsigma => 20.0,
    ysigma => 20.0,
);

# Run following to re-generate test images.
# perl t/02_image.t generate
if (@ARGV && shift @ARGV eq 'generate') {
    $hmap->insert_datas( get_data_src 'sample.tsv' );
    my $img = $hmap->draw;
    $img->write( file => File::Spec->catfile($resources_dir, 'sample.png') );
} else {

    subtest "Basic image generation" => sub {
        $hmap->insert_datas( get_data_src 'sample.tsv' );
        my $img = $hmap->draw;
        $img->write(file => '/tmp/test.png');
        is_image $img, read_img('sample.png'), "Result image comparison";
    };

    subtest "No data image generation" => sub {
        my $hmap = hmap;

        my $img;
        warning_like sub {
            $img = $hmap->draw;
        }, qr/Nothing to be rendered/, "Nothing to be rendered if no data specified";

        is_image $img, Imager->new(
            xsize    => $hmap->xsize, 
            ysize    => $hmap->ysize,
            channels => 4,
        ), "Returned image should be a blank image";
    };

    done_testing;
}
