use ExtUtils::MakeMaker;

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
WriteMakefile
  (
   NAME		=> 'DTA::CAB',
   AUTHOR       => 'Bryan Jurish <moocow@bbaw.de>',
   ABSTRACT	=> '"Cascaded Analysis Broker" for robust morphological analysis',
   VERSION_FROM	=> 'CAB.pm',

   PREREQ_PM    => {
		    'Gfsm'    =>0.0216,
		    'Gfsm::XL'=>0.02,
		    ##--
		    'Encode'=>undef,
		    'Tie::Cache'=>undef,
		    'File::Basename'=>undef,
		    'Getopt::Long'=>undef,
		    'Pod::Usage'=>undef,
		    'Storable'=>undef,
		    'Time::HiRes'=>undef,
		   },

   #EXE_FILES   => [qw(dta-cab.perl),],
  );


##-----------------------------------------------------------------------
## Extensions
##-----------------------------------------------------------------------

sub MY::postamble {
  # how to format the README file
  "README.txt : README.POD\n"
  ."\tpod2text README.POD README.txt\n\n";
}

sub MY::dist_core {
  package MY;
  my $inherited = shift->SUPER::dist_core(@_);
  $inherited =~
    # ... distribution requires current README file
    s/^dist\s*:/dist\ : README.txt/m;
  $inherited;
}
