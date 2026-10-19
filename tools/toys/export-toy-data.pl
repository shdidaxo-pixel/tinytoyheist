#!/usr/bin/perl
# Export the toy data (palette, kits, every set file, rarities, mutations) from the Luau modules in
# src/ReplicatedStorage/Shared/Toys to design/toy-data.js, so the review page draws exactly what Studio builds.
#
# The data modules are plain `return { ... }` table literals (no locals, no functions), so this only needs a small
# Luau table parser. A table with any `key = value` field becomes a JSON object, otherwise an array.
#
# usage (from the repo root): perl tools/toys/export-toy-data.pl
use strict;
use warnings;
use JSON::PP;

my $root = "src/ReplicatedStorage/Shared/Toys";
my @SETS = qw(Bedroom Hallway Kitchen LivingRoom Garage Attic Halloween NightmareNight Winter Specials);

sub slurp {
	my ($path) = @_;
	open(my $fh, "<:encoding(UTF-8)", $path) or die "can't read $path: $!";
	local $/;
	my $s = <$fh>;
	close $fh;
	return $s;
}

# --- tokenizer -------------------------------------------------------------------------------------------------
sub tokenize {
	my ($src, $file) = @_;
	my @t;
	pos($src) = 0;
	while (pos($src) < length $src) {
		if ($src =~ /\G\s+/gc) { next }
		if ($src =~ /\G--\[(=*)\[.*?\]\1\]/gcs) { next }
		if ($src =~ /\G--[^\n]*/gc) { next }
		if ($src =~ /\G"((?:[^"\\]|\\.)*)"/gc or $src =~ /\G'((?:[^'\\]|\\.)*)'/gc) {
			my $s = $1;
			$s =~ s/\\n/\n/g;
			$s =~ s/\\t/\t/g;
			$s =~ s/\\(.)/$1/g;
			push @t, ["str", $s];
			next;
		}
		if ($src =~ /\G(-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)/gc) { push @t, ["num", $1 + 0]; next }
		if ($src =~ /\G([A-Za-z_][A-Za-z0-9_]*)/gc) { push @t, ["name", $1]; next }
		if ($src =~ /\G([{}=,;\[\]])/gc) { push @t, ["sym", $1]; next }
		die "$file: unexpected character near: " . substr($src, pos($src), 40);
	}
	return \@t;
}

# --- parser ----------------------------------------------------------------------------------------------------
my ($T, $P, $F);

sub peek { return $T->[$P] }
sub take {
	my ($kind, $val) = @_;
	my $tok = $T->[$P] or die "$F: unexpected end of file";
	if (defined $kind and ($tok->[0] ne $kind or (defined $val and $tok->[1] ne $val))) {
		die "$F: expected $kind " . ($val // "") . " but got $tok->[0] '$tok->[1]' (token $P)";
	}
	$P++;
	return $tok;
}

sub value {
	my $tok = peek() or die "$F: unexpected end";
	if ($tok->[0] eq "sym" and $tok->[1] eq "{") { return table() }
	if ($tok->[0] eq "str") { $P++; return $tok->[1] }
	if ($tok->[0] eq "num") { $P++; return $tok->[1] }
	if ($tok->[0] eq "name") {
		$P++;
		return JSON::PP::true if $tok->[1] eq "true";
		return JSON::PP::false if $tok->[1] eq "false";
		return undef if $tok->[1] eq "nil";
		die "$F: bare name '$tok->[1]' is not allowed in toy data (token $P)";
	}
	die "$F: unexpected token '$tok->[1]' (token $P)";
}

sub table {
	take("sym", "{");
	my (@arr, %obj, @order);
	my $keyed = 0;
	while (1) {
		my $tok = peek();
		last if $tok->[0] eq "sym" and $tok->[1] eq "}";
		my $nx = $T->[$P + 1];
		if ($tok->[0] eq "name" and $nx and $nx->[0] eq "sym" and $nx->[1] eq "=") {
			$P += 2;
			$obj{ $tok->[1] } = value();
			push @order, $tok->[1];
			$keyed = 1;
		} elsif ($tok->[0] eq "sym" and $tok->[1] eq "[") {
			$P++;
			my $k = take("str")->[1];
			take("sym", "]");
			take("sym", "=");
			$obj{$k} = value();
			push @order, $k;
			$keyed = 1;
		} else {
			push @arr, value();
		}
		my $sep = peek();
		if ($sep->[0] eq "sym" and ($sep->[1] eq "," or $sep->[1] eq ";")) { $P++; next }
		last;
	}
	take("sym", "}");
	die "$F: table mixes keyed and positional fields (token $P)" if $keyed and @arr;
	return $keyed ? \%obj : \@arr;
}

sub parse_module {
	my ($path) = @_;
	$F = $path;
	$T = tokenize(slurp($path), $path);
	$P = 0;
	take("name", "return");
	my $v = value();
	die "$path: trailing tokens after the returned table" if $P < @$T;
	return $v;
}

# --- checks ----------------------------------------------------------------------------------------------------
# The same rules ToyCatalog.validate checks in Studio, so mistakes show up before anything is built.
my @problems;
my ($palette, %RARITY, %SIZE, %CHANNEL, %WAVE);
@RARITY{qw(Common Uncommon Rare Epic Legendary Mythic Secret)} = ();
@SIZE{qw(S M L G)} = ();
@CHANNEL{qw(PosX PosY PosZ RotX RotY RotZ Fade)} = ();
@WAVE{qw(Sin Abs Pos Lift Spin Const Pulse Turn Step Wobble)} = ();
my %seen_id;

sub problem { push @problems, join("", @_) }
sub isnum { defined $_[0] and !ref $_[0] and $_[0] =~ /^-?[\d.]+(?:e-?\d+)?$/i }

sub check_colour {
	my ($c, $where, $in_kit) = @_;
	return problem("$where: colour missing") unless defined $c and !ref $c;
	return if $c =~ /^#[0-9A-Fa-f]{6}$/;
	return if $in_kit and $c =~ /^\$\w+$/;
	problem("$where: unknown colour '$c'") unless exists $palette->{Colors}{$c};
}

# Walk a part list, collecting group names; returns the number of boxes (mirrored ones count twice).
sub check_parts {
	my ($parts, $where, $groups, $in_kit, $slots) = @_;
	my $n = 0;
	return problem("$where: Parts must be a list") && 0 unless ref $parts eq "ARRAY";
	for my $p (@$parts) {
		if (ref $p eq "ARRAY") {
			my @b = @$p;
			if (@b < 7 or @b > 9) { problem("$where: a box needs { x, y, z, w, h, d, colour, flags?, rot? }"); next }
			for my $i (0 .. 5) { problem("$where: box value $i is not a number") unless isnum($b[$i]) }
			for my $i (3 .. 5) { problem("$where: box has a zero or negative size") if isnum($b[$i]) and $b[$i] <= 0 }
			if (defined $b[6] and !ref $b[6] and $b[6] =~ /^\$(\w+)$/ and !$in_kit) { problem("$where: kit slot colour '$b[6]' outside a kit") }
			else { check_colour($b[6], $where, $in_kit) }
			my $flags = $b[7] // "";
			problem("$where: unknown flag in '$flags' (use m M N G F)") if $flags =~ /[^mMNGF]/;
			$n += $flags =~ /m/ ? 2 : 1;
		} elsif (ref $p eq "HASH" and defined $p->{Kit}) {
			my $kit = $palette->{Kits}{ $p->{Kit} };
			if (!$kit) { problem("$where: unknown kit '$p->{Kit}'"); next }
			my %need;
			my $walk;
			$walk = sub { for my $q (@{ $_[0] }) { if (ref $q eq "ARRAY") { $need{$1} = 1 if ($q->[6] // "") =~ /^\$(\w+)$/ } elsif (ref $q eq "HASH" and $q->{Parts}) { $walk->($q->{Parts}) } } };
			$walk->($kit);
			for my $s (sort keys %need) {
				my $v = $p->{Colors} ? $p->{Colors}{$s} : undef;
				if (!defined $v) { problem("$where: kit $p->{Kit} needs Colors.$s") }
				else { check_colour(ref $v eq "ARRAY" ? $v->[0] : $v, "$where (kit $p->{Kit}.$s)") }
			}
			$n += check_parts($kit, "$where (kit $p->{Kit})", $groups, 1);
		} elsif (ref $p eq "HASH" and defined $p->{Group}) {
			my $g = $p->{Group};
			if (!$groups->{$g}) {
				problem("$where: new group '$g' needs a Pivot { x, y, z }") unless ref $p->{Pivot} eq "ARRAY" and @{ $p->{Pivot} } == 3;
				$groups->{$g} = 1;
			}
			$n += check_parts($p->{Parts}, "$where > $g", $groups, $in_kit);
		} else {
			problem("$where: a part must be a box list, a { Kit = ... } or a { Group = ... }");
		}
	}
	return $n;
}

sub check_toy {
	my ($t, $set) = @_;
	my $id = $t->{Id} // "?";
	my $w = "$set.$id";
	problem("$w: Id must be PascalCase letters and digits") unless $id =~ /^[A-Z][A-Za-z0-9]*$/;
	problem("$w: duplicate Id (also in $seen_id{$id})") if $seen_id{$id};
	$seen_id{$id} = $set;
	for my $k (qw(Name Look IdleText)) { problem("$w: missing $k") unless defined $t->{$k} and length $t->{$k} }
	problem("$w: Rarity must be one of Common..Secret") unless defined $t->{Rarity} and exists $RARITY{ $t->{Rarity} };
	problem("$w: Size must be S, M, L or G") unless defined $t->{Size} and exists $SIZE{ $t->{Size} };
	problem("$w: Money must be a positive number") unless isnum($t->{Money}) and $t->{Money} > 0;
	my $epic = defined $t->{Rarity} && $t->{Rarity} =~ /^(Epic|Legendary|Mythic|Secret)$/;
	problem("$w: Epic and up need a Perk") if $epic and !$t->{Perk};
	my %groups = (Body => 1);
	my $n = check_parts($t->{Parts}, $w, \%groups, 0);
	problem("$w: has no blocks") unless $n;
	problem("$w: $n blocks is a lot for phones (keep it under 90)") if $n > 90;
	if (ref $t->{Idle} ne "ARRAY" or !@{ $t->{Idle} }) { problem("$w: needs an Idle animation") }
	else {
		for my $tr (@{ $t->{Idle} }) {
			if (ref $tr ne "ARRAY" or @$tr < 4) { problem("$w: an Idle track is { target, channel, amp, speed, wave?, phase?, duty? }"); next }
			my ($tg, $ch, $a, $sp, $wv) = @$tr;
			problem("$w: Idle targets unknown group '$tg'") unless $groups{$tg};
			problem("$w: Idle channel '$ch' (use PosX PosY PosZ RotX RotY RotZ Fade)") unless exists $CHANNEL{$ch};
			problem("$w: Idle wave '$wv'") if defined $wv and !exists $WAVE{$wv};
			problem("$w: Idle amp/speed must be numbers") unless isnum($a) and isnum($sp);
		}
	}
	for my $fx (@{ $t->{Fx} // [] }) {
		if (ref $fx ne "ARRAY" or @$fx < 2) { problem("$w: an Fx entry is { preset, { x, y, z }, group?, rate? }"); next }
		problem("$w: unknown Fx preset '$fx->[0]'") unless $palette->{Fx}{ $fx->[0] };
		problem("$w: Fx point must be { x, y, z }") unless ref $fx->[1] eq "ARRAY" and @{ $fx->[1] } == 3;
		problem("$w: Fx group '$fx->[2]' doesn't exist") if defined $fx->[2] and !$groups{ $fx->[2] };
	}
	$t->{Blocks} = $n;
}

# --- export ----------------------------------------------------------------------------------------------------
$palette = parse_module("$root/ToyPalette.luau");
my $data = {
	palette => $palette,
	rarities => parse_module("$root/ToyRarities.luau"),
	mutations => parse_module("$root/MutationData.luau"),
	sets => [],
};
my ($count, $blocks) = (0, 0);
for my $set (@SETS) {
	my $path = "$root/Sets/$set.luau";
	next unless -f $path;
	my $s = eval { parse_module($path) };
	if (!$s) { problem("$set: can't read $path: $@"); next }
	problem("$set: Set should be '$set'") unless ($s->{Set} // "") eq $set;
	for my $t (@{ $s->{Toys} // [] }) { check_toy($t, $set); $count++; $blocks += $t->{Blocks} // 0 }
	push @{ $data->{sets} }, $s;
}

my $json = JSON::PP->new->utf8->canonical->allow_nonref->encode($data);
open(my $out, ">:raw", "design/toy-data.js.tmp") or die "can't write design/toy-data.js.tmp: $!";
print $out "// Generated by tools/toys/export-toy-data.pl from src/ReplicatedStorage/Shared/Toys. Don't edit by hand.\n";
print $out "window.TOY_DATA = $json;\n";
close $out;
rename("design/toy-data.js.tmp", "design/toy-data.js") or die "can't replace design/toy-data.js: $!";
printf "design/toy-data.js: %d sets, %d toys, %d blocks (avg %.0f), %d bytes\n", scalar @{ $data->{sets} }, $count, $blocks,
	$count ? $blocks / $count : 0, length $json;
if (@problems) {
	print scalar(@problems), " problem(s):\n";
	print "  $_\n" for @problems;
	exit 1;
}
print "no problems\n";
