
use Cwd;

my $curdir = cwd();
foreach(split('/', "usr/local/src/distro/test")) {
	mkdir $_;
	if(-d $_) {
		chdir $_, next;
	} else {
		die "Couldn't create directory $_: $!";
	}
}
chdir $curdir;
		
	
		
