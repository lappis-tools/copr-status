use strict;
use warnings;
use Test::More;

BEGIN { use_ok('CoprStatus'); }
BEGIN { use_ok('Copr::Api'); }

CoprStatus::update_info();

my $info = $CoprStatus::info;

ok(ref($info), 'HASH');
foreach my $key (keys %{$info}) {
  ok(ref($info->{$key}), 'HASH');
  ok($info->{$key}->{'git'}->{'master'});
  ok($info->{$key}->{'copr'}->{'v4'}->{version});
  ok($info->{$key}->{'copr'}->{'v5'}->{version});
  like($info->{$key}->{'copr'}->{'v4'}->{version}, qr/[[:ascii:]]+-[[:ascii:]]+/);
  like($info->{$key}->{'copr'}->{'v5'}->{version}, qr/[[:ascii:]]+-[[:ascii:]]+/);
  like($info->{$key}->{'git'}->{'master'}, qr/[[:ascii:]]+-[[:ascii:]]+/);
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


done_testing();
