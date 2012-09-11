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

    my $hmap = Imager::Heatmap->new(
        xsize            => $opts{width},
        ysize            => $opts{height},
        xsigma           => 10,
        ysigma           => 10,
    );

    my $file = shift;
    my @insert_datas;
    open my $fh, '<', $file or die "Can't open file $file: $!";
    while (my $line = <$fh>) {
        chomp $line;
        push @insert_datas, [ split /\s/, $line ];
    }
    close $fh;

    my $hratio = $opts{width} / $opts{'src-width'};
    my $vratio = $opts{height} / $opts{'src-height'};

    $hmap->add_data(@insert_datas);

    $hmap->draw;
    $hmap->img->write(file => $opts{output});

    close $fh;
}
