use strict;
use warnings;
use Test::More;
use Imager::Test qw/ is_image /;
use File::Spec;
use File::Basename;

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

    return sub {
        defined(my $line = <$fh>) or return;
        chomp $line;
        return split /\s/, $line;
    };
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
    $hmap->draw( get_data_src 'sample.tsv' );
    $hmap->img->write( file => File::Spec->catfile($resources_dir, 'sample.png') );
} else {

    subtest "Basic image generation" => sub {
        $hmap->draw( get_data_src 'sample.tsv' );
        is_image $hmap->img, read_img('sample.png'), "Result image comparison";
    };

    $hmap->img(Imager->new(xsize => $hmap->xsize, ysize => $hmap->ysize, channels => 4));

    subtest "Image generation with limited data fetch" => sub {
        $hmap->max_data_at_time(10);
        $hmap->draw( get_data_src 'sample.tsv' );
        is_image $hmap->img, read_img('sample.png'), "Result image comparison";
    };

    done_testing;
}
