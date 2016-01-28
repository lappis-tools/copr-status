package CoprStatus;
use strict;
use warnings;
use JSON;
use YAML::XS 'LoadFile';
use Text::Template;
use LWP::UserAgent;
use LWP::Simple;

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

# hash with repos data
our $info = {};
my $config = LoadFile('config.yaml');

sub copr_monitor_url {
  my ( $user, $repo ) = @_;
  return "http://copr.fedoraproject.org/api/coprs/$user/$repo/monitor/";
}

sub git_url {
  my ( $domain, $spec_path, $branch, $package ) = @_;

  $spec_path =~ s/<branch>/$branch/;
  $spec_path =~ s/<package>/$package/g;

  return "$domain/$spec_path";
}

sub download_specs {
  my ( $branch, $user, $repo ) = @_;
  return unless -e "data/copr/$user/$repo/monitor.json";
  my $ua = LWP::UserAgent->new;
  $ua->timeout(300);
  $ua->env_proxy;
  $ua->ssl_opts(SSL_verify_mode => 0x00);
  open(my $fh, "<", "data/copr/$user/$repo/monitor.json") or die;
  my $result = do { local $/; <$fh> };
  close($fh);
  my $json = JSON->new->allow_nonref;
  my $dec_result = $json->decode($result);
  foreach(@{$dec_result->{'packages'}}) {
    my $package = $_->{'pkg_name'};
    my $git_url = git_url('http://softwarepublico.gov.br',
                          'gitlab/softwarepublico/softwarepublico/raw/<branch>/src/pkg-rpm/<package>/<package>.spec',
                          $branch, $package);
    `mkdir -p data/git/$branch`;
    my $spec_filename = 'data/git/'.$branch.'/'.$package.'.spec';
    $ua->mirror( $git_url, $spec_filename );
  }
}

sub download_copr_versions {
  my ( $user, $repo ) = @_;
    `mkdir -p data/copr/$user/$repo`;
  my $result = mirror(copr_monitor_url($user, $repo), "data/copr/$user/$repo/monitor.json");
}

sub get_specs {
  my ( $branch ) = @_;
  foreach my $package (keys %{$info}) {
    next unless -e "data/git/$branch/$package.spec";
    open(my $fh, "<", "data/git/$branch/$package.spec") or die;
    my $spec = do { local $/; <$fh> };
    close($fh);
    my $version = $1 if $spec =~ /^Version:\s*([^\s]+)\s*$/m;
    if($version =~ /%\{version\}/) {
      $version = $1 if $spec =~ /define version\s*([^\s]+)\s*$/m;
    }

    my $release = 'no_release';
    $release = $1 if $spec =~ /^Release:\s*([^\s]+)\s*$/m;
    $version = "$version-$release";
    $info->{$package}->{'git_version_'.$branch} = $version;
  }
}

sub get_copr_versions {
  my ( $user, $repo ) = @_;
  return unless -e "data/copr/$user/$repo/monitor.json";
  open(my $fh, "<", "data/copr/$user/$repo/monitor.json") or die;
  my $result = do { local $/; <$fh> };
  close($fh);
  my $json = JSON->new->allow_nonref;
  my $dec_result = $json->decode($result);
  foreach(@{$dec_result->{'packages'}}) {
    my $package = $_->{'pkg_name'};
    my $status = $_->{'results'}{'epel-7-x86_64'}{'status'};
    my $version = $_->{'results'}{'epel-7-x86_64'}{'pkg_version'};
    $info->{$package}->{$repo."_version"} = $version if $status eq "succeeded";
  }
}

sub update_info {
  my $user = $config->{User};
  foreach my $repo (@{$config->{Repositories}}) {
    get_copr_versions($user, $repo);
  }

  foreach my $branch (@{$config->{Branches}}) {
    get_specs($branch);
  }
}

sub update_files {
  while(1) {
    my $user = $config->{User};
    foreach my $repo (@{$config->{Repositories}}) {
      download_copr_versions($user, $repo);
    }

    my $repo_index = 0;
    foreach my $branch (@{$config->{Branches}}) {
      download_specs($branch, $user, ${$config->{Repositories}}[$repo_index]);
      $repo_index += 1;
    }

    sleep $config->{UpdateRate};
  }
}

sub compare_versions {
  update_info();
  my $match = {};
  foreach my $package (keys %{$info}) {
    if($info->{$package}->{'v5_version'} eq $info->{$package}->{git_version_master}) {
      $match->{$package} = 1;
    }
    else {
      $match->{$package} = 0;
    }
  }

  return $match;
}

sub info2html {
  update_info();
  my $table_entries="";
  foreach my $package (keys %{$info}) {
    my $fill_v4_row;
    my $fill_v5_row;
    if($info->{$package}->{'v4_version'} eq $info->{$package}->{'git_version_stable-4.2'}) {
      $fill_v4_row = "success";
    }
    else {
      $fill_v4_row = "danger";
    }

    if($info->{$package}->{'v5_version'} eq $info->{$package}->{git_version_master}) {
      $fill_v5_row = "success";
    }
    else {
      $fill_v5_row = "danger";
    }

    $table_entries .= "<tr>
    <td><b>$package</b></td>
    <td>$info->{$package}->{'git_version_stable-4.2'}</td>
    <td class=\"$fill_v4_row\">$info->{$package}->{'v4_version'}</td>
    <td>$info->{$package}->{'git_version_master'}</td>
    <td class=\"$fill_v5_row\">$info->{$package}->{'v5_version'}</td>
    </tr>";
  }

  return $table_entries;
}

sub build_html {
  my ( $data, $template ) = @_;
  return $template->fill_in(HASH => $data);
}

our %ROUTING = (
    '/'      => \&serve_html,
    '/api'  => \&serve_json,
    '/api/status'  => \&serve_json_status
    );

sub serve_html {
  my $data = {
    title => "SPB Copr Status",
    table_entries => info2html()
  };

  my $template = Text::Template->new(
    TYPE => 'FILE',
    SOURCE => 'template.html.tt'
  );

  return [
    '200',
    [ 'Content-Type' => 'text/html'],
    [ build_html($data, $template) ],
  ];
};

sub serve_json {
  update_info();
  my $json = JSON->new->allow_nonref;
  my $json_info = $json->encode($info);
  return [
    '200',
    [ 'Content-Type' => 'application/json'],
    [ $json_info ],
  ];
};

sub serve_json_status {
  my $info = compare_versions();
  my $json = JSON->new->allow_nonref;
  my $json_info = $json->encode($info);
  return [
    '200',
    [ 'Content-Type' => 'application/json'],
    [ $json_info ],
  ];
};

my $child_pid = fork();
if($child_pid) {
  update_files();
}

1;
