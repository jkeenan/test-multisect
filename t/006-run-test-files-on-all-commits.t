# -*- perl -*-
# t/006-run-test-files-on-all-commits.t
use strict;
use warnings;
use Test::Multisect;
use Test::Multisect::Opts qw( process_options );
use Test::More tests => 11;
use Data::Dumper;
#use Data::Dump qw(pp);

# Before releasing this to cpan I'll have to figure out how to embed a real
# git repository within this repository.

##### run_test_files_on_all_commits() #####

my (%args, $params, $self);
my ($good_gitdir, $good_last_before, $good_last);
my ($target_args, $full_targets);
my ($transitions, $all_outputs, $all_outputs_count);

$good_gitdir = '/home/jkeenan/gitwork/list-compare';
$good_last_before = '2614b2c2f1e4c10fe297acbbea60cf30e457e7af';
$good_last = 'd304a207329e6bd7e62354df4f561d9a7ce1c8c2';
%args = (
    gitdir => $good_gitdir,
    last_before => $good_last_before,
    last => $good_last,
    verbose => 1,
    make_command => 'make -s',
);
$params = process_options(%args);
$self = Test::Multisect->new($params);
ok($self, "new() returned true value");
isa_ok($self, 'Test::Multisect');

$target_args = [
    't/44_func_hashes_mult_unsorted.t',
    't/45_func_hashes_alt_dual_sorted.t',
];
$full_targets = $self->set_targets($target_args);
ok($full_targets, "set_targets() returned true value");
is(ref($full_targets), 'ARRAY', "set_targets() returned array ref");
is_deeply(
    $full_targets,
    [ map { "$self->{gitdir}/$_" } @{$target_args} ],
    "Got expected full paths to target files for testing",
);

{
    # error case: premature run of get_digests_by_file_and_commit()
    local $@;
    eval { $transitions = $self->get_digests_by_file_and_commit(); };
    like($@,
        qr/You must call run_test_files_on_all_commits\(\) before calling get_digests_by_file_and_commit\(\)/,
        "Got expected error message for premature get_digests_by_file_and_commit()"
    );
}

$all_outputs = $self->run_test_files_on_all_commits();
ok($all_outputs, "run_test_files_on_all_commits() returned true value");
is(ref($all_outputs), 'ARRAY', "run_test_files_on_all_commits() returned array ref");
$all_outputs_count = 0;
for my $c (@{$all_outputs}) {
    for my $t (@{$c}) {
        $all_outputs_count++;
    }
}
is(
    $all_outputs_count,
    scalar(@{$self->get_commits_range}) * scalar(@{$target_args}),
    "Got expected number of output files"
);



##### get_digests_by_file_and_commit() #####

$transitions = $self->get_digests_by_file_and_commit();

for my $test (sort keys %$transitions) {
    my $expected_different = 0;
    my $observed_different = 0;
    for my $r (@{$transitions->{$test}}) {
        $observed_different++ if $r->{compare} eq 'different';
    }
    cmp_ok($observed_different, '==', $expected_different,
        "As expected, for $test got $expected_different 'different' for 'compare'");
}
