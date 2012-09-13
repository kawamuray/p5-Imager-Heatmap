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

    done_testing;
}
