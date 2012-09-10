package Imager::Heatmap;
use 5.008000;
use strict;
use warnings;
use utf8;
use XSLoader;
use Carp;
use Imager;
use List::Util qw/ max /;

our $VERSION = '0.01';
our $DEBUG = 0;
our %DEFAULTS = (
    xsigma           => 1,
    ysigma           => 1,
    correlation      => 0.0,
    max_data_at_time => undef,
);

XSLoader::load __PACKAGE__, $VERSION;

sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    if ($args{img}) {
        $self->img(delete $args{img});
        # Remove xsize and ysize (to not trigger croak for "Unkown options")
        delete $args{xsize} && delete $args{ysize};
    } else {
        unless (exists $args{xsize} && exists $args{ysize}) {
            croak "You need to specify xsize and ysize";
        }
        $self->xsize(delete $args{xsize});
        $self->ysize(delete $args{ysize});
        $self->img(Imager->new(
            xsize    => $self->xsize,
            ysize    => $self->ysize,
            channels => 4,
        ));
    }

    $self->xsigma          ((exists $args{xsigma})           ? delete $args{xsigma}           : $DEFAULTS{xsigma});
    $self->ysigma          ((exists $args{ysigma})           ? delete $args{ysigma}           : $DEFAULTS{ysigma});
    $self->correlation     ((exists $args{correlation})      ? delete $args{correlation}      : $DEFAULTS{correlation});
    $self->max_data_at_time((exists $args{max_data_at_time}) ? delete $args{max_data_at_time} : $DEFAULTS{max_data_at_time});

    if (keys %args) {
        croak "You did specify some unkown options: " . join ',', keys %args;
    }

    return $self;
}

sub xsize {
    my $self = shift;

    if (@_) {
        if ($_[0] < 0) { croak "xsize must be a positive number" }
        $self->{xsize} = $_[0];
    }
    return $self->{xsize};
}

sub ysize {
    my $self = shift;

    if (@_) {
        if ($_[0] < 0) { croak "ysize must be a positive number" }
        $self->{ysize} = $_[0];
    }
    return $self->{ysize};
}

sub xsigma {
    my $self = shift;

    if (@_) {
        if ($_[0] < 0.0) { croak "xsigma should be a positive number" }
        $self->{xsigma} = $_[0];
    }
    return $self->{xsigma}
}

sub ysigma {
    my $self = shift;

    if (@_) {
        if ($_[0] < 0.0) { croak "ysigma should be a positive number" }
        $self->{ysigma} = $_[0];
    }
    return $self->{ysigma}
}

sub correlation {
    my $self = shift;

    if (@_) {
        if ($_[0] < -1 || $_[0] > 1) {
            croak "correlation should be a number between -1 and 1";
        }
        $self->{correlation} = $_[0];
    }
    return $self->{correlation}
}

sub max_data_at_time {
    my $self = shift;

    if (@_) {
        if (defined $_[0] && $_[0] < 0) {
            croak "max_data_at_time must be a positive number or undef(or 0, unlimited)";
        }
        $self->{max_data_at_time} = $_[0];
    }
    return $self->{max_data_at_time};
}

sub matrix { (shift)->{matrix} }

sub img {
    my $self = shift;

    if (@_) {
        if (!$_[0]->isa('Imager'))   { croak "img must be a blessed object of Imager(3)" }
        if ($_[0]->getchannels != 4) { croak "img should be a 4-channels image" }

        $self->{img} = $_[0];

        # Need to update xsize and ysize when img updated
        $self->xsize($_[0]->getwidth);
        $self->ysize($_[0]->getheight);
    }
    return $self->{img};
}

sub generate_matrix {
    my ($self, $data_src) = @_;

    if (ref $data_src eq 'ARRAY') {
        my @data_src_copy = @{ $data_src };
        $data_src = sub {
            my $point = shift @data_src_copy or return;
            return @{ $point };
        };
    } elsif (ref $data_src ne 'CODE') {
        croak "dara_src must be a ARRAY ref or a CODE ref";
    }

    # To avoid "Use of uninitialized..." warnings
    my $max_data_at_time = $self->max_data_at_time // 0;

    $self->{matrix} = xs_generate_matrix(
        $self->xsize, $self->ysize,
        $self->xsigma, $self->ysigma, $self->correlation,
        $data_src, $max_data_at_time,
    );
}

sub draw {
    my ($self, $data_src) = @_;

    my $matrix  = $self->generate_matrix($data_src);
    my ($w, $h) = ($self->xsize, $self->ysize);
    my $img     = $self->img;
    my $max     = max(@{ $matrix });

    unless ($max) {
        carp "Nothing to be rendered";
        return;
    }

    my %color_cache;
    for (my $y = 0; $y < $h; $y++) {
        my @linedata = map {
            my $div = $_/$max;
            my $hue   = int((1-$div)*240);
            my $alpha = int(sqrt($div)*255);

            $color_cache{"$hue $alpha"} ||= Imager::Color->new(
                hue        => $hue,
                saturation => 1.0,
                value      => 1.0,
                alpha      => $alpha,
            );
        } @$matrix[$y*$w..$y*$w+$w-1];

        $img->setscanline('y' => $y, pixels => \@linedata);
    }
}

1;
__END__

=head1 NAME

Imager::Heatmap - Perl extension for drawing Heatmap using Imager(3)

=head1 SYNOPSIS

    use Imager::Heatmap;
    my $hmap = Imager::Heatmap->new({
        xsize       => 640,    # image xsize
        ysize      => 480,    # image ysize
        xsigma       => 10,     # X-dimentional sigma value
        ysigma       => 10,     # Y-dimentional sigma value
        max_data_at_time       => 10000,  # max number of points which keeps in memory at same time
    });

    open my $fh, '<', /path/to/data/file or die "Can't open file $file: $!";

    $hmap->fetch_method(sub {
        defined(my $line = <$fh>) or return;   # return undef if EOF appeared
        chomp $line;
        my @f = split /\s/, $line;

        return ($f[0]*10, $f[1]*10);
    });

    $hmap->process; # start fetching and calculating normal distribution

    $hmap->img->write(file => '/path/to/outfile'); # you can access Imager instance using img method


=head1 DESCRIPTION

Imager::Heatmap draws HEATMAP using Imager(3).
This module generates normal distribution matrix from input data.
Then convert the matrix to color information and draw it to image.
You can specified (X|Y)-dimentional sigma value and probability variable.
# write about accessing matrix
# write abound parallel processing

=head1 METHODS

=head1 SEE ALSO

Imager
    
=head1 AUTHOR

Yuto Kawamura, E<lt>rivervillage.braveperson@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Yuto Kawamura

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
