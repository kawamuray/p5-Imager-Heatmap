use strict;
use warnings;
use Test::More;
use Imager::Test qw/ is_image /;
use File::Spec;
use File::Basename;

use Imager::Heatmap;

my $hmap = Imager::Heatmap->new(
    xsize  => 1000,
    ysize  => 1000,
    xsigma => 20.0,
    ysigma => 20.0,
);

my $path = File::Spec->catfile(File::Basename::dirname(__FILE__), 'resources', 'sample.tsv');
open my $fh, '<', $path or die "Can't open file $path: $!";

my @array;
while (my $line = <$fh>) {
    chomp $line;
    push @array, [ split /\s/, $line ];
}

my $fetch_method = sub {
    defined(my $line = <$fh>) or return;
    chomp $line;
    return split /\s/, $line
};

my $matrix_arrsrc = $hmap->generate_matrix(\@array);

seek $fh, 0, 0;
my $matrix_fetchsrc = $hmap->generate_matrix($fetch_method);

seek $fh, 0, 0;
$hmap->max_data_at_time(20);
my $matrix_fetchsrc_limited = $hmap->generate_matrix($fetch_method);

is_deeply $matrix_arrsrc, $matrix_fetchsrc, "Two matrix generated by array source and fetch method must be same";
is_deeply $matrix_fetchsrc, $matrix_fetchsrc_limited, "Two matrix generated by fetch method and fetch method(limited) must be same";

done_testing;