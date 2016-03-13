package CoprStatus;
use strict;
use warnings;
use JSON;
use YAML::XS 'LoadFile';
use Text::Template;
use LWP::UserAgent;
use LWP::Simple;
use Copr::Api;

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

# hash with repos data
our $info = {};
my $config = LoadFile('config.yaml');

sub git_url {
  my ( $domain, $spec_path, $branch, $package ) = @_;

  $spec_path =~ s/<branch>/$branch/;
  $spec_path =~ s/<package>/$package/g;

  return "$domain/$spec_path";
}

sub download_specs {
  my ( $branch, $user, $repo ) = @_;
  my $ua = LWP::UserAgent->new;
  $ua->timeout(300);
  $ua->env_proxy;
  $ua->ssl_opts(SSL_verify_mode => 0x00);
  my %latest_packages = Copr::Api::get_latest_packages($user, $repo);
  foreach my $package (keys %latest_packages) {
    my $git_url = git_url($config->{GitDomain},
                          $config->{GitSpecPath},
                          $branch, $package);
    `mkdir -p data/git/$branch`;
    my $spec_filename = "data/git/$branch/$package.spec";
    $ua->mirror( $git_url, $spec_filename );
  }
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
    $info->{$package}->{'git'}->{$branch} = $version;
  }
}

sub get_copr_versions {
  my ( $user, $repo ) = @_;
  my %latest_packages = Copr::Api::get_latest_packages($user, $repo);
  foreach my $package (keys %latest_packages) {
    my $version = $latest_packages{$package}{version};
    my $submitter = $latest_packages{$package}{submitter};
    $info->{$package}->{'copr'}->{$repo}->{version} = $version;
    $info->{$package}->{'copr'}->{$repo}->{submitter} = $submitter;
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
    if($info->{$package}->{'copr'}->{${$config->{Repositories}}[1]}->{version} eq $info->{$package}->{'git'}->{${$config->{Branches}}[1]}) {
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
    my $fill_stable_row;
    my $fill_dev_row;
    if($info->{$package}->{'copr'}->{${$config->{Repositories}}[0]}->{version} eq $info->{$package}->{'git'}->{${$config->{Branches}}[0]}) {
      $fill_stable_row = "success";
    }
    else {
      $fill_stable_row = "danger";
    }

    if($info->{$package}->{'copr'}->{${$config->{Repositories}}[1]}->{version} eq $info->{$package}->{'git'}->{${$config->{Branches}}[1]}) {
      $fill_dev_row = "success";
    }
    else {
      $fill_dev_row = "danger";
    }

    $table_entries .= "<tr>
    <td><b>$package</b></td>
    <td>$info->{$package}->{'git'}->{${$config->{Branches}}[0]}</td>
    <td class=\"$fill_stable_row\" data-toggle=\"tooltip\" data-placement=\"top\" title=\"Submitter: $info->{$package}->{'copr'}->{${$config->{Repositories}}[0]}->{submitter}\">$info->{$package}->{'copr'}->{${$config->{Repositories}}[0]}->{version}</td>
    <td>$info->{$package}->{'git'}->{${$config->{Branches}}[1]}</td>
    <td class=\"$fill_dev_row\" data-toggle=\"tooltip\" data-placement=\"top\" title=\"Submitter: $info->{$package}->{'copr'}->{${$config->{Repositories}}[1]}->{submitter}\">$info->{$package}->{'copr'}->{${$config->{Repositories}}[1]}->{version}</td>
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
    table_entries => info2html(),
    branch0 => ${$config->{Branches}}[0],
    branch1 => ${$config->{Branches}}[1],
    repo0 => ${$config->{Repositories}}[0],
    repo1 => ${$config->{Repositories}}[1]
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

1;
