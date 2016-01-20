use strict;
use warnings;
use Test::More;

BEGIN { use_ok('CoprStatus'); }

CoprStatus::copr_info('softwarepublico', 'v4', 'stable-4.1');
CoprStatus::copr_info('softwarepublico', 'v5', 'master');

my $info = $CoprStatus::info;

ok(ref($info), 'HASH');
foreach my $key (keys %{$info}) {
  ok(ref($info->{$key}), 'HASH');
  ok($info->{$key}->{'git_version_master'});
  ok($info->{$key}->{'v4_version'});
  ok($info->{$key}->{'v5_version'});
  like($info->{$key}->{'v4_version'}, qr/[[:ascii:]]+-[[:ascii:]]+/);
  like($info->{$key}->{'v5_version'}, qr/[[:ascii:]]+-[[:ascii:]]+/);
  like($info->{$key}->{'git_version_master'}, qr/[[:ascii:]]+-[[:ascii:]]+/);
}

my $match = CoprStatus::compare_versions;
ok(ref($match), 'HASH');
foreach my $key (keys %{$match}) {
  like($match->{$key}, qr/1|0/);
}

my $table = CoprStatus::info2html();
like($table, qr/danger|success/m);

my $data = {
  title => "SPB Copr Status",
  table_entries => $table
};

my $template = Text::Template->new(
  TYPE => 'FILE',
  SOURCE => 'template.html.tt'
);

my $html = CoprStatus::build_html($data, $template);
like($html, qr/SPB Copr Status/m);

my $monitor_url = CoprStatus::copr_monitor_url("foo", "bar");
my $test_url =  "http://copr.fedoraproject.org/api/coprs/foo/bar/monitor/";
is($monitor_url, $test_url);

done_testing();
