# Copyright (C) 2009 David Caldwell and Jim Radford, All Rights Reserved. -*- cperl -*-
package File::HashCache; use warnings; use strict;

use List::Util qw(max);
use Digest::MD5 qw(md5_hex);
use File::Basename;
use File::Slurp qw(read_file write_file);
use JSON qw(to_json from_json);

sub max_timestamp(@) { max map { (stat $_)[9] || 0 } @_ } # Obviously 9 is mtime

sub pound_include($;$);
sub pound_include($;$) {
    my ($text, $referrer) = @_;
    my ($line, @deps) = (0);
    return (join('', map { $line++;
                         $_ .= "\n";
                         if (/^#include\s+"([^"]+)"/) {
                             my $included = read_file(my $name=$1) or die "include '$1' not found".($referrer?" at $referrer\n":"\n");
                             ($_, my @new_deps) = pound_include($included, $name);
                             push @deps, $name, @new_deps;
                         }
                         $_;
                     } split(/\n/, $text)),
            @deps);
}

sub hash {
    my ($config, $name) = @_;

    my $script;
    if (   !($script = $config->{cache}->{$name})
        || ! -f $script->{path}
        || max_timestamp(@{$script->{deps}}) > $script->{timestamp}) {

        my ($base, $dir, $ext) = fileparse $name, qr/\.[^.]+/;
        $ext =~ s/^\.//;
        my $single_blob = read_file($name);

        my ($processed, @deps) = ($single_blob, $name);
        for my $process (@{$config->{"process_$ext"}}) {
            ($processed, my @new_deps) = $process->($processed);
            push @deps, @new_deps;
        }

        my $hash = md5_hex($processed);
        $config->{cache}->{$name} = $script = { deps => \@deps,
                                                name => "$base-$hash.$ext",
                                                path => "$config->{cache_dir}/$base-$hash.$ext",
                                                hash => $hash,
                                                timestamp => max_timestamp(@deps) };
        if (! -f $script->{path}) {
          mkdir $config->{cache_dir};
          write_file($script->{path},       { atomic => 1 }, $processed) or die "couldn't cache $script->{path}";
          write_file($config->{cache_file}, { atomic => 1 }, to_json($config->{cache}, {pretty => 1})) or warn "Couldn't save cache control file";
        }
    }
    $script->{name};
}

sub new {
    my $class = shift;
    my $config = bless { cache_dir => '.hashcache',
                         @_,
                       }, $class;
    $config->{cache_file} ||= "$config->{cache_dir}/cache.json";
    $config->{cache} = from_json( read_file($config->{cache_file}) ) if -f $config->{cache_file};
    my $cache_file_version = 1;
    # On mismatched versions, just clear out the cache:
    $config->{cache} = { VERSION => $cache_file_version } unless $config->{cache} && ($config->{cache}->{VERSION} || 0) == $cache_file_version;
    $config;
}

1;

