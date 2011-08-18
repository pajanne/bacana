=head1 NAME

Pathogens::Annotate::Glimmer

=head1 SYNOPSIS


=cut

package Pathogens::Annotate::Glimmer;
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
        'name'     => 'run_glimmer3',
        'action'   => \&run_glimmer3,
        'requires' => \&run_glimmer3_requires, 
        'provides' => \&run_glimmer3_provides,
    },
);

our $options = 
{
    # Executables
    'glimmer3_exec'        => 'g3-iterated.csh',
    'glimmer2tab_exec'     => 'glimmer2tab.py',

    # LSF options
    'bsub_opts'            => '-q normal',
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
### run_glimmer3
### ---------------------------------------------------------------------------
sub run_glimmer3_requires
{
    my ($self) = @_;
    my @requires;
    push(@requires, "$$self{fasta}");
    return \@requires;
}

sub run_glimmer3_provides
{
    my ($self) = @_;
    my @provides;
    push(@provides, "$$self{common_name}.g3.tab");
    return \@provides;
}

sub run_glimmer3
{
    my ($self, $path, $lock_file) = @_;

    # dynamic script to be run by LSF
    open(my $fh,'>', "$path/_glimmer3.pl") or Utils::error("$path/_glimmer3.pl: $!");
    print $fh
qq[
use strict;
use warnings;
use Utils;

# run glimmer3
Utils::CMD("$$self{glimmer3_exec} $$self{fasta} $$self{common_name} >& _glimmer3_cmd.log", {'verbose'=>1, 'time'=>1});

# if no result file, create one 
if ( ! -s "$$self{common_name}.predict" ) { 
    Utils::CMD("touch $$self{common_name}.predict");
}

# Tidy-up
unlink("$$self{common_name}.longorfs");
unlink("$$self{common_name}.train");
unlink("$$self{common_name}.icm");
unlink("$$self{common_name}.run1.detail");
unlink("$$self{common_name}.run1.predict");
unlink("$$self{common_name}.coords");
unlink("$$self{common_name}.upstream");
unlink("$$self{common_name}.motif");
unlink("$$self{common_name}.detail");

# Convert glimmer3 results into EMBL feature table
Utils::CMD("$$self{glimmer2tab_exec} -i $$self{common_name}.predict -o $$self{common_name}.g3.tab", {'verbose'=>1, 'time'=>1});

# Tidy-up
unlink("$$self{common_name}.predict");

];
    close($fh);
    LSF::run($lock_file, $path, "_glimmer3_bsub", {bsub_opts=>$$self{bsub_opts}}, qq[perl -w _glimmer3.pl]);

    return $$self{'No'};
}

1;

