=head1 NAME

Pathogens::Annotate::RepeatScout

=head1 SYNOPSIS

=cut

package Pathogens::Annotate::RepeatScout;
use base qw(VertRes::Pipeline);

use strict;
use warnings;
use VRTrack::VRTrack;
use Utils;
use LSF;
use VertRes::Utils::FileSystem;

our @actions =
(
    {
        'name'     => 'run_repeatscout',
        'action'   => \&run_repeatscout,
        'requires' => \&run_repeatscout_requires, 
        'provides' => \&run_repeatscout_provides,
    },
);

our $options = 
{
    # Executables
    'lmertable_exec'       => 'build_lmer_table',
    'repeatscout_exec'     => 'RepeatScout',
    'repeatmasker_exec'    => 'RepeatMasker',
    'filter1_exec'         => 'filter-stage-1.prl',
    'filter2_exec'         => 'filter-stage-2.prl',
    'repeat2tab_exec'      => 'repeat2tab.py',

    # LSF options
    'bsub_opts'            => '-q normal -M2500000 -R"select[mem>2500] rusage[mem=2500]"',

};


### ---------------------------------------------------------------------------
### new
### ---------------------------------------------------------------------------
sub new 
{
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(%$options,'actions'=>\@actions,@args);
    
    # check required options are provided
    $self->throw("Missing fasta option in config.\n") unless $self->{fasta};
    $self->throw("Missing common_name option in config.\n") unless $self->{common_name};

    # set sequence
    $self->{sequence} = 'sequence.fna';

    return $self;
}



### ---------------------------------------------------------------------------
### run_repeatscout
### ---------------------------------------------------------------------------
sub run_repeatscout_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta}");
    return \@requires;
}

sub run_repeatscout_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.repeatscout.tab");
    return \@provides;
}

sub run_repeatscout
{
    my ($self, $path, $lock_file) = @_;

    # create symlink to fasta file
    Utils::relative_symlink($$self{fasta}, $path . '/' . $$self{sequence}); 

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_repeatscout.pl") or Utils::error("$path/_repeatscout.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# step1 - run build_lmer_table
# creates a file that tabulates the frequency of all l-mers in the sequence to be analyzed [option -l to be set?]
Utils::CMD("$$self{lmertable_exec} -sequence $$self{sequence} -freq $$self{common_name}.repeatscout.lmer", {'verbose'=>1, 'time'=>1});

# step2 - run RepeatScout
# takes this table and the sequence and produces a fasta file that contains all the repetitive elements that it could find.
Utils::CMD("$$self{repeatscout_exec} -sequence $$self{sequence} -output $$self{common_name}.repeatscout -freq $$self{common_name}.repeatscout.lmer", {'verbose'=>1, 'time'=>1});

# step3 - run filter-stage-1.prl script
# on the output of RepeatScout to remove low-complexity and tandem elements
Utils::CMD("cat $$self{common_name}.repeatscout | $$self{filter1_exec} > $$self{common_name}.repeatscout.prl1", {'verbose'=>1, 'time'=>1});

# Only run the following steps if prl1 file not empty
if (! -z "$$self{common_name}.repeatscout.prl1") {
    # step4 - run RepeatMasker
    Utils::CMD("$$self{repeatmasker_exec} -lib $$self{common_name}.repeatscout.prl1 $$self{sequence}", {'verbose'=>1, 'time'=>1});

    # step5 - run filter-stage-2.prl script
    # filters out any repeat element that does not appear a certain number of times (by default, 10)
    Utils::CMD("cat $$self{common_name}.repeatscout.prl1 | $$self{filter2_exec} --cat=$$self{sequence}.out --thresh=20 > $$self{common_name}.repeatscout.prl2", {'verbose'=>1, 'time'=>1});

    # Tidy-up
    unlink("$$self{sequence}.cat");
    unlink("$$self{sequence}.out");
    unlink("$$self{sequence}.masked");
    unlink("$$self{sequence}.tbl");

    # step6 - run RepeatMasker
    Utils::CMD("$$self{repeatmasker_exec} -lib $$self{common_name}.repeatscout.prl2 $$self{sequence}", {'verbose'=>1, 'time'=>1});
}

# if no result file, create one
if ( ! -s "$$self{sequence}.out" ) { 
     Utils::CMD("touch $$self{sequence}.out");
}

# Convert to EMBL feature table
Utils::CMD("$$self{repeat2tab_exec} -i $$self{sequence}.out -o $$self{common_name}.repeatscout.tab", {'verbose'=>1, 'time'=>1});

# Tidy-up
unlink("$$self{common_name}.repeatscout.lmer");
unlink("$$self{common_name}.repeatscout");
unlink("$$self{common_name}.repeatscout.prl1");
unlink("$$self{common_name}.repeatscout.prl2");
unlink("$$self{sequence}.cat");
unlink("$$self{sequence}.ori.out");
unlink("$$self{sequence}.out");
unlink("$$self{sequence}.log");
unlink("$$self{sequence}.masked");
unlink("$$self{sequence}.tbl");

];
    close($fh);
    LSF::run($lock_file, $path, "_$$self{common_name}_repeatscout", {bsub_opts=>$$self{bsub_opts}}, "perl -w _repeatscout.pl");

    return $$self{'No'};
}


1;

