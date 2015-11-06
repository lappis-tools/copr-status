use strict;
use warnings;
use Test::More;

BEGIN { use_ok('CoprStatus') }

my $info = CoprStatus::copr_info();
ok(ref($info), 'HASH');
foreach my $key (keys %{$info}) {
  ok(ref($info->{$key}), 'HASH');
  ok($info->{$key}->{'git_version'});
  ok($info->{$key}->{'v4_version'});
  ok($info->{$key}->{'v5_version'});
  like($info->{$key}->{'v4_version'}, qr/[[:ascii:]]+-[[:ascii:]]+/);
  like($info->{$key}->{'v5_version'}, qr/[[:ascii:]]+-[[:ascii:]]+/);
  like($info->{$key}->{'git_version'}, qr/[[:ascii:]]+-[[:ascii:]]+/);
}

my $match = CoprStatus::compare_versions;
ok(ref($match), 'HASH');
foreach my $key (keys %{$match}) {
  like($match->{$key}, qr/1|0/);
}

# TODO: test info2html() and build_html()

done_testing();
