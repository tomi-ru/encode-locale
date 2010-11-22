package Encode::Locale;

use strict;
our $VERSION = "0.03";

use base 'Exporter';
our @EXPORT_OK = qw(
    decode_argv env
    $ENCODING_LOCALE $ENCODING_LOCALE_FS
    $ENCODING_CONSOLE_IN $ENCODING_CONSOLE_OUT
);

use Encode ();
use Encode::Alias ();

our $ENCODING_LOCALE;
our $ENCODING_LOCALE_FS;
our $ENCODING_CONSOLE_IN;
our $ENCODING_CONSOLE_OUT;

sub DEBUG () { 0 }

sub _init {
    if ($^O eq "MSWin32") {
	# If we have the Win32::Console module installed we can ask
	# it for the code set to use
	eval {
	    require Win32::Console;
	    my $cp = Win32::Console::InputCP();
	    $ENCODING_CONSOLE_IN = "cp$cp" if $cp;
	    $cp = Win32::Console::OutputCP();
	    $ENCODING_CONSOLE_OUT = "cp$cp" if $cp;
	};
	# Invoking the 'chcp' program might also work
	if (!$ENCODING_CONSOLE_IN && qx(chcp) =~ /^Active code page: (\d+)/) {
	    $ENCODING_CONSOLE_IN = "cp$1";
	}
    }

    unless ($ENCODING_LOCALE) {
	eval {
	    require I18N::Langinfo;
	    $ENCODING_LOCALE = I18N::Langinfo::langinfo(I18N::Langinfo::CODESET());

	    # Workaround of Encode < v2.25.  The "646" encoding  alias was
	    # introducted in Encode-2.25, but we don't want to require that version
	    # quite yet.  Should avoid the CPAN testers failure reported from
	    # openbsd-4.7/perl-5.10.0 combo.
	    $ENCODING_LOCALE = "ascii" if $ENCODING_LOCALE eq "646";
	};
	$ENCODING_LOCALE ||= $ENCODING_CONSOLE_IN;
    }

    if ($^O eq "darwin") {
	$ENCODING_LOCALE_FS ||= "UTF-8";
    }

    # final fallback
    $ENCODING_LOCALE ||= $^O eq "MSWin32" ? "cp1252" : "UTF-8";
    $ENCODING_LOCALE_FS ||= $ENCODING_LOCALE;
    $ENCODING_CONSOLE_IN ||= $ENCODING_LOCALE;
    $ENCODING_CONSOLE_OUT ||= $ENCODING_CONSOLE_IN;

    unless (Encode::find_encoding($ENCODING_LOCALE)) {
	die "The locale codeset ($ENCODING_LOCALE) isn't one that perl can decode, stopped";
    }
}

_init();
Encode::Alias::define_alias(sub {
    no strict 'refs';
    return ${"ENCODING_" . uc(shift)};
}, "locale");

sub _flush_aliases {
    no strict 'refs';
    for my $a (keys %Encode::Alias::Alias) {
	if (defined ${"ENCODING_" . uc($a)}) {
	    delete $Encode::Alias::Alias{$a};
	    warn "Flushed alias cache for $a" if DEBUG;
	}
    }
}

sub reinit {
    $ENCODING_LOCALE = shift;
    $ENCODING_LOCALE_FS = shift;
    $ENCODING_CONSOLE_IN = $ENCODING_LOCALE;
    $ENCODING_CONSOLE_OUT = $ENCODING_LOCALE;
    _init();
    _flush_aliases();
}

sub decode_argv {
    die if defined wantarray;
    for (@ARGV) {
	$_ = Encode::decode(locale => $_, @_);
    }
}

sub env {
    my $k = Encode::encode(locale => shift);
    my $old = $ENV{$k};
    if (@_) {
	my $v = shift;
	if (defined $v) {
	    $ENV{$k} = Encode::encode(locale => $v);
	}
	else {
	    delete $ENV{$k};
	}
    }
    return Encode::decode(locale => $old) if defined wantarray;
}

1;
