#!/usr/bin/perl
#% require "config.pimpx"
#% ifdef WITH_PERL
#%   print #!%WITH_PERL %WITH_PERLFLAGS
#% endif

use Cwd;
use vars qw($basename);


sub error($);
sub warning($);

#% ifdef WITH_CONFIGFILE
#% print my $CONFIGFILE = '%{WITH_CONFIGFILE}';
#%   else
my $CONFIGFILE = './conf';
#% endif

# ### hashref getconfig(void)
# Description:
#   Parse our configurationfile and return a hashref to it. I.e:
#     database {
#       pagedb db/page.db;
#     }
#   becomes:
#     $config->{database}{pagedb};
#
# Depends on global variables:
#  $CONFIGFILE  The configuration file to use.
#
sub getconfig {
    my %config;
    open(CF, "<$CONFIGFILE") or return undef;
    my @dir_names = qw(general excludeAtParse database);

    my $config; { # slurp our file into $config
        local $/ = undef; # $/ = $INPUT_RECORD_SEPARATOR
        $config = <CF>;
    }

    # remove comments
    $config =~ s/#.+?\n//g;

    # parse each directive in @dir_names
    foreach my $dir_name (@dir_names) {
        $config =~  /   $dir_name\s*{
                            \s*(.+?)\s*
                        }\s*
                    /sx
        ;
        my $block = $1;
        next unless $block;

        $block =~ s/\\;/!{QUOTED_SEMI}/g;
        foreach(split /;/, $block) {
            s/^\s+//; s/\s+$//; # remove leading and trailing whitespace
            s/!{QUOTED_SEMI}/;/g;
            my($key, $value) = split(/\s+/, $_, 2);
            $config{$dir_name}{$key} = $value;
        }
    }
    return \%config;
}

# ### void mkdir_recursive(string path)
# Get a directory path, split it up by forward slash
# and create each directory.
#
sub mkdir_recursive {
	my($destdir) = @_;
	my $curdir = cwd();
	foreach(split('/', $destdir)) {
	    last unless $_;
	    mkdir $_;
	    if(-d $_) {
	        chdir $_, next;
	    } else {
	        error "Couldn't create directory $_: $!";
	    }
	}
	chdir $curdir;
}

# ### void error(string error);
# Description:
#   Print error message to STDERR and exit program.
#
# Depends on global variable:
#   $basename   Basename of programname.
#
sub error($) {
    my($error) = @_;
    printf(STDERR "%s: Error: %s\n", $basename, $error);
    exit 1;
}

# ### int warning(string warning);
# Description:
#   Print warning message to STDERR
#
# Depends on global variable:
#   $basename   Basename of programname.
#
sub warning($) {
    my($warning) = @_;
    printf(STDERR "%s: Warning: %s\n", $basename, $warning);
    return 1;
}



1;
__END__
