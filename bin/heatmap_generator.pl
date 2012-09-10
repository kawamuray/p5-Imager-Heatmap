#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Imager::Heatmap;

my %delimiter = (
    csv => ',',
    tsv => qr/\s/,
);

my %opts = (
    format => 'csv',
    output => './heatmap.png',
);

# Options:
#   required: --src-width, --src-height, --width, --height
#   optional: --format, --output

GetOptions(
    (map { +"$_=i" => \$opts{$_} } qw(src-width src-height width height)),
    (map { +"$_=s" => \$opts{$_} } qw(format output)),
);

# main
{
    for my $opt (qw(src-width src-height width height)) {
        die "Option $opt is required." unless defined $opts{$opt};
    }

    my $hmap = Imager::Heatmap->new({
        width       => $opts{width},
        height      => $opts{height},
        sig_x       => 10,
        sig_y       => 10,
        limit       => 10000,
    });

    my $file = shift;
    open my $fh, '<', $file or die "Can't open file $file: $!";

    my $hratio = $opts{width} / $opts{'src-width'};
    my $vratio = $opts{height} / $opts{'src-height'};
    $hmap->fetcher(sub {
        defined(my $line = <$fh>) or return;
        chomp $line;
        my @f = split $delimiter{$opts{format}}, $line;
        $f[2] = 1 if @f == 2;

        return ($f[0]*$hratio, $f[1]*$vratio);
    });

    $hmap->process;
    $hmap->img->write(file => $opts{output});

    close $fh;
}
