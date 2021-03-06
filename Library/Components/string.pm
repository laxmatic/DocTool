package String;
use strict;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self  = {value => undef,
                 docEnv => undef,

                 css_class => undef,
                 @_};
    bless ($self, $class);

    die unless $self->{docEnv};

    return $self;
}

sub value
{
    my $self = shift;
    return $self->{value};
}

sub html
{
    my $self = shift;
    my %args = (html => undef,
                @_);

    die unless $args{html};

    return unless $self->{value};

    $self->{value} =~ s/</&lt;/g;
    $self->{value} =~ s/>/&gt;/g;

    $args{html}->append(line => Encode::encode("utf-8", $self->{value}));
}

sub plain
{
    my $self = shift;
    my %args = (@_);

    return Encode::encode("utf-8", $self->{value});
}

sub Parse
{
    my $class = shift;
    my %args = (string => undef,
                value => undef,
                @_);

    my $docEnv = $args{string}->{docEnv};
    unless ($args{string}) {
        if ($args{value}) {
            $args{string} = String->new(value => $args{value},
                                        docEnv => $docEnv);
        } else {
            die;
        }
    }

    if (my $content = $class->ParseDoubleQuotes(string => $args{string})) {
        return $content;
    }
    if (my $content = $class->ParseSingleQuotes(string => $args{string})) {
        return $content;
    }
    if (my $content = $class->ParseLeftRightQuotes(string => $args{string})) {
        return $content;
    }
    return [$args{string}];
}


use Emphasize;
use Footnote;
use Latex;
use Link;


BEGIN {
    our @Components = (qw(Emphasize),
                       qw(Link),
                       qw(Latex),
                       qw(Footnote)
                       );

    our %SingleQuotes;
    our %DoubleQuotes;
    our %LeftRightQuotes;

    our $SingleQuotes = "";
    our @DoubleQuotes;
    our @LeftRightQuotes;

    for my $component (@String::Components) {
        my $chars = $component->SingleQuotes();
        if ($chars) {
            $String::SingleQuotes = $String::SingleQuotes . $chars;
            for my $char (split (//, $chars)) {
                $String::SingleQuotes{$char} = $component;
            }
        }
        $chars = $component->DoubleQuotes();
        if ($chars) {
            my @chars = split (//, $component->DoubleQuotes());
            if (scalar @chars) {
                push(@String::DoubleQuotes, @chars);
                for my $char (@chars) {
                    $String::DoubleQuotes{$char} = $component;
                }
            }
        }
        $chars = $component->LeftQuote();
        if ($chars) {
            my $right = $component->RightQuote();
            die unless $right;
            push(@String::LeftRightQuotes, {Left => $chars, Right => $right});
            $String::LeftRightQuotes{$chars . $right} = $component;
        }
    }
}

sub ParseSingleQuotes
{
    my $class = shift;
    my %args = (string => undef,
                @_);

    return undef
        unless $String::SingleQuotes;

    my $string = $args{string}->value();
    my $docEnv = $args{string}->{docEnv};
    return undef
        unless $string =~ /^[^${String::SingleQuotes}]*?([${String::SingleQuotes}])/;

    my $found = $1;
    my $char ="[$found]";
    my $notChar ="[^$found]";

    return undef
        unless $string =~ /^(${notChar}*?)${char}(${notChar}+?)${char}(.*)$/;

    my ($one, $two, $three) = ($1, $2, $3);

    return [@{String->Parse(string => String->new(value => $one,
                                                  docEnv => $docEnv))},
            $String::SingleQuotes{$found}->new(
                                     string => String->new(value => $two,
                                                           docEnv => $docEnv),
                                     singleQuote => $found
                                     ),
            @{String->Parse(string => String->new(value => $three,
                                                  docEnv => $docEnv))}];
}

sub ParseDoubleQuotes
{
    my $class = shift;
    my %args = (string => undef,
                @_);

    return undef
        unless scalar @String::DoubleQuotes;

    my $string = $args{string}->value();
    my $docEnv = $args{string}->{docEnv};

    my $found = undef;
    my $foundPos = length($string)+1;

    for my $char (@String::DoubleQuotes) {
        if ((my $pos = index($string, "${char}${char}"))>-1) {
            if ($pos<$foundPos) {
                $found = $char;
                $foundPos = $pos;
            }
        }
    }
    return undef
        unless $found;

    return undef
        unless $string =~ /^(.*?)${found}${found}(.+?)${found}${found}(.*)$/;

    my ($one, $two, $three) = ($1, $2, $3);

    return [@{String->Parse(string => String->new(value => $one,
                                                  docEnv => $docEnv))},
            $String::DoubleQuotes{$found}->new(
                                     string => String->new(value => $two,
                                                           docEnv => $docEnv),
                                     doubleQuote => $found,
                                     ),
            @{String->Parse(string => String->new(value => $three,
                                                  docEnv => $docEnv))}];
}

sub ParseLeftRightQuotes
{
    my $class = shift;
    my %args = (string => undef,
                @_);

    return undef
        unless scalar @String::LeftRightQuotes;

    my $string = $args{string}->value();
    my $docEnv = $args{string}->{docEnv};

    my $foundLeft = undef;
    my $foundRight = undef;
    my $foundPos = length($string)+1;
    my $posLeft;
    my $posRight;

    for my $pair (@String::LeftRightQuotes) {

        my $left  = $pair->{Left};
        my $right = $pair->{Right};

        $posLeft = index($string, $left);
        $posRight = index($string, $right, $posLeft+length($left));

        return if $posLeft<0;
        return if $posRight<0;

        if ($posLeft<$foundPos) {
            $foundPos = $posLeft;
            $foundLeft = $left;
            $foundRight = $right;
        }
    }
    return undef
        unless $foundLeft;

    my $one = substr($string, 0, $posLeft);
    my $two = substr($string,
                     $posLeft+length($foundLeft),
                     $posRight-$posLeft-length($foundLeft));
    my $three = substr($string, $posRight+length($foundRight));



    return [@{String->Parse(string => String->new(value => $one,
                                                  docEnv => $docEnv))},
            $String::LeftRightQuotes{$foundLeft . $foundRight}->new(
                                     string => String->new(value => $two,
                                                           docEnv => $docEnv),
                                     leftQuote  => $foundLeft,
                                     rightQuote => $foundRight,
                                     ),
            @{String->Parse(string => String->new(value => $three,
                                                  docEnv => $docEnv))}];
}

1;
