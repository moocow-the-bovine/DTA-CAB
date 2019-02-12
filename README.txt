    README for DTA::CAB

ABSTRACT
    DTA::CAB - "Cascaded Analysis Broker" for error-tolerant linguistic
    analysis

REQUIREMENTS
    Gfsm
        Both C library and perl wrappers required. See
        <http://kaskade.dwds.de/~jurish/projects/gfsm>

    Gfsm::XL
        Both C library and perl wrappers required. See
        <http://kaskade.dwds.de/~jurish/projects/gfsm#gfsmxl>

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

REFERENCES
    The author would appreciate CAB users citing its use in any related
    publications. As a general CAB-related reference, please cite:

    Jurish, Bryan. *Finite-state Canonicalization Techniques for Historical
    German.* PhD thesis, Universität Potsdam, 2012 (defended 2011). URN
    urn:nbn:de:kobv:517-opus-55789, [epub
    <http://opus.kobv.de/ubp/volltexte/2012/5578/>, PDF
    <http://kaskade.dwds.de/~jurish/pubs/jurish2012diss.pdf>, BibTeX
    <http://kaskade.dwds.de/~jurish/pubs/jurish2012diss.bib>]

SEE ALSO
    Gfsm(3perl)
        URL: <http://kaskade.dwds.de/~jurish/projects/gfsm>

    Gfsm::XL(3perl)
        URL: <http://kaskade.dwds.de/~jurish/projects/gfsm#gfsmxl>

AUTHOR
    Bryan Jurish <moocow@cpan.org>

