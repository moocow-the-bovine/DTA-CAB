    README for DTA::CAB

ABSTRACT
    DTA::CAB - "Cascaded Analysis Broker" for error-tolerant linguistic
    analysis

REQUIREMENTS
    Gfsm
        Both C library and perl wrappers required. See
        http://www.ling.uni-potsdam.de/~moocow/projects/gfsm

    Gfsm::XL
        Both C library and perl wrappers required. See
        http://www.ling.uni-potsdam.de/~moocow/projects/gfsm#gfsmxl

    Encode
    Storable
    Tie::Cache
    Getopt::Long
    Pod::Usage
    Time::HiRes
    (a bunch of Gfsm transducers)

DESCRIPTION
    The DTA::CAB package provides an object-oriented compiler/interpreter
    for error-tolerant heuristic morphological analysis of tokenized text.

INSTALLATION
    Issue the following commands to the shell:

     bash$ cd DTA-CAB-0.01   # (or wherever you unpacked this distribution)
     bash$ perl Makefile.PL  # check requirements, etc.
     bash$ make              # build the module
     bash$ make test         # (optional): test module before installing
     bash$ make install      # install the module on your system

SEE ALSO
    Gfsm(3perl)
        URL: http://www.ling.uni-potsdam.de/~moocow/projects/gfsm

    Gfsm::XL(3perl)
        URL: http://www.ling.uni-potsdam.de/~moocow/projects/gfsm#gfsmxl

AUTHOR
    Bryan Jurish <jurish@bbaw.de>

