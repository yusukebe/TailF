package TailF::Twitter::StreamServer;
use Mouse;
use AnyEvent::Twitter::Stream;
use Continuity;
use Encode;
use Template;
use utf8;

with 'MouseX::Getopt';

has 'username' => ( is => 'rw', isa => 'Str', required => 1 );
has 'password' => ( is => 'rw', isa => 'Str', required => 1 );
has 'port'  => ( is => 'rw', isa => 'Int', default => 16001 );
has 'track' => ( is => 'rw', isa => 'Str', default => 'http' );
has 'server' => ( is => 'ro', isa => 'Continuity', lazy_build => 1 );
has 'docroot' => ( is => 'rw', isa => 'Str', default => './root/' );
has 'tweets' => (
    is         => 'rw',
    isa        => 'ArrayRef',
    default    => sub { [] },
    auto_deref => 1,
);
has 'template' => (
      is      => 'rw',
      isa     => 'Template',
      default => sub {
          return Template->new( { INCLUDE_PATH => './tmpl/' } );
      }
);

no Mouse;

$Event::DIED = sub {
    Event::verbose_exception_handler(@_);
    Event::unloop_all();
    Event::loop();
};

sub _build_server {
    my $self = shift;
    return Continuity->new(
        port           => $self->port,
        path_session   => 1,
        cookie_session => 'sid',
        staticp =>
          sub { $_[0]->url =~ m/\.(jpg|jpeg|gif|png|css|ico|js|html)$/ },
        callback => sub { $self->main(@_) },
        docroot => $self->docroot,
    );
}

sub run {
    my $self = shift;
    my $done = AnyEvent->condvar;

    my $streamer = AnyEvent::Twitter::Stream->new(
        username => $self->username,
        password => $self->password,
        method   => 'filter',
        track    => $self->track,
        on_tweet => sub {
            my $tweet = shift;
            my $text = $tweet->{text};
            if ( $text && $text =~ /[あ-んア-ン]/ ) {
                my @tweets = $self->tweets;
                shift @tweets if $#tweets > 20;
                if ( $text =~
                    /(https?:\/\/[-_.!~*\'a-zA-Z0-9;\/?:\@&=+\$,%\#]+)/ )
                {
                    my $link = $1;
                    $text =~ s!$link!<a href="$link" target="_blank">$link</a>!;
                }
                push(
                    @tweets,
                    encode(
                        'utf8',
                        $self->templatize( { tweet => $tweet, text => $text } )
                    ),
                );
                $self->tweets( \@tweets );
            }
        },
        on_error => sub {
            my $error = shift;
            warn "ERROR: $error";
            $done->send;
        },
        on_eof => sub {
            $done->send;
        },
    );

    $self->server->loop;
    $done->recv;
}

sub templatize {
    my ( $self, $var ) = @_;
    my $output = '';
    $self->template->process( 'tweet.tt2', $var, \$output )
      || die $self->template->error();
    return $output;
}

sub main {
    my ( $self, $req ) = @_;
    my $path = $req->request->url->path;
    print STDERR "Path: '$path'\n";
    $self->pushstream($req) if $path =~ /pushstream/;
}

sub pushstream {
    my ($self, $req) = @_;
    while (1) {
        my $log = join "\n", $self->tweets;
        $req->print($log);
        $req->next;
    }
}

1;
__END__
