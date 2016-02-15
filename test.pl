use strict;
use warnings;
use RPM::VersionCompare;

my $greater = "1.3.6+spb-1";
my $lesser = "1.3.6-1";

print "$greater is greater than $lesser\n" if RPM::VersionCompare::labelCompare($greater, $lesser) == 1;
print "$greater is the same as $lesser\n" if RPM::VersionCompare::labelCompare($greater, $lesser) == 0;
print "$greater is lesser than $lesser\n" if RPM::VersionCompare::labelCompare($greater, $lesser) == -1;
