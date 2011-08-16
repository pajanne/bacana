=head1 NAME

Pathogens::Annotate::AlienHunter

=head1 SYNOPSIS

=cut

package Pathogens::Annotate::AlienHunter;
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
        'name'     => 'run_alienhunter',
        'action'   => \&run_alienhunter,
        'requires' => \&run_alienhunter_requires, 
        'provides' => \&run_alienhunter_provides,
    },
);

our $options = 
{
    # Executables
    'alienhunter_exec'     => 'alien_hunter',

    # LSF options
    'bsub_opts'            => '-q long -M2500000 -R"select[mem>2500] rusage[mem=2500]"',
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

    return $self;
}


### ---------------------------------------------------------------------------
### run_alienhunter
### ---------------------------------------------------------------------------
sub run_alienhunter_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta}");
    return \@requires;
}

sub run_alienhunter_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.alienhunter.tab");
    return \@provides;
}

sub run_alienhunter
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_alienhunter.pl") or Utils::error("$path/_alienhunter.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run alienhunter
Utils::CMD("$$self{alienhunter_exec} $$self{fasta} $$self{common_name}.alienhunter.tab -c > _alienhunter_cmd.log", {'verbose'=>1, 'time'=>1});

# if no result file, create one to stop the pipeline running
if ( ! -s "$$self{common_name}.alienhunter.tab" ) { 
    Utils::CMD("touch $$self{common_name}.alienhunter.tab");
}

# tidy-up
unlink("$$self{common_name}.alienhunter.tab.sco");
unlink("$$self{common_name}.alienhunter.tab.plot");
unlink("$$self{common_name}.alienhunter.tab.opt");
unlink("$$self{common_name}.alienhunter.tab.opt.plot");

];
    close($fh);
    LSF::run($lock_file, $path, "_alienhunter_bsub", {bsub_opts=>$$self{bsub_opts}}, qq[perl -w _alienhunter.pl]);

    return $$self{'No'};
}

1;

