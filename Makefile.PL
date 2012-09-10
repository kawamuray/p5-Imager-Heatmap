use 5.008000;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Imager::Heatmap',
    VERSION_FROM  => 'lib/Imager/Heatmap.pm',
    INSTALLDIRS   => 'site',
    ABSTRACT_FROM => 'lib/Imager/Heatmap.pm',
    AUTHOR        => 'Yuto Kawamura <kawamuray.dadada@gmail.com>',
    LIBS          => '-lm',
    LICENSE       => 'perl',
    PREREQ_PM     => {
        'Imager'       => '0.90',
        'Imager::Test' => '0.90',
        'Test::More'   => '0.00',
        'FindBin'      => '0.00',
    },
);
