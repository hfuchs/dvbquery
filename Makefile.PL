use ExtUtils::MakeMaker;

WriteMakefile(
    # 2011-03-27, TODO Suppress creation of that blasted Makefile.old?
    #MAKEFILE_OLD  => '',
    #clean         => { FILES => "Makefile.old" }, # Run *before*.
    realclean     => { FILES => "Makefile Makefile.old tags" },  # HA!
    NAME          => 'dvbquery',
    ABSTRACT      => "Simulate the behaviour of DVB widgets and query
    their servers for public transport schedules.",
    LICENSE       => 'perl',
    AUTHOR        => 'Hagen Fuchs <hagen.fuchs@physik.tu-dresden.de>',
    #VERSION_FROM  => eval { my$v=`git describe`;
    #    `echo "*VERSION = $v" > version-file`; return "version-file" },
    #VERSION_FROM  => 'version-file',
    VERSION  => `git describe`,
    EXE_FILES     => [ 'bin/dvb' ],
);

sub MY::postamble {
    return << 'EOC';
tags:
	ctags -R .
EOC
}

