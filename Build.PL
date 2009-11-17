use Module::Build;
Module::Build->new(
    module_name => 'File::HashCache::JavaScript',
    license     => 'perl',
    dist_author => 'David Caldwell <david@porkrind.org>',
    requires    => {
        File::Slurp => 0,
        JSON => 0,
        JavaScript::Minifier::XS => 0,
    },
)->create_build_script;
