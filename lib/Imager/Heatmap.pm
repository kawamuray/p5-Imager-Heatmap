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

Imager::Heatmap - Perl extension for drawing Heatmap using Imager

=head1 SYNOPSIS

    use Imager::Heatmap;
    my $hmap = Imager::Heatmap->new(
        xsize  => 640,        # Image width
        ysize  => 480,        # Image height
        xsigma => 10,         # X-dimentional sigma value
        ysigma => 10,         # Y-dimentional sigma value
    );

    # Drawing heatmap
    $hmap->draw(\@point_datas); # @point_datas should be: ( [ x1, y1, weight1 ], [ x2, y2, weight2 ] ... )

    or 

    # Example to draw heatmap by data from file
    open my $fh, '<', /path/to/data/file or die "Can't open file $file: $!";

    # Closure should return a data(x, y, weight(optional)) for each call
    $hmap->draw(sub {
        defined(my $line = <$fh>) or return; # Return undef to notify end of data
        chomp $line;
        my ($x, $y, $weight) = split /\s/, $line;
        return ($x, $y, $weight);
    });

    close $fh;

    # After drawing finished, you can use img method to access Imager instance

    $hmap->img->write( file => '/path/to/outfile' ); # Write to file
    $img->rubthrough( src => $hmap->img );           # Overlay on other images

    # And you can access probability density matrix using matrix method if you like...
    $hmap->matrix;

=head1 DESCRIPTION

Imager::Heatmap is a module to draw heatmap using Imager.

This module calculates probability density matrix from input data and
map a color for each pixels to represent density of input data.

=head1 METHODS

=head2 new()

Create new instance of Imager::Heatmap.
You can specify some options as follows.
See the accessors section for more details about each parameters.

    $hmap = Imager::Heatmap->new( xsize => 300, ysize => 300 );
    $hmap = Imager::Heatmap->new( img => $imager_instance );

=head3 Options

=over

=item o img         (required if you don't specify xsize and ysize)

A blessed object of Imager to render heatmap.
Image's xsize and ysize will automatically set to Imager::Heatmap instance.

Option xsize and ysize will ignored if you specify this option.

=item o xsize       (required if you don't specify img)

X-dimentional size of heatmap image.
 
=item o ysize       (required if you don't specify img)

Y-dimentional size of heatmap image.

=item o xsigma      (optional, default: 1.0)

X-dimentional sigma value.

=item o ysigma      (optional, default: 1.0)

Y-dimentional sigma value.

=item o correlation (optional, default: 0.0)

Correlation between X and Y.

=item o max_data_at_time (optional, default: undef)

Max number of data that could process at a time.

=back

=head2 xsize()

Set/Get the X-dimentional size of heatmap image.

    $hmap->xsize(100);
    $xsize = $hmap->xsize;

=head2 ysize()

Set/Get the Y-dimentional size of heatmap image.

    $hmap->ysize(100);
    $ysize = $hmap->ysize;

=head2 xsigma()
    
Set/Get the X-dimentional sigma value.
This value represents X-dimentional standard deviation.
This value should be positive number.

    $hmap->xsigma(10.0);
    $xsigma = $hmap->xsigma;

=head2 ysigma()
    
Set/Get the Y-dimentional sigma value.
This value represents Y-dimentional standard deviation.
This value should be positive number.

    $hmap->ysigma(10.0);
    $ysigma = $hmap->ysigma;

=head2 correlation()
    
Set/Get the correlation coefficient.
This value represents correlation between X and Y.
This value should be the number between -1 and 1. (includeing -1 and 1)

    $hmap->correlation(0.5);
    $correlation = $hmap->correlation;

=head2 max_data_at_time()

Set/Get the Max number of data that could process at a time.
This value is used when you specify closure as data source to draw method.
Imager::Heatmap doesn't fetch data further than this value,
but continue to fetch remaining datas after processed existing datas.

    $hmap->max_data_at_time(50000);
    $max_data_at_time = $hmap->max_data_at_time;

If you don't need to specify limit for fetching data, set undef(or 0) to let it unlimited.

=head2 matrix()

Get the processed probability density matrix.
If you call this before any data has been processed, you will just get the undef.

    $matrix = $hmap->matrix;

Return value is flat array. You can access the value of pixel(x,y) as follows:

    $pixel_value = $matrix->[$y * $hmap->xsize + $x];

=head2 img()

Set/Get a Imager instance the target to draw a heatmap.
The argument must be a blessed object of Imager and it should be a 4-channels image.

    $img = $hmap->img;
    $hmap->img(Imager->new( xsize    => $xsize,
                            ysize    => $ysize,
                            channels => 4 ));

=head2 generate_matrix()

Calculates probability density matrix of input datas.
This method will internally called by draw() method.

    $matrix = $img->generate_matrix($data_source);

You can find the equation used to calculate 2-dimentional probability density matrix
can be found at following location:

    http://en.wikipedia.org/wiki/Multivariate_normal_distribution#Bivariate_case

=head2 draw()

Draw a heatmap from the passed data source.
This method may be take a while if the datas are large.

    $img->draw($data_source);

The argument data_source should be a arrayref or a coderef.

If it is a arrayref, each element of array should contain
x([0]), y([1]), and optionally weight([2]) as follows:
    
$data_source = [ [ x1, y1, weight1 ], [ x2, y2, weight2 ] ... ];

Else if it is a code ref, it should return 2 or 3 elements as following for each call:

$data_source = sub { (x, y) };

or

$data_source = sub { (x, y, weight) };

It should return undef to notify end of data.

Commonly, the default value of weight is 1.

X, Y and weight will implicitly cast to integer in XS,
so it doesn't make any sense specifying real numbers to these parameters.

=head1 SEE ALSO

Imager(3)
    
The equation used to calculate 2-dimentional probability density matrix: 
    Multivariate normal distribution - Wikipedia, the free encyclopedia
        http://en.wikipedia.org/wiki/Multivariate_normal_distribution#Bivariate_case

=head1 AUTHOR

Yuto KAWAMURA(kawamuray), E<lt>kawamuray.dadada@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Yuto KAWAMURA(kawamuray)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
