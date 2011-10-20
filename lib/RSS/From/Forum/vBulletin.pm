package RSS::From::Forum::vBulletin;

use 5.010;
use strict;
use warnings;

use LWP::UserAgent;
use Mojo::DOM;
use URI::URL;

use Exporter::Lite;
our @EXPORT_OK = qw(get_rss_from_forum);

# VERSION

our %SPEC;

sub _strip_session_param {
    my $url = shift;
    $url =~ s/([?&])s=[0-9a-f]{32}(&|$)/
        ($1 eq '?' ? '?' : '') /e;
    $url;
}

$SPEC{get_rss_from_forum} = {
    summary => 'Generate an RSS page by parsing vBulletin forum display page',
    description => <<'_',

Many vBulletin forums do not turn on RSS feeds. This function parses vBulletin
forum display page and create a simple RSS page so you can subscribe to it using
RSS.

_
    args    => {
        url => ['str*' => {
            summary     => 'Forum URL (the forum display page)',
            description => <<'_',

Usually it's of the form: http://host/path/forumdisplay.php?f=XXX

_
            arg_pos     => 0,
        }],
        ua => ['obj' => {
            summary     => 'Supply a custom LWP::UserAgent object',
            description => <<'_',

If supplied, will be used instead of the default LWP::UserAgent object.

_
        }],
    },
};
sub get_rss_from_forum {
    my %args = @_;

    state $default_ua = LWP::UserAgent->new;

    my $url = $args{url} or return [400, "Please specify url"];
    my $ua = $args{ua} // $default_ua;

    my $uares;
    eval { $uares = $ua->get($url) };
    return [500, "Can't download URL `$url`: $@"] if $@;
    return [$uares->code, "Can't download URL: " . $uares->message]
        unless $uares->is_success;

    my $dom;
    eval { $dom = Mojo::DOM->new($uares->content) };
    return [500, "Can't create DOM from read URL: $@"] if $@;

    my $gen = "RSS::From::Forum::vBulletin " .
        ($RSS::From::Forum::vBulletin::VERSION // "?"). " (Perl module)";

    my @rss;

    push @rss, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    push @rss, "<!-- generator=$gen -->\n";
    push @rss, "<rss version=\"2.0\">\n";
    push @rss, "<channel>\n";

    my $els = $dom->find("title");
    push @rss, "<title>",
        ($els->[0] ? $els->[0]->text : "(untitled)"), "</title>\n";
    push @rss, "<link>$url</link><!-- HTML, not RSS -->\n";
    push @rss, "<generator>$gen</generator>\n";

    # find all table rows containing show thread url
    my $rows = $dom->find("tr");
    for my $row (@$rows) {
        my $a = $row->find(qq{a[href*="showthread.php"]});
        next unless @$a;
        push @rss, "<item>\n";
        push @rss, "<title>", $a->[0]->text, "</title>\n";
        my $iurl = URI::URL->new($a->[0]->attrs->{href})->abs($url);
        $iurl = _strip_session_param("$iurl");
        push @rss, "<link>$iurl</link>\n";
        # TODO: pubDate
        # TODO: description
        push @rss, "</item>\n\n";
    }

    push @rss, "</channel>\n";
    push @rss, "</rss>\n";

    [200, "OK", join("", @rss)];
}

1;
#ABSTRACT: Generate Indonesian monthly HTML calendar
__END__

=head1 SYNOPSIS

 # See get-rss-from-forum for command-line usage


=head1 DESCRIPTION


=head1 FUNCTIONS

None are exported, but they are exportable.

=cut
