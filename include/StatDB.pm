#!/usr/bin/perl
#% include "config.pimpx"
#% ifdef WITH_PERL
#%   print #!%WITH_PERL %WITH_PERLFLAGS
#%  endif
# <------------------------------ - -  - -    -     -       -          -
# Module: StatDB.pm
#
# Description:
#   Gives a object oriented interface to stat.pl's DBM files.
#
# Files:
#   DBM files given as arguments to new.
#
# Depends on:
#   BerkeleyDB.pm, Berkeley DB (http://www.sleepycat.com)
#
# Author: Ask Solem Hoel <ask@startsiden.no>
#
################################################################

require 5.6.0;

package StatDB;
use strict;
use BerkeleyDB;
use Exporter;

our $verbose = 0;
our(@ISA, @EXPORT, @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT = qw(sprint_timeref cmp_timestampref b_to_kB b_to_MB b_to_GB);

our %valid_exprs 
	= map {$_ => 1} qw(-Day -Month -Year -Hour -Page -IP -Status);

# #### CONSTRUCTOR ########################### #

sub new {
    my %argv = @_;
    my $self = {};
    bless $self, "StatDB";

    foreach(($argv{timedb}, $argv{ipdb}, $argv{pagedb}, $argv{statusdb}))
    {
        unless(defined $_) {
            die "StatDB->new: Internal error: Missing required arguments.\n";
        }
    }

    $self->set_time_db($argv{timedb});
    $self->set_ip_db($argv{ipdb});
    $self->set_page_db($argv{pagedb});
    $self->set_status_db($argv{statusdb});
    
    return $self;
}

# #### ACCESSORS ############################ #

# vars
sub fetch_time_db       {$_[0]->{TIME_DB}};
sub fetch_status_db     {$_[0]->{STATUS_DB}};
sub fetch_page_db       {$_[0]->{PAGE_DB}};
sub fetch_ip_db         {$_[0]->{IP_DB}};
sub set_time_db         {$_[0]->{TIME_DB}   = $_[1]};
sub set_ip_db           {$_[0]->{IP_DB}     = $_[1]};
sub set_page_db         {$_[0]->{PAGE_DB}   = $_[1]};
sub set_status_db       {$_[0]->{STATUS_DB} = $_[1]};

# databases (tied hash refs)
sub tbyid {
    my($self, $tbyid) = @_;
    $self->{TBYID} = $tbyid if $tbyid;
    return $self->{TBYID};
}
sub tbytime {
    my($self, $tbytime) = @_;
    $self->{TBYTIME} = $tbytime if $tbytime;
    return $self->{TBYTIME};
}
sub ibyid {
    my($self, $ibyid) = @_;
    $self->{IBYID} = $ibyid if $ibyid;
    return $self->{IBYID};
}
sub sbyid {
    my($self, $sbyid) = @_;
    $self->{SBYID} = $sbyid if $sbyid;
    return $self->{SBYID};
}

sub pbyid {
    my($self, $pbyid) = @_;
    $self->{PBYID} = $pbyid if $pbyid;
    return $self->{PBYID};
}

sub error {
    my($self, $error) = @_;
    $self->{ERROR} = $error if defined $error;
    return $self->{ERROR};
}

# #### METHODS ############################# #

# ### int startsession(StatDB statdb)
# Open all databases and tie them to this object.
# Always run StatDB::endsession when finished.
#
sub startsession($)
{
    my($self) = @_;

    my $timedb      = $self->fetch_time_db;
    my $ipdb        = $self->fetch_ip_db;
    my $pagedb      = $self->fetch_page_db;
    my $statusdb    = $self->fetch_status_db;

    foreach my $ref (($timedb, $ipdb, $pagedb, $statusdb)) {
        unless(defined $ref) {
            $self->error("StatDB->startsession: Missing database file. Please reconfigure script");
            return undef;
        }
    }

    # ###########################
    # Here we open the different filedatabases which should work
    # as one big database
    my $env = new BerkeleyDB::Env();
    $self->tbyid(   create_session($timedb, 	"byid", 	$env));
    $self->tbytime( create_session($timedb, 	"bytime", 	$env));
    $self->ibyid(   create_session($ipdb,		"byid", 	$env));
    $self->pbyid(   create_session($pagedb, 	"byid", 	$env));
    $self->sbyid(   create_session($statusdb, 	"byid", 	$env));

    return 1;
}

# ### int endsession(StatDB statdb)
# Close all open databases.
#
sub endsession($)
{
    my($self) = @_;
    foreach my $ref 
        ((  $self->tbyid(), 
            $self->tbytime(),
            $self->ibyid(),
            $self->pbyid(),
            $self->sbyid())
    ) {
        if(tied %$ref) {
            untie %$ref;
        }
    }
    return 1;
}
    

# ### tied create_session(StatDB statdb, string dbfile, string dbname)
# Open a database and return reference to the tied hash.
# If new databases are added, it's important to add these to StatDB::endsession()
#
sub create_session($$$)
{ 
    my($file, $db, $env) = @_;
    tie my %db, "BerkeleyDB::Hash",
        -Filename   => $file,
        -Subname    => $db,
        -Env        => $env,
        -Flags      => DB_CREATE,
    || die "Couldn't open file $file: $! $BerkeleyDB::Error\n";
    return \%db;
}

# ### int tdb_next_id(StatDB statdb)
# Find next availible id in the timestamp database.
#
sub tdb_next_id($)
{
    my($self) = @_;
    my $tbyid = $self->tbyid();
    my $next_id = 1; # starts at 1, not 0
    while($tbyid->{$next_id}) {
        $next_id++;
    }
    return $next_id;
}

# ### int insert_new_timestamp(StatDB statdb, string timestamp)
# Insert a new timestamp entry. Returns a new/existing id.
#
sub insert_new_timestamp($$)
{
    my($self, $timestamp) = @_;
    my $tbyid = $self->tbyid();
    my $tbytime = $self->tbytime();

    if($tbytime->{$timestamp}) {
        return $tbytime->{$timestamp};
    }

    my $id = $self->tdb_next_id();

    # save both values
    $tbyid->{$id} = $timestamp;
    $tbytime->{$timestamp} = $id;
    return $id;
}

# ### int insert_ip(StatDB statdb, string host/ip, string time, string server)
# Insert a new ip entry.
#
sub insert_ip($$$$)
{
    my($self, $ip, $time, $server) = @_;
    my $ibyid = $self->ibyid();

    my $new_id = join(":", $ip, $time, $server);
    if(exists $ibyid->{$new_id}) {
            $ibyid->{$new_id}++;
    } else {
        $ibyid->{$new_id} = 1;
    }
    return 1;
}

# ### int insert_page(StatDB statdb, string page, string time, string server, int bytes)
# Insert a new page entry.
#
sub insert_page($$$$$)
{
    my($self, $page, $time, $server, $bytes) = @_;
    my $pbyid = $self->pbyid();

    my $new_id = join(":", $page, $time, $server);
    if(exists $pbyid->{$new_id}) {
			my($icount, $ibytes) = split(/:/, $pbyid->{$new_id}, 2);
			$icount++;
			$ibytes += $bytes;
			$pbyid->{$new_id} = join(':', $icount, $ibytes);
    } else {
        $pbyid->{$new_id} = "1:$bytes";
    }
    return 1;
}

# ### int insert_status(StatDB statdb, int status, string time, string server)
# Insert a new status entry.
#
sub insert_status($$$$)
{
    my($self, $status, $time, $server) = @_;
    my $sbyid = $self->sbyid();

    my $new_id = join(":", $status, $time, $server);
    if(exists $sbyid->{$new_id}) {
            $sbyid->{$new_id}++;
    } else {
        $sbyid->{$new_id} = 1;
    }
    return 1;
}

# ### string last_db_update(StatDB statdb)
# Get the date and time from the last changed database file.
#
sub last_db_update($)
{
    my($self) = @_;
    my $timedb      = $self->fetch_time_db;
    my $ipdb        = $self->fetch_ip_db;
    my $pagedb      = $self->fetch_page_db;
    my $statusdb    = $self->fetch_status_db;
    foreach(reverse sort {(stat($a))[10] <=> (stat($b))[10]} ($timedb, $ipdb, $pagedb, $statusdb)) {
        return scalar localtime( (stat($_))[10] );
    }   
}

# ### int get_all_hits(StatDB statdb)
# return total hits on all pages in the pages database.
#
sub get_all_hits($)
{
	my($self) = @_;
	my $pbyid = $self->pbyid();

	my $hits = 0;
	foreach(values %$pbyid) {
		$hits += $_;
	}
	return $hits;
}

# ### void test_limit_expr(hashref expr)
# Check for invalid limit expressions, print a warning if any.
#
sub test_limit_expr($)
{
	my($expr) = @_;
	foreach(keys %$expr) {
		unless($StatDB::valid_exprs{$_}) {
			warn("Internal warning: Invalid limit expression: $_\n");
		}
	}
}

sub fetch_times
{
	my($self, %expr) = @_;
	my $tbyid = $self->tbyid();
	my $tbytime = $self->tbytime();
	test_limit_expr(\%expr);
	my @times;
	foreach my $timestamp (sort {$a <=> $b || $a cmp $b} values %$tbyid) {
		my @time = get_arr_of_dates($timestamp);
		next unless cmp_timestampref(\@time, %expr);
		push(@time, $tbytime->{$timestamp});
		push(@times, \@time);
	}
	return \@times;
}

sub fetch_sizes
{
	my($self, %expr) = @_;
	my $pbyid = $self->pbyid();
	my $tbyid = $self->tbyid();
	test_limit_expr(\%expr);
	my $total_size = 0;
	while(my($key, $value) = each(%$pbyid)) {
		my($page, $time, $server) = split(':', $key);
		my($count, $size) = split(':', $value);
		if(defined %expr) {
			my @time = get_arr_of_dates($tbyid->{$time});
			next unless cmp_timestampref(\@time, %expr);
		}		
		$total_size += $size;
	}
	return $total_size;
}

sub fetch_all
{
	my($self, %expr) = @_;
	my $pbyid = $self->pbyid();
	my $tbyid = $self->tbyid();
	my $tbytime = $self->tbytime();
	my $ibyid = $self->ibyid();
	my $sbyid = $self->sbyid();

	test_limit_expr(\%expr);

	my $total_hits 	= 0;
	my $total_size 	= 0;
	my $total_404 	= 0;
	my $total_200	= 0;
	my $total_ip 	= 0;
	my @per_hour;
	my %seen_ip;
		
	# ### iterate through the pages db:	
	PAGE: while(my($key, $value) = each(%$pbyid)) {
		my($page, $time, $server) = split(':', $key);
		my($count, $size) = split(':', $value);
		my @time = get_arr_of_dates($tbyid->{$time});
		if(defined %expr) {
			next PAGE unless cmp_timestampref(\@time, %expr);
		}
		$total_hits += $count;
		$total_size += $size;
		$per_hour[sprintf("%.1d", $time[3])] += $count;
	}

	# ### Iterate through the IP address db:
	IP: while(my($key, $count) = each(%$ibyid)) {
		my($ip, $time, $server) = split(':', $key);
		if(defined %expr) {
			my @time = get_arr_of_dates($tbyid->{$time});
			next IP unless cmp_timestampref(\@time, %expr);
		}
		$seen_ip{$ip} += $count;
	}
	$total_ip = scalar keys %seen_ip;

	# ### Iterate through the HTTP status code db:
	STATUS: while(my($key, $count) = each(%$sbyid)) {
		my($status, $time, $server) = split(':', $key);
		if(defined %expr) {
			my @time = get_arr_of_dates($tbyid->{$time});
			next STATUS unless cmp_timestampref(\@time, %expr);
		}
		if($status == 404) {
			$total_404 += $count;
		}
		elsif($status == 200) {
			$total_200 += $count;
		}
	}
	return {
		total_hits 	=> $total_hits,
		total_size 	=> $total_size,
		total_ips 	=> $total_ip,
		total_200	=> $total_200,
		total_404	=> $total_404,
		per_hour	=> \@per_hour,
	}
}
		
sub strcmplimit {
	my($haystack, $limit) = @_;
	return 1 unless defined $limit;
	if($limit =~ s/^=//) {
		return undef unless $haystack eq $limit;
	}
	elsif($limit =~ s/^~//) {
		return undef unless $haystack =~ $limit;
	}
	elsif($limit =~ s/^>//) {
		return undef unless index($haystack, $limit) == -1;
	}
	return 1;
}

sub cmp_timestampref
{
	my($timeref, %expr) = @_;
	if(defined %expr) {
		if(defined $expr{'-Day'}) {
			if($expr{'-Day'} =~ s/^>//) {
				return undef unless $timeref->[2] >= $expr{'-Day'};
			}
			elsif($expr{'-Day'} =~ s/^<//) {
				return undef unless $timeref->[2] <= $expr{'-Day'};
			}
			else {
				return undef unless $timeref->[2] == $expr{'-Day'};
			}
		}
		if(defined $expr{'-Month'}) {
			if($expr{'-Month'} =~ s/^>//) {
				return undef unless $timeref->[1] >= $expr{'-Month'};
			}
			elsif($expr{'-Month'} =~ s/^<//) {
				return undef unless $timeref->[1] <= $expr{'-Month'};
			}
			else {
				return undef unless $timeref->[1] == $expr{'-Month'};
			}
		}
		if(defined $expr{'-Year'}) {
			if($expr{'-Year'} =~ s/^>//) {
				return undef unless $timeref->[0] >= $expr{'-Year'};
			}
			elsif($expr{'-Year'} =~ s/^<//) {
				return undef unless $timeref->[0] <= $expr{'-Year'};
			}
			else {
				return undef unless $timeref->[0] == $expr{'-Year'};
			}
		}
		if(defined $expr{'-Hour'}) {
			if($expr{'-Hour'} =~ s/^>//) {
				return undef unless $timeref->[3] >= $expr{'-Hour'};
			}
			elsif($expr{'-Hour'} =~ s/^<//) {
				return undef unless $timeref->[3] <= $expr{'-Hour'};
			}
			else {
				return undef unless $timeref->[3] == $expr{'-Hour'};
			}
		}
	}
	return 1;
}

# ### string sprint_time(arrayref timeref)
# Return a formatted timestamp string. i.e:
#   my $timeref = get_arr_of_dates($timestamp);
#	print sprint_time($timeref), "\n";
#
sub sprint_time($)
{
	my($timeref) = @_;
	my $final_str = sprintf("%.4d-%.2d-%.2d %.2d:00:00",
			$timeref->[0],
			$timeref->[1],
			$timeref->[2],
			$timeref->[3],
		);
	return $final_str;
}

# ### arrayref get_arr_of_dates(string timestamp)
# Extract the elements from a timestamp and return a reference to an array
# with these elements.
#
sub get_arr_of_dates($)
{
	my($timestamp) = @_;
	my @fields; {
		$_ = $timestamp;
		@fields = /(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):00:00([\+|\-]\d\d)/;
	}
	return @fields;
}

# ### int get_id_from_timestamp(StatDB statdb, string timestamp)
# Get the timestampdb id for a timestamp (if any)
#
sub get_id_from_timestamp($$)
{
	my($self, $timestamp) = @_;
	my $tbytime = $self->tbytime();
	my $id = $tbytime->{$timestamp};
	return $id if defined $id;
	return undef; # otherwise
}

# ### int b_to_kB(int bytes)
# convert bytes to kilobytes
#
sub b_to_kB($)
{
	my($bytes) = @_;
	return sprintf("%.2f", $bytes / 1024);
}

# ### int b_to_MB(int bytes)
# convert bytes to megabytes
#
sub b_to_MB($)
{
	my($bytes) = @_;
	return sprintf("%.2f", $bytes / 1_048_576);
}

# ### int b_to_GB(int bytes)
# convert bytes to gigabytes.
#
sub b_to_GB($)
{
	my($bytes) = @_;
	return sprintf("%.2f", $bytes / 1_073_741_824);
}

# #### <--<>--> ########################### #
1;
__END__
=head1 NAME

StatDB - Gives a object oriented interface to stat.pl's DBM files.

=head1 SYNOPSIS

    use StatDB;

    my $db = StatDB::new(
        timedb      => 'db/time.db',
        pagedb      => 'db/page.db',
        statusdb    => 'db/status.db',
        ipdb        => 'db/ip.db',
    );

    $db->startsession() or die $db->error(), "\n";
    print $db->idb_next_id(), "\n";
    $db->endsession();

=head1 DESCRIPTION

StatDB.pm gives a object oriented interface to stat.pl's DBM files.

=head1 METHODS

=over 4
    
=item int startsession(StatDB statdb)

Open all databases and tie them to this object.
Always run StatDB::endsession when finished.

=item int endsession(StatDB statdb)
    
Close all open databases.

=item tied create_session(StatDB statdb, string dbfile, string dbname)

Open a database and return reference to the tied hash.
If new databases are added, it's important to add these to StatDB::endsession()

=item int tdb_next_id(StatDB statdb)

Find next availible id in the timestamp database.

=item int insert_new_timestamp(StatDB statdb, string timestamp)

Insert a new timestamp entry. Returns a new/existing id.

=item int insert_ip(StatDB statdb, string host/ip, string time, string server)

Insert a new ip entry.

=item int insert_page(StatDB statdb, string page, string time, string server int bytes)

Insert a new page entry.

=item int insert_status(StatDB statdb, int status, string time, string server)

Insert a new status entry.

=item string last_db_update(StatDB statdb)

Get the date and time from the last changed database file.

=item int b_to_kB(int bytes)

Convert bytes to kilobytes.

=item int b_to_MB(int bytes)

Convert bytes to megabytes.

=item int b_to_GB(int bytes)

Convert bytes to gigabytes.

=item int get_all_hits(StatDB statdb)

Return total hits on all pages in the pages database.

=item void test_limit_expr(hashref expr)

Check for invalid limit expressions, print a warning if any.

=item int get_id_from_timestamp(StatDB statdb, string timestamp)

Get the timestampdb id for a timestamp (if any)

=item string sprint_time(arrayref timeref)

Return a formatted timestamp string. i.e:

	my $timeref = get_arr_of_dates($timestamp);
	print sprint_time($timeref), "\n";

=item arrayref get_arr_of_dates(string timestamp)

Extract the elements from a timestamp and return a reference to an array
with these elements.

=back

=head1 DATABASES

=over 4

=item The timestamp database

The timestamp database has two subdatabases:

byid: 	key=id value=timestamp,
bytime:	key=timestamp value=id

All entries in the other databases has a time field, which is the id of
a timedb entry.	

=item The pages database

The pages database has one entry for each hour, page and server.
A page entry looks like this:

byid: key=page:time:server value=count:size

The count field is how many times this page is seen, on this server and
in this hour. The size is the total traffic (in kB) this page has generated
at $hour and $server.

=item The IP database

The IP database has one entry for each hour, ip and server.
An IP entry looks like this:

byid: key=ip:time:server value=count

=item The Status database

The status database has one entry for each hour, http status code and server.
An Status entry looks like this:

byid: key=http_status_code:time:server value=count

=back

=head1 EXPORT

=over 4

=item sprint_timeref($)

=item cmp_timestampref($$)

=item b_to_kB($)

=item b_to_MB($)

=item b_to_GB($)

=back

=head1 AUTHOR
    
Ask Solem Hoel E<lt>ask@startsiden.no<gt>

=head1 SEE ALSO

L<perl>, L<BerkeleyDB>, L<http://www.startsiden.no>

=cut
