package GameBoard ;

# $Id: GameBoard.pm,v 1.12 2000/04/24 14:12:34 root Exp root $

# Copyright (c) Mark Summerfield 2000. All Rights Reserved.
# May be used/distributed under the GPL.

use strict ;

use Carp ;

use vars qw( $VERSION ) ;
$VERSION = '0.02' ;


use readonly
        # Public class constants
        '$TILE'                    =>   0,
        '$COLOUR'                  =>   1,

        # Private class constants
        '$DEF_HEIGHT'              =>   8,
        '$DEF_WIDTH'               =>  12,
        '$DEF_LENGTH'              =>  36,
        '$DEF_SCALE'               =>   1,

        '$DEF_DELAY'               => 200, # 1/5 sec delay
        '$DEF_BEEP'                =>   1,

        '$DEF_BACKGROUND_COLOUR'   => '#FFFFFF', # white
        '$DEF_OUTLINE_COLOUR'      => '#DFDFDF', # grey80
        '$DEF_MAX_COLOURS'         =>   3,
        '$DEF_BUTTON_NEW'          =>   1, # 0 means use Start + Pause/Resume
        '$DEF_SHAPE'               => 'octagon', 
        '$SHAPES'                  => 'circle:square:triangle:hexagon:star5:star6:' .
                                      'octagon:heart:random:pie:spiral1:spiral2',

        '$BUTTON_WIDTH'            =>  10,
        '$BUTTON_NEW'              => 'New',
        '$BUTTON_START'            => 'Start',
        '$BUTTON_PAUSE'            => 'Pause',
        '$BUTTON_OPTIONS'          => 'Options',
        '$BUTTON_ABOUT'            => 'About',
        '$BUTTON_HELP'             => 'Help',
        '$BUTTON_QUIT'             => 'Quit',
        '$BUTTON_SCORE'            => 'Score',
        '$BUTTON_STATUS'           => 'Status',
 
        ;

# Private methods

sub _set {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $field = shift ;

    $self->{$field} = shift ;
}


# Public methods

sub new { # Class and object method 
    my $obj   = shift ;
    my $class = ref( $obj ) || $obj ;
    my $self  = {} ;

    if( ref $obj ) { # $obj->new
        my %arg = @_ ;

        foreach my $field ( $class->_fields ) {
            $self->{$field} = defined $arg{$field} ? 
                                $arg{$field} : $obj->get( $field ) ;
        }
    }
    else {           # Class->new
        %{$self} = (
            -window     => undef, # Mandatory
            -canvas     => undef, # Should not be assigned to
            -quit       => undef, # Mandatory
            -height     => $DEF_HEIGHT,         # User
            -width      => $DEF_WIDTH,          # User
            '-length'   => $DEF_LENGTH,
            -scale      => $DEF_SCALE,          # User
            -background => $DEF_BACKGROUND_COLOUR,
            -outline    => $DEF_OUTLINE_COLOUR, 
            -maxcolours => $DEF_MAX_COLOURS,    # User
            -tile       => undef, # Should not be assigned to
            -tileref    => undef, # Should not be assigned to
            -tiles      => undef, # Should not be assigned to
            -delay      => $DEF_DELAY,          # User
            -beep       => $DEF_BEEP,           # User
            -shape      => $DEF_SHAPE,          # User
            -buttonnew  => $DEF_BUTTON_NEW,
            -hiscore    => 0,                   # User
            @_, 
        ) ;
    }

    croak "-window is mandatory" unless defined $self->{-window} ;
    croak "-quit is mandatory"   unless defined $self->{-quit} ;
    croak "-canvas should not be assigned to"  if defined $self->{-canvas} ;
    croak "-tile should not be assigned to"    if defined $self->{-tile} ;
    croak "-tileref should not be assigned to" if defined $self->{-tileref} ;
    croak "-tiles should not be assigned to"   if defined $self->{-tiles} ;
    # Do any other fatal error checks here.

    bless $self, $class ;

    $self->init_buttons ;
    $self->bind_keyboard ;
    $self->init_board ;

    $self ;
}


sub DESTROY {
    ; # Save's time.
}


sub get { # Object method
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $field = shift ;

    if( $field eq '-tile' or $field eq '-tileref' ) {
        my( $x, $y ) = @_ ;
        croak "x and y coords required" unless defined $x and defined $y ;
        # We do NOT range check
        $field eq '-tile' ? $self->{-tiles}[$x][$y][$COLOUR] : 
                            $self->{-tiles}[$x][$y][$TILE] ; # -tileref
    }
    elsif( $field =~ /_display$/o ) {
        $self->{$field}->cget( -text ) ;
    }
    elsif( $field eq '-shapes' ) {
        my @shape = split /:/, $SHAPES ;
        wantarray ? @shape : scalar @shape ;
    }
    else {
        $self->{$field} ;
    }
}


sub set { # Object method
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $field = shift ;

    if( $field eq '-tile' ) {
        my( $x, $y, $colour ) = @_ ;
        croak "x and y coords required" unless defined $x and defined $y ;
        # We do NOT range check
        $self->{-tiles}[$x][$y][$COLOUR] = $colour ; 
        if( $colour =~ /^#[\dA-Fa-f]{6}$/o ) {
            $self->{-canvas}->itemconfigure(
                $self->{-tiles}[$x][$y][$TILE], -fill => $colour, ) ;
        }
    }
    elsif( $field =~ /_display$/o ) {
        my $widget = $self->{$field} ;
        $widget->configure( -text, shift() ) ;
        $widget->update ;
    }
    else {
        $self->{$field} = shift ;
    }
}


sub init_buttons { # Object method
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $buttonbar = $self->get( -window )->
                        Frame()->pack( -side => 'left', -anchor => 'nw', ) ;

    my $buttonnew = $self->get( -buttonnew ) ;

    my $row = 0 ;

    if( $buttonnew ) {
        $buttonbar->Button(
            -text      => $BUTTON_NEW,
            -underline => 0,
            -width     => $BUTTON_WIDTH,
            -command   => sub { $self->new_game },
            )->grid( -row => $row++, -column => 0 ) ;
    }
    else {
        $buttonbar->Button(
            -text      => $BUTTON_START,
            -underline => 0,
            -width     => $BUTTON_WIDTH,
            -command   => sub { $self->new_game },
            )->grid( -row => $row++, -column => 0 ) ;

        $buttonbar->Button(
            -text      => $BUTTON_PAUSE,
            -underline => 0,
            -width     => $BUTTON_WIDTH,
            -command   => sub { $self->pause_resume },
            )->grid( -row => $row++, -column => 0 ) ;
    }

    $buttonbar->Button(
        -text      => $BUTTON_OPTIONS,
        -underline => 0,
        -width     => $BUTTON_WIDTH,
        -command   => sub { $self->options },
        )->grid( -row => $row++, -column => 0 ) ;

    $buttonbar->Button(
        -text      => $BUTTON_ABOUT,
        -underline => 0,
        -width     => $BUTTON_WIDTH,
        -command   => sub { $self->about },
        )->grid( -row => $row++, -column => 0 ) ;

    $buttonbar->Button(
        -text      => $BUTTON_HELP,
        -underline => 0,
        -width     => $BUTTON_WIDTH,
        -command   => sub { $self->help },
        )->grid( -row => $row++, -column => 0 ) ;

    $buttonbar->Button(
        -text      => $BUTTON_QUIT,
        -underline => 0,
        -width     => $BUTTON_WIDTH,
        -command   => $self->get( -quit ),
        )->grid( -row => $row++, -column => 0 ) ;

    $buttonbar->Label(
        -text      => 'High Score',
        -width     => $BUTTON_WIDTH,
        )->grid( -row => $row++, -column => 0 ) ;

    my $hiscore = 
        $buttonbar->Label(
            -text      => $self->get( -hiscore ),
            -width     => $BUTTON_WIDTH,
            -fg        => 'DarkGreen',
            -relief    => 'sunken',
            )->grid( -pady => 5, -row => $row++, -column => 0 ) ;

    $buttonbar->Label(
        -text      => 'Score',
        -width     => $BUTTON_WIDTH,
        )->grid( -row => $row++, -column => 0 ) ;

    my $score = 
        $buttonbar->Label(
            -text      => '0',
            -width     => $BUTTON_WIDTH,
            -fg        => 'DarkGreen',
            -relief    => 'sunken',
            )->grid( -pady => 5, -row => $row++, -column => 0 ) ;

    my $status =
        $buttonbar->Label( 
            -width     => $BUTTON_WIDTH * 1.2,
            -text      => 'Running',
            -relief    => 'groove',
            )->grid( -pady => 3, -row => $row++, -column => 0 ) ;

    $self->_set( -score_display,   $score ) ;
    $self->_set( -hiscore_display, $hiscore ) ;
    $self->_set( -status_display,  $status ) ;
}


sub new_game     { croak     "new_game() must be overridden" }
sub pause_resume { croak "pause_resume() must be overridden" }
sub options      { croak      "options() must be overridden" }
sub about        { croak        "about() must be overridden" }
sub help         { croak         "help() must be overridden" }
sub click        { croak        "click() must be overridden" }
sub move_up      { croak      "move_up() must be overridden" }
sub move_down    { croak    "move_down() must be overridden" }
sub move_left    { croak    "move_left() must be overridden" }
sub move_right   { croak   "move_right() must be overridden" }


sub init_board { # Object method
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $ratio = $self->get( '-length' ) * $self->get( -scale ) ;

    $self->set( -canvas, $self->get( -window )->
            Canvas( -width  => $self->get( -width )  * $ratio, 
                    -height => $self->get( -height ) * $ratio, 
                    )->pack() ) ;

    my @tile ;
    $self->set( -tiles, \@tile ) ;

    $self->draw ;
}


sub draw {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $width       = $self->get( -width ) ;
    my $height      = $self->get( -height ) ;
    my $len         = $self->get( '-length' ) ;
    my $scale       = $self->get( -scale ) ;
    my $background  = $self->get( -background ) ;
    my $outline     = $self->get( -outline ) ;
    my $canvas      = $self->get( -canvas ) ;
    my $tile        = $self->get( -tiles ) ;
    my $shape       = $self->get( -shape ) ;
    my @shape       = map { 
                        $_ eq 'random' ? () : 
                            $_ eq 'circle' ? 'oval' :
                                $_ eq 'square' ? 'rectangle' :
                                    $_
                        } $self->get( -shapes ) ;
    my $shape_count = scalar @shape ;
    my $random      = $shape eq 'random' ? 1 : 0 ;

    $shape = 'oval'      if $shape eq 'circle' ;
    $shape = 'rectangle' if $shape eq 'square' ;
    my $smooth = $shape eq 'spiral2' ? 1 : 0 ;

    $canvas->delete( 'all' ) ;

    my $ratio = $len * $scale ;

    $canvas->configure(
        -width  => $width  * $ratio,
        -height => $height * $ratio,
        ) ; 

    # Precalculate in case needed
    my $half           = $len     / 2 ;
    my $third          = $len     / 3 ;
    my $two_thirds     = $third   * 2 ;
    my $quarter        = $len     / 4 ;
    my $three_quarters = $quarter * 3 ;
    my $fifth          = $len     / 5 ;
    my $four_fifths    = $fifth   * 4 ;

    for( my $x = 0 ; $x < $width ; $x++ ) {
        my $xpos = $x    * $len ;
        my $Xpos = $xpos + $len ;
        TILE:
        for( my $y = 0 ; $y < $height ; $y++ ) {
            my $ypos   = $y    * $len ;
            my $Ypos   = $ypos + $len ;
            my $colour = $tile->[$x][$y][$COLOUR] ||= $background ;
            $shape     = $shape[rand $shape_count] if $random ;
            if( $shape eq 'oval' or $shape eq 'rectangle' ) {
                $tile->[$x][$y][$TILE] = 
                    $canvas->create( $shape, 
                        $xpos, $ypos, 
                        $Xpos, $Ypos,
                        -fill => $colour, -outline => $outline ) ;
                next TILE ;
            }
            if( $shape eq 'pie' ) {
                $tile->[$x][$y][$TILE] = 
                    $canvas->create( 'arc', 
                        $xpos, $ypos, 
                        $Xpos, $Ypos,
                        -extent => -310,
                        -fill => $colour, -outline => $outline ) ;
                next TILE ;
            }
            elsif( $shape eq 'triangle' ) {
                $tile->[$x][$y][$TILE] = 
                    $canvas->create( 'polygon', 
                        $xpos,         $Ypos, 
                        $xpos + $half, $ypos,
                        $Xpos,         $Ypos,
                        -fill => $colour, -outline => $outline ) ;
                next TILE ;
            }
            elsif( $shape eq 'hexagon' ) {
                $tile->[$x][$y][$TILE] = 
                    $canvas->create( 'polygon', 
                        $xpos,         $ypos + $fifth, 
                        $xpos + $half, $ypos,
                        $Xpos,         $ypos + $fifth,
                        $Xpos,         $ypos + $four_fifths,
                        $xpos + $half, $Ypos,
                        $xpos,         $ypos + $four_fifths,
                        -fill => $colour, -outline => $outline ) ;
                next TILE ;
            }
            elsif( $shape eq 'star5' ) {
                $tile->[$x][$y][$TILE] = 
                    $canvas->create( 'polygon', 
                        $xpos,                   $ypos + $third, 
                        $xpos + $third,          $ypos + $third,
                        $xpos + $half,           $ypos,
                        $xpos + $two_thirds,     $ypos + $third,
                        $Xpos,                   $ypos + $third,
                        $xpos + $three_quarters, $ypos + $half,
                        $Xpos,                   $Ypos,
                        $xpos + $half,           $ypos + $two_thirds,
                        $xpos,                   $Ypos,
                        $xpos + $quarter,        $ypos + $half,
                        -fill => $colour, -outline => $outline ) ;
                next TILE ;
            }
            elsif( $shape eq 'octagon' ) {
                $tile->[$x][$y][$TILE] = 
                    $canvas->create( 'polygon', 
                        $xpos,                   $ypos + $quarter,
                        $xpos + $quarter,        $ypos,
                        $xpos + $three_quarters, $ypos,
                        $Xpos,                   $ypos + $quarter,
                        $Xpos,                   $ypos + $three_quarters,
                        $xpos + $three_quarters, $Ypos,
                        $xpos + $quarter,        $Ypos,
                        $xpos,                   $ypos + $three_quarters,
                        -fill => $colour, -outline => $outline ) ;
                next TILE ;
            }
            elsif( $shape eq 'heart' ) {
                $tile->[$x][$y][$TILE] = 
                    $canvas->create( 'polygon', 
                        $xpos,                   $ypos + $third,
                        $xpos + $quarter,        $ypos,
                        $xpos + $half,           $ypos + $quarter,
                        $xpos + $three_quarters, $ypos,
                        $Xpos,                   $ypos + $third,
                        $xpos + $half,           $Ypos,
                        -smooth => 1, -splinesteps => 4,
                        -fill => $colour, -outline => $outline ) ;
                next TILE ;
            }
            elsif( $shape eq 'star6' ) {
                $tile->[$x][$y][$TILE] = 
                    $canvas->create( 'polygon', 
                        $xpos,                   $ypos + $quarter,
                        $xpos + $third,          $ypos + $quarter,
                        $xpos + $half,           $ypos,
                        $xpos + $two_thirds,     $ypos + $quarter,
                        $Xpos,                   $ypos + $quarter,
                        $xpos + $three_quarters, $ypos + $half,
                        $Xpos,                   $ypos + $three_quarters,
                        $xpos + $two_thirds,     $ypos + $three_quarters,
                        $xpos + $half,           $Ypos,
                        $xpos + $third,          $ypos + $three_quarters,
                        $xpos,                   $ypos + $three_quarters,
                        $xpos + $quarter,        $ypos + $half,
                        -fill => $colour, -outline => $outline ) ;
                next TILE ;
            }
            elsif( $shape eq 'spiral1' or $shape eq 'spiral2' ) {
                # Not convinced its faster to precalculate since you'd have to
                # do it for every tile and would be doing a lot of memory
                # allocation.
                $smooth = int rand 2 if $random ;
                $tile->[$x][$y][$TILE] = 
                    $canvas->createLine( 
                        $xpos,      $ypos,
                        $Xpos,      $ypos,
                        $Xpos,      $Ypos,
                        $xpos +  3, $Ypos,
                        $xpos +  3, $ypos +  3,
                        $Xpos -  3, $ypos +  3,
                        $Xpos -  3, $Ypos -  3,
                        $xpos +  6, $Ypos -  3,
                        $xpos +  6, $ypos +  6,
                        $Xpos -  6, $ypos +  6,
                        $Xpos -  6, $Ypos -  6,
                        $xpos +  9, $Ypos -  6,
                        $xpos +  9, $ypos +  9,
                        $Xpos -  9, $ypos +  9,
                        $Xpos -  9, $Ypos -  9,
                        $xpos + 12, $Ypos -  9,
                        $xpos + 12, $ypos + 12,
                        $Xpos - 12, $ypos + 12,
                        $Xpos - 12, $Ypos - 12,
                        $xpos + 15, $Ypos - 12,
                        $xpos + 15, $ypos + 15,
                        $Xpos - 15, $ypos + 15,
                        $Xpos - 15, $Ypos - 15,
                        $xpos + 18, $Ypos - 15,
                        $xpos + 18, $ypos + 18,
                        $Xpos - 18, $ypos + 18,
                        -smooth => $smooth, 
                        -fill => $colour, -width => 2 ) ;
                next TILE ;
            }
        }
    }

    $canvas->scale( 'all', 0, 0, $scale, $scale ) ;
    $canvas->update ;
}


sub bind_keyboard {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $window = $self->get( -window ) ;

    local $_ ;

    foreach( qw( <Control-n> <Alt-n> <n> <Control-s> <Alt-s> <s> ) ) {
        $window->bind( $_, sub { $self->new_game } ) ;
    }

    foreach( qw( <Control-p> <Alt-p> <p> ) ) {
        $window->bind( $_, sub { $self->pause_resume } ) ; # Pause
    }

    foreach( qw( <Control-r> <Alt-r> <r> ) ) {
        $window->bind( $_, sub { $self->pause_resume } ) ; # Resume
    }

    foreach( qw( <Control-o> <Alt-o> <o> ) ) {
        $window->bind( $_, sub { $self->options } ) ;
    }

    foreach( qw( <Control-a> <Alt-a> <a> ) ) {
        $window->bind( $_, sub { $self->about } ) ;
    }

    foreach( qw( <Control-h> <Alt-h> <F1> ) ) {
        $window->bind( $_, sub { $self->help } ) ;
    }

    foreach( qw( <Control-q> <Alt-q> <q> ) ) {
        $window->bind( $_, $self->get( -quit ) ) ;
    }

    foreach( qw( <Up> <k> <f> ) ) {
        $window->bind( $_, sub { $self->move_up } ) ;
    }

    foreach( qw( <Down> <j> <b> ) ) {
        $window->bind( $_, sub { $self->move_down } ) ;
    }

    foreach( qw( <Left> <h> <d> ) ) {
        $window->bind( $_, sub { $self->move_left } ) ;
    }

    foreach( qw( <Right> <l> <g> ) ) {
        $window->bind( $_, sub { $self->move_right } ) ;
    }

    foreach( qw( <space> <Return> ) ) {
        $window->bind( $_, sub { $self->click } ) ;
    }

}


# Utility methods

sub centre {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $win = shift ;
    $win->update ;
    my $x = int( ( $win->screenwidth  - $win->width  ) / 2 ) ;
    my $y = int( ( $win->screenheight - $win->height ) / 2 ) ;
    $win->geometry( "+$x+$y" ) ;
}


sub get_rand_colour {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    die "is an object method" unless ref $self ;

    my $background = $self->get( -background ) ;

    while( 1 ) {
        my $red   = int( rand( 0xFF ) ) ;
        my $green = int( rand( 0xFF ) ) ;
        my $blue  = int( rand( 0xFF ) ) ;
    
        next if ( abs( $red   - $green ) < 16 and 
                  abs( $green - $blue  ) < 16 ) ; # Don't return grey

        my $colour = sprintf "#%02X%02X%02X", $red, $green, $blue ;

        return $colour unless 
        $self->similar_colour( $colour, $background ) ; # Don't return background
    }
}


sub similar_colour {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    die "is an object method" unless ref $self ;

    # We deem a colour to be similar if the difference in RGB values is <= 192
    # We do NOT check that the hex string is valid.

    my $colour = shift ;
    $colour =~ /^#(..)(..)(..)$/o ;
    my( $red, $green, $blue ) = ( hex( $1 ), hex( $2 ), hex( $3 ) ) ; 

    local $_ ;
    foreach ( @_ ) {
        /^#(..)(..)(..)$/o ;
        return 1 unless ( abs( $red   - hex( $1 ) ) +
                          abs( $green - hex( $2 ) ) +
                          abs( $blue  - hex( $3 ) ) ) > 192 ;
    }

    0 ;
}


sub valid_int {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my( $val, $def, $min, $max ) = @_ ;
    $val = int $val ;

    ( $val >= $min and $val <= $max ) ? $val : $def ;
}


sub valid_array_element {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $val   = lc shift ;
    my $def   = shift ;

    foreach my $element ( @_ ) {
        return $val if $val eq $element ;
    }

    $def ;
}


1 ;


