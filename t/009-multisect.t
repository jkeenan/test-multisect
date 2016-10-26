# -*- perl -*-
# t/009-multisect.t
use strict;
use warnings;
use Test::Multisect;
use Test::Multisect::Opts qw( process_options );
use Test::More qw(no_plan); # tests => 37;
use Data::Dump qw(pp);
use List::Util qw( first );
use Cwd;

my $cwd = cwd();

my (%args, $params, $self);
my ($good_gitdir, $good_first, $good_last);
my ($target_args, $full_targets);
my ($rv, $transitions, $all_outputs, $all_outputs_count, $expected_count, $first_element);

# In this test file we'll use a different (newer) range of commits in the
# 'dummyrepo' repository.  In this range there will exist 2 test files for
# targeting.

# So that we have a basis for comparison, we'll first run already tested
# methods over the 'dummyrepo'.

$good_gitdir = "$cwd/t/lib/dummyrepo";
$good_first = 'd2bd2c75a2fd9afd3ac65a808eea2886d0e41d01';
$good_last = '199494ee204dd78ed69490f9e54115b0e83e7d39';
%args = (
    gitdir => $good_gitdir,
    first => $good_first,
    last => $good_last,
    verbose => 0,
    make_command => 'make -s',
);
$params = process_options(%args);
$target_args = [
    't/001_load.t',
    't/002_add.t',
];

note("First object");

$self = Test::Multisect->new($params);
ok($self, "new() returned true value");
isa_ok($self, 'Test::Multisect');

$full_targets = $self->set_targets($target_args);
ok($full_targets, "set_targets() returned true value");
is(ref($full_targets), 'ARRAY', "set_targets() returned array ref");
is_deeply(
    $full_targets,
    [ map { "$self->{gitdir}/$_" } @{$target_args} ],
    "Got expected full paths to target files for testing",
);

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

$rv = $self->get_digests_by_file_and_commit();
ok($rv, "get_digests_by_file_and_commit() returned true value");
is(ref($rv), 'HASH', "get_digests_by_file_and_commit() returned hash ref");
cmp_ok(scalar(keys %{$rv}), '==', scalar(@{$target_args}),
    "Got expected number of elements: one for each of " . scalar(@{$target_args}) . " test files targeted");
$first_element = first { $_ } keys %{$rv};
is(ref($rv->{$first_element}), 'ARRAY', "Records are array references");
is(
    scalar(@{$rv->{$first_element}}),
    scalar(@{$self->get_commits_range}),
    "Got 1 element for each of " . scalar(@{$self->get_commits_range}) . " commits"
);
is(ref($rv->{$first_element}->[0]), 'HASH', "Records are hash references");
for my $k ( qw| commit file md5_hex | ) {
    ok(exists $rv->{$first_element}->[0]->{$k}, "Record has '$k' element");
}

$transitions = $self->examine_transitions();
ok($transitions, "examine_transitions() returned true value");
is(ref($transitions), 'HASH', "examine_transitions() returned hash ref");
cmp_ok(scalar(keys %{$transitions}), '==', scalar(@{$target_args}),
    "Got expected number of elements: one for each of " . scalar(@{$target_args}) . " test files targeted");
$first_element = first { $_ } keys %{$transitions};
is(ref($transitions->{$first_element}), 'ARRAY', "Records are array references");
$expected_count = scalar(@{$self->get_commits_range}) - 1;
is(
    scalar(@{$transitions->{$first_element}}),
    $expected_count,
    "Got 1 element for each of $expected_count transitions between commits"
);
is(ref($transitions->{$first_element}->[0]), 'HASH', "Records are hash references");
for my $k ( qw| older newer compare | ) {
    ok(exists $transitions->{$first_element}->[0]->{$k}, "Record has '$k' element");
}

#say STDERR "AAA: transitions";
#pp($transitions);

#######################################

note("Second object");

my ($self2, $commit_range, $idx, $bisected_outputs, $bisected_outputs_undef_count);

$self2 = Test::Multisect->new($params);
ok($self2, "new() returned true value");
isa_ok($self2, 'Test::Multisect');

$commit_range = $self2->get_commits_range;

$full_targets = $self2->set_targets($target_args);
ok($full_targets, "set_targets() returned true value");
is(ref($full_targets), 'ARRAY', "set_targets() returned array ref");
is_deeply(
    $full_targets,
    [ map { "$self2->{gitdir}/$_" } @{$target_args} ],
    "Got expected full paths to target files for testing",
);

{
    # error case: premature run of identify_first_transition_per_target()
    local $@;
    eval { $rv = $self2->identify_first_transition_per_target(); };
    like($@,
        qr/You must run prepare_multisect\(\) before identify_first_transition_per_target\(\)/,
        "Got expected error message for premature identify_first_transition_per_target()"
    );
}

note("prepare_multisect()");

$bisected_outputs = $self2->prepare_multisect();
ok($bisected_outputs, "prepare_multisect() returned true value");
is(ref($bisected_outputs), 'ARRAY', "prepare_multisect() returned array ref");
say STDERR "BBB:";
pp($self2);
cmp_ok(
    scalar(@{$bisected_outputs}),
    '==',
    scalar(@{$self2->get_commits_range}),
    "Got expected number of elements in bisected outputs"
);
ok(scalar(@{$bisected_outputs->[0]}), "Array ref in first element is non-empty");
ok(scalar(@{$bisected_outputs->[-1]}), "Array ref in last element is non-empty");
$bisected_outputs_undef_count = 0;
for my $idx (1 .. ($#{$bisected_outputs} - 1)) {
    $bisected_outputs_undef_count++
        if defined $bisected_outputs->[$idx];
}
ok(! $bisected_outputs_undef_count,
    "After prepare_multisect(), internal elements are all as yet undefined");

$idx = 0;
$self2->identify_first_transition_per_target($idx);

note("prepare_multisect_hash()");

$bisected_outputs = $self2->prepare_multisect_hash();
ok($bisected_outputs, "prepare_multisect_hash() returned true value");
is(ref($bisected_outputs), 'HASH', "prepare_multisect() returned hash ref");
say STDERR "CCC: hash form of bisected_outputs";
pp($bisected_outputs);
for my $target (keys %{$bisected_outputs}) {
    ok(defined $bisected_outputs->{$target}->[0], "first element for $target is defined");
    ok(defined $bisected_outputs->{$target}->[-1], "last element for $target is defined");
    is(ref($bisected_outputs->{$target}->[0]), 'HASH', "first element for $target is a hash ref");
    is(ref($bisected_outputs->{$target}->[-1]), 'HASH', "last element for $target is a hash ref");
    $bisected_outputs_undef_count = 0;
    for my $idx (1 .. ($#{$bisected_outputs->{$target}} - 1)) {
        $bisected_outputs_undef_count++
            if defined $bisected_outputs->{$target}->[$idx];
    }
    ok(! $bisected_outputs_undef_count,
        "After prepare_multisect_hash(), internal elements for $target are all as yet undefined");
}
