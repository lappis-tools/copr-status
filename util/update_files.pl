use CoprStatus;
use YAML::XS 'LoadFile';

my $config = LoadFile('config.yaml');

sub update_files {
  while(1) {
    my $user = $config->{User};
    my $repo_index = 0;
    foreach my $branch (@{$config->{Branches}}) {
      CoprStatus::download_specs($branch, $user, ${$config->{Repositories}}[$repo_index]);
      $repo_index += 1;
    }

    sleep $config->{UpdateRate};
  }
}

update_files();

