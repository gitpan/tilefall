package TileFall ;

use strict ;

# $Id: TileFall.pm,v 1.10 2000/04/23 18:59:00 root Exp $

# Copyright (c) Mark Summerfield 2000. All Rights Reserved.
# May be used/distributed under the GPL.

use Carp qw( croak ) ;
use GameBoard ;
use Symbol () ;
use Tk::MesgBox ;

use vars qw( @ISA ) ;

@ISA = qw( GameBoard ) ;

use readonly
        '$MIN_HEIGHT'       =>    5,
        '$DEF_HEIGHT'       =>    8,
        '$MAX_HEIGHT'       =>   60,
        '$MIN_WIDTH'        =>    5,
        '$DEF_WIDTH'        =>   12,
        '$MAX_WIDTH'        =>   60,
        '$MIN_SCALE'        =>   20,
        '$DEF_SCALE'        =>  100,
        '$MAX_SCALE'        =>  200,
        '$MIN_COLOURS'      =>    2,
        '$DEF_COLOURS'      =>    3,
        '$MAX_COLOURS'      =>    9,
        '$MIN_DELAY'        =>    0,
        '$DEF_DELAY'        =>  200, 
        '$MAX_DELAY'        => 1000, 
        '$DEF_BEEP'         =>    1,
        '$DEF_SHAPE'        => 'octagon',
        '$DEF_CHANGE_SHAPE' => 'every game',
        '$SHAPES'           => 'every game:every click:never',
        '$BUTTON_WIDTH'     =>   10,
        '$WIN_FILE'         => 'TILEFALL.INI',
        '$LINUX_FILE'       => '/.games/tilefallrc',
        '$DEF_HISCORE'      => 3333,
        '$OPTIONS'          => 
            'height:width:scale:maxcolours:beep:shape:hiscore:delay:changeshape', 
        ;

my( $Opt_height, $Opt_width, $Opt_scale, $Opt_maxcolours, $Opt_delay, 
    $Opt_beep, $Opt_shape, $Opt_changeshape ) ;

my( $Orig_shape, $Orig_scale ) ;

my %Shape = (
        circle   => 'oval',
        square   => 'rectangle',
        triangle => 'triangle',
        hexagon  => 'hexagon',
        star5    => 'star5',
        star6    => 'star6',
        octagon  => 'octagon',
        heart    => 'heart',
        ) ;

my %UnShape = reverse %Shape ;


sub new_game { 
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $window = $self->get( -window ) ;
    $window->configure( -cursor => 'watch' ) ;
    $self->set( -status_display, 'Drawing...' ) ;
    $self->set( -score_display, 0 ) ;

    my @colour ;

    while( scalar @colour < $self->get( -maxcolours ) ) {
        my $colour = $self->get_rand_colour ;
        push @colour, $colour 
        unless $self->similar_colour( $colour, @colour ) ;
    }

    my $tiles  = $self->get( -tiles ) ;

    my $height = $self->get( -height ) ;
    for( my $x = 0 ; $x < $self->get( -width ) ; $x++ ) {
        for( my $y = 0 ; $y < $height ; $y++ ) {
            $tiles->[$x][$y][$GameBoard::COLOUR] = $colour[int rand scalar @colour] ; 
        }
    }

    $self->set( -shape, ( values %Shape )[rand scalar keys %Shape] ) 
    if $self->get( -changeshape ) eq 'every game' ;

    $self->draw ;
    $self->centre( $window ) ;
    $self->set( -status_display, 'Running' ) ;
    $window->configure( -cursor => 'left_ptr' ) ;
}


sub beep {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    $self->get( -window )->bell if $self->get( -beep ) ;
}


sub click {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my( $x, $y ) = @_ ;

    $self->set( -status_display, '' ) ; 

    my $window = $self->get( -window ) ;
    my $tiles  = $self->get( -tiles ) ;
    my $colour = $self->get( -tile, $x, $y ) ;
    my $xmax   = $self->get( -width )  - 1 ;
    my $ymax   = $self->get( -height ) - 1 ;

    # 1. Is the move legal (adjoining tile of same colour and not background?)
    unless( $self->legal( $x, $y, $colour, $xmax, $ymax ) ) {
        $self->set( -status_display, 'Illegal!' ) ;
        $self->beep ;
        return ;
    }

    $window->configure( -cursor => 'watch' ) ;

    # 2. Note all the tiles that must be removed.
    my @list ;
    $self->adjoining( $x, $y, $colour, $xmax, $ymax, \@list ) ;

    # 3. Remove the tiles.
    my $background = $self->get( -background ) ;
    my $points = 0 ; 
    for( my $x = 0 ; $x <= $xmax ; $x++ ) {
        for( my $y = 0 ; $y <= $ymax ; $y++ ) {
            if( defined $list[$x][$y] ) {
                $points++ ;
                $self->set( -tile, $x, $y, $background ) ;
            }
        }
    }

    # Show points gained immediately
    $points = ( $points - 2 ) ** 2 ;
    $self->set( -status_display, $points ) ; 
    $self->set( -score_display, $self->get( -score_display ) + $points ) ;

    # 4. Pause for a time proportional to tiles removed.
    $window->update ;
    $window->after( $self->get( -delay ) ) ; 

    # 5. Column by column drop any tiles that need dropping.
    $self->drop_tiles( $xmax, $ymax, $background ) ;

    $window->update ;
    $window->after( $self->get( -delay ) ) ;

    # 6. Row by row (right to left) move columns left where necessary.
    $self->move_columns( $xmax, $ymax, $background ) ;

    # 7. Is the game over?
    #    7.a) No tiles left (user gets bonus); or
    my $gameover ;
    $gameover = $self->get( -tile, 0, $ymax ) eq $background ;
    if( $gameover ) {
        my $bonus = $self->get( -width )  * 
                    $self->get( -height ) *  
                    ( $self->get( -maxcolours ) ** 2 ) ;
        $self->set( -status_display, $points + $bonus ) ; 
        $self->set( -score_display, $self->get( -score_display ) + $bonus ) ;
    }

    #    7.b) No pair of adjoining tile left
    $gameover = not $self->find_pair( $xmax, $ymax, $background ) unless $gameover ;

    if( $gameover ) {
        $self->set( -status_display, 'Game Over' ) ;
        $self->beep ; 
        my $score   = $self->get( -score_display ) ;
        my $hiscore = $self->get( -hiscore_display ) ;
        if( $score > $hiscore ) {
            $self->set( -hiscore, $score ) ;
            $self->set( -hiscore_display, $score ) ;
        }
    }
    elsif( $self->get( -changeshape ) eq 'every click' ) {
        $self->set( -shape, ( values %Shape )[rand scalar keys %Shape] ) ;
        $self->draw ;
    }

    $window->configure( -cursor => 'left_ptr' ) ;
}


sub legal {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my( $x, $y, $colour, $xmax, $ymax ) = @_ ;

    return 0 if $colour eq $self->get( -background ) ;

    return 1 if $x > 0     and $self->get( -tile,  $x - 1, $y ) eq $colour ;
    return 1 if $x < $xmax and $self->get( -tile,  $x + 1, $y ) eq $colour ;
    return 1 if $y > 0     and $self->get( -tile,  $x, $y - 1 ) eq $colour ;
    return 1 if $y < $ymax and $self->get( -tile,  $x, $y + 1 ) eq $colour ;

    0 ;
}


sub adjoining {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my( $x, $y, $colour, $xmax, $ymax, $list ) = @_ ;

    return if $x < 0 or $y < 0 or $x > $xmax or $y > $ymax ;
    return if $self->get( -tile, $x, $y ) ne $colour ;
    return if defined $list->[$x][$y] ;

    $list->[$x][$y] = $self->get( -tileref, $x, $y ) ;

    $self->adjoining( $x - 1, $y, $colour, $xmax, $ymax, $list ) ;
    $self->adjoining( $x + 1, $y, $colour, $xmax, $ymax, $list ) ;
    $self->adjoining( $x, $y - 1, $colour, $xmax, $ymax, $list ) ;
    $self->adjoining( $x, $y + 1, $colour, $xmax, $ymax, $list ) ;
}


sub drop_tiles {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my( $xmax, $ymax, $background ) = @_ ;

    for( my $x = 0 ; $x <= $xmax ; $x++ ) {
        for( my $y = $ymax ; $y > 0 ; $y-- ) {
            if( $self->get( -tile, $x, $y ) eq $background ) {
                # Swap with first non-background one above if any
                my $found = -1 ;
                for( my $sy = $y - 1 ; $sy >= 0 ; $sy-- ) {
                    $found = $sy, last 
                    if $self->get( -tile, $x, $sy ) ne $background ; 
                }
                if( $found > -1 ) {
                    $self->set( -tile, $x, $y, $self->get( -tile, $x, $found ) ) ;
                    $self->set( -tile, $x, $found, $background ) ;
                }
            }
        }
    }
}


sub move_columns {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my( $xmax, $ymax, $background ) = @_ ;

    for( my $x = 0 ; $x <= $xmax ; $x++ ) {
        if( $self->get( -tile, $x, $ymax ) eq $background ) {
            # Empty column must be moved left by swapping with first non-empty
            # column if any
            my $found = -1 ;
            for( my $sx = $x + 1 ; $sx <= $xmax ; $sx++ ) {
                $found = $sx, last
                if $self->get( -tile, $sx, $ymax ) ne $background ;
            }
            if( $found > -1 ) {
                for( my $sy = 0 ; $sy <= $ymax ; $sy++ ) {
                    $self->set( -tile, $x, $sy, 
                        $self->get( -tile, $found, $sy ) ) ;
                    $self->set( -tile, $found, $sy, $background ) ;
                }
            }
        }
    }
}


sub find_pair {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    # If we can find ANY pair then game on!

    my( $xmax, $ymax, $background ) = @_ ;

    COLUMN:
    for( my $x = 0 ; $x <= $xmax ; $x++ ) {
        for( my $y = $ymax ; $y >= 0 ; $y-- ) {
            my $colour = $self->get( -tile, $x, $y ) ;
            next COLUMN if $colour eq $background ;
            return 1 if $x > 0     and $self->get( -tile,  $x - 1, $y ) eq $colour ;
            return 1 if $x < $xmax and $self->get( -tile,  $x + 1, $y ) eq $colour ;
            return 1 if $y > 0     and $self->get( -tile,  $x, $y - 1 ) eq $colour ;
            return 1 if $y < $ymax and $self->get( -tile,  $x, $y + 1 ) eq $colour ;
        }
    }

    0 ;
}

 
sub about {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;
   
    my $text = <<EOT ;
TileFall v $::VERSION

www.perlpress.com

Copyright (c) Mark Summerfield 2000. 
All Rights Reserved.

May be used/distributed under the GPL.

This game is based on TileFall which was originally written 
for the Amiga and Psion by Adam Dawes
www.electrolyte.demon.co.uk
EOT

    my $msg = $self->get( -window )->
                MesgBox( 
                    -title => 'About TileFall',
                    -text  => $text,
                    ) ;
    $msg->Show ;
}


sub help {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;
   
    my $text = <<EOT ;
The aim of the game is to remove as many tiles as possible.
This is achieved by clicking tiles. When a tile is clicked 
any vertically or horizontally adjoining tiles of the same
colour are also removed.

The more tiles removed in one go the more points you score:
  Tiles = Points
2 = 0
3 = 1
4 = 4
5 = 9
 6 = 16
:
10 = 64
and so on.
If you clear the board you also get a bonus proportional 
to the board size times the number of colours.

TileFall v $::VERSION

www.perlpress.com

Copyright (c) Mark Summerfield 2000. 
All Rights Reserved.

May be used/distributed under the GPL.

This game is based on TileFall which was originally written 
for the Amiga and Psion by Adam Dawes
www.electrolyte.demon.co.uk
EOT

    my $msg = $self->get( -window )->
                MesgBox( 
                    -title => 'TileFall Help',
                    -text  => $text,
                    ) ;
    $msg->Show ;
}


sub options {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $win = $self->get( -window )->Toplevel() ;
    $self->set( -optionswin, $win ) ;
    $win->title( 'TileFall Options' ) ;
    $win->protocol( "WM_DELETE_WINDOW", sub { $self->options_close( 0 ) } ) ;

    $self->options_init_keyboard ;

    my $widget ;
    my $frame ;
    my $row = 0 ;

    $widget = $self->options_create_scale( 
                $MIN_HEIGHT, $MAX_HEIGHT, 5, 'Height (tiles)', $row, 0 ) ;
    $Opt_height = $self->get( -height ) ;
    $widget->configure( -variable => \$Opt_height ) ;
    $row += 3 ;

    $widget = $self->options_create_scale( 
                $MIN_WIDTH, $MAX_WIDTH, 5, 'Width (tiles)', $row, 0 ) ;
    $Opt_width = $self->get( -width ) ;
    $widget->configure( -variable => \$Opt_width ) ;
    $row += 3 ;

    $widget = $self->options_create_scale( 
                $MIN_SCALE, $MAX_SCALE, 20, 'Scale (%)', $row, 0 ) ;
    $Orig_scale = $Opt_scale = $self->get( -scale ) * 100 ;
    $widget->configure( 
        -variable => \$Opt_scale,
        -command  => sub { 
            $Opt_scale = $DEF_SCALE unless $Opt_scale ; # Paranoia
            $self->set( -scale, $Opt_scale / 100 ) ; 
            $self->draw 
            } ) ;
    $row += 3 ;

    $widget = $self->options_create_scale( 
                $MIN_DELAY, $MAX_DELAY, 200, 'Delay (millisecs)', $row, 0 ) ;
    $Opt_delay = $self->get( -delay ) ;
    $widget->configure( -variable => \$Opt_delay ) ;

    $row = 0 ;

    $widget = $self->options_create_scale( 
                $MIN_COLOURS, $MAX_COLOURS, 1, 'Colours', $row, 3 ) ;
    $Opt_maxcolours = $self->get( -maxcolours ) ;
    $widget->configure( -variable => \$Opt_maxcolours ) ;
    $row += 3 ;

    $Opt_beep = $self->get( '-beep' ) ;
    $win->Checkbutton(
        -text => 'Beep', -variable => \$Opt_beep, 
        -relief => 'ridge', -borderwidth => 2,
        )->grid( -row => $row++, -column => 3, 
                 -columnspan => 3, -sticky => 'nsew' ) ;

    my $col = 0 ;
    $Opt_changeshape = $self->get( '-changeshape' ) ;
    $frame = $win->Frame( -relief => 'ridge', -borderwidth => 2 )->
                grid( -row => $row, -column => 3, 
                      -rowspan => 2, -columnspan => 3, -sticky => 'nsew' ) ;
    $row += 2 ;
    $frame->Label( -text => 'Change shape' )->
        grid( -row => 0, -column => 0, -columnspan => 3, -sticky => 'w' ) ;
    foreach my $option ( split /:/, $SHAPES ) {
        $frame->Radiobutton(
            -text => $option, -value => $option, -variable => \$Opt_changeshape, )->
            grid( -row => 1, -column => $col++, -sticky => 'w' ) ;
    }

    $Orig_shape = $Opt_shape = $UnShape{$self->get( -shape )} ;
    $col = 0 ;
    $frame = $win->Frame( -relief => 'ridge', -borderwidth => 2 )->
                grid( -row => $row, -column => 3, 
                      -rowspan => 2, -columnspan => 3, -sticky => 'nsew' ) ;
    $row += 2 ;
    $frame->Label( -text => 'Shape (if change shape is never)' )->
        grid( -row => 0, -column => 0, -columnspan => 3, -sticky => 'w' ) ;
    foreach my $shape ( sort keys %Shape ) {
        $frame->Radiobutton( 
            -text => $shape, -value => $shape, -variable => \$Opt_shape,
            -command => sub { 
                ( $Opt_shape ) = each %Shape unless $Opt_shape ; # Paranoia
                $self->set( -shape, $Shape{$Opt_shape} ) ; 
                $self->draw 
                } )->
            grid( -row => $row, -column => $col, -columnspan => 1, -sticky => 'w' ) ;
        $col++ ;
        $row++, $col = 0 if $col == 4 ;
    }

    $frame = $win->Frame()->
                grid( -row => $row, -column => 3, -columnspan => 3 ) ;

    $frame->Button(
        -text      => 'Save',
        -underline => 0,
        -width     => $BUTTON_WIDTH,
        -command   => sub { $self->options_close( 1 ) },
        )->grid( -row => 0, -column => 0, -sticky => 'w' ) ;

    $frame->Button(
        -text      => 'Cancel',
        -underline => 0,
        -width     => $BUTTON_WIDTH,
        -command   => sub { $self->options_close( 0 ) },
        )->grid( -row => 0, -column => 1, -sticky => 'w' ) ;

    $frame->Button(
        -text      => 'Defaults',
        -underline => 0,
        -width     => $BUTTON_WIDTH,
        -command   => sub { $self->options_defaults },
        )->grid( -row => 0, -column => 2, -sticky => 'w' ) ;
}


sub options_init_keyboard {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $win = $self->get( -optionswin ) ;
    local $_ ;

    # Cancel keyboard bindings.
    foreach( qw( <Alt-c> <Control-c> <Escape> ) ) {
        $win->bind( $_, sub { $self->options_close( 0 ) } ) ;
    }

    # Save keyboard bindings.
    foreach( qw( <Alt-s> <Control-s> <Return> ) ) {
        $win->bind( $_, sub { $self->options_close( 1 ) } ) ;
    }

    # Defaults keyboard bindings.
    foreach( qw( <Alt-d> <Control-d> ) ) {
        $win->bind( $_, sub { $self->options_defaults } ) ;
    }
}


sub options_create_scale {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $win = $self->get( -optionswin ) ;

    my( $min, $max, $interval, $title, $row, $col ) = @_ ;

    my $scale = $win->Scale(
        -orient       => 'horizontal',
        -from         => $min,
        -to           => $max,
        -tickinterval => $interval,
        -label        => $title,
        '-length'     => 290,
        -borderwidth  =>   2,
        -relief       => 'ridge',
        )->grid( -row => $row, -column => $col, -rowspan => 3, -columnspan => 3 ) ;

    $scale ;
}


sub options_close {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $win  = $self->get( -optionswin ) ;
    my $save = shift ;

    $win->configure( -cursor => 'watch' ) ;

    if( $save ) {
        my $new_game = 
            ( $Opt_height     != $self->get( -height ) or
              $Opt_width      != $self->get( -width )  or
              $Opt_maxcolours != $self->get( -maxcolours ) ) ;

        my $redraw = ( ( $Opt_scale != $self->get( -scale ) * 100 ) or
                       ( $Shape{$Opt_shape} ne $self->get( -shape ) ) ) ;

        $self->set( -height,      $Opt_height ) ;
        $self->set( -width,       $Opt_width ) ;
        $self->set( -scale,       $Opt_scale / 100 ) ;
        $self->set( -maxcolours,  $Opt_maxcolours ) ;
        $self->set( -delay,       $Opt_delay ) ;
        $self->set( '-beep',      $Opt_beep ) ;
        $self->set( -shape,       $Shape{$Opt_shape} ) ;
        $self->set( -changeshape, $Opt_changeshape ) ;

        if( $new_game ) {
            $self->new_game ;
        }
        elsif( $redraw ) {
            $self->draw ;
        }

        $self->centre( $self->get( -window ) ) if $new_game or $redraw ;
        $self->write_options ;
    }

    $win->configure( -cursor => 'left_ptr' ) ;
    $win->destroy ;
}


sub options_defaults {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    $Opt_height      = $DEF_HEIGHT ;
    $Opt_width       = $DEF_WIDTH ;
    $Opt_scale       = $DEF_SCALE ;
    $Opt_maxcolours  = $DEF_COLOURS ;
    $Opt_delay       = $DEF_DELAY ;
    $Opt_beep        = $DEF_BEEP ;
    $Opt_shape       = $DEF_SHAPE ;
    $Opt_changeshape = $DEF_CHANGE_SHAPE ;

    my $redraw = ( ( $Opt_scale != $self->get( -scale ) * 100 ) or
                   ( $Shape{$Opt_shape} ne $self->get( -shape ) ) ) ;

    $self->set( -shape, $Shape{$Opt_shape} ) ;
    $self->set( -scale, $Opt_scale / 100 ) ;

    $self->draw if $redraw ;
}


sub get_filename {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $file ;

    if( $^O =~ /[Ww][Ii][Nn]32/o ) {
        $file = $WIN_FILE ;
    }
    else {
        $file = ( $ENV{HOME} or $ENV{LOGDIR} or (getpwuid( $> ))[7]) . 
               $LINUX_FILE ;
    }

    $file ;
}


sub write_options {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    my $file = $self->get_filename ;

    eval {
        $file =~ m{^(.*)/} ;
        if( defined $1 and not -e $1 ) { 
            die "Failed to create directory `$1' for options file: $!\n"
            unless mkdir $1, 0666 ;
        }

        my $fh = Symbol::gensym ;
        open $fh, ">$file" or die "Failed to write options file `$file': $!\n" ;
        foreach my $opt ( sort split /:/, $OPTIONS ) {
            my $val = $self->get( "-$opt" ) ;
            $val = 0 unless $val ;
            $val *= 100           if $opt eq 'scale' ;
            $val = $UnShape{$val} if $opt eq 'shape' ;
            print $fh "$opt: $val\n" ;
        }
        close $fh or die "Failed to close options file `$file': $!\n" ;
    } ;
    if( $@ ) {
        my $msg = $self->get( -window )->
                    MesgBox( 
                        -title => 'TileFall Error',
                        -icon  => 'error',
                        -text  => $@,
                        ) ;
        $msg->Show ;
    }
}


sub read_options {
    my $self  = shift ;
    my $class = ref( $self ) || $self ;

    croak "is an object method" unless ref $self ;

    unless( $self->get( -hiscore ) ) {
        $self->set( -hiscore, $DEF_HISCORE ) ;
        $self->set( -hiscore_display, $DEF_HISCORE ) ;
    }

    my $file   = $self->get_filename ;
    my $window = $self->get( -window ) ;

    $self->set( -changeshape, $DEF_CHANGE_SHAPE ) 
    unless $self->get( -changeshape ) ;

    eval {
        local $_ ;
        my $msg ;
        my $fh = Symbol::gensym ;
        open $fh, $file or die "Failed to open options file `$file': $!\n" ;
        while( <$fh> ) {
            chomp ;
            my( $key, $val ) = split /\s*:\s*/, $_, 2 ;
            my $warning ;
            if( index( $OPTIONS, $key ) > -1 ) {
                CASE : {
                    if( $key eq 'height' ) {
                        $val = int( $val ) ;
                        if( $val >= $MIN_HEIGHT and $val <= $MAX_HEIGHT ) { 
                            $self->set( -height, $val ) ;
                        }
                        else {
                            $warning = "Invalid height `$val'" ;
                        }
                        last CASE ;
                    }
                    if( $key eq 'width' ) {
                        $val = int( $val ) ;
                        if( $val >= $MIN_WIDTH and $val <= $MAX_WIDTH ) {
                            $self->set( -width, $val ) ;
                        }
                        else {
                            $warning = "Invalid width `$val'" ;
                        }
                        last CASE ;
                    }
                    if( $key eq 'scale' ) {
                        $val = int( $val ) ;
                        if( $val >= $MIN_SCALE and $val <= $MAX_SCALE ) {
                            $self->set( -scale, $val / 100 ) ;
                        }
                        else {
                            $warning = "Invalid scale `$val'" ;
                        }
                        last CASE ;
                    }
                    if( $key eq 'maxcolours' ) {
                        $val = int( $val ) ;
                        if( $val >= $MIN_COLOURS and $val <= $MAX_COLOURS ) {
                            $self->set( -maxcolours, $val ) ;
                        }
                        else {
                            $warning = "Invalid maxcolours `$val'" ;
                        }
                        last CASE ;
                    }
                    if( $key eq 'delay' ) {
                        $val = int( $val ) ;
                        if( $val >= $MIN_DELAY and $val <= $MAX_DELAY ) {
                            $self->set( -delay, $val ) ;
                        }
                        else {
                            $warning = "Invalid delay `$val'" ;
                        }
                        last CASE ;
                    }
                    if( $key eq 'beep' ) {
                        $self->set( '-beep', $val =~ /^[TtYy1]/o ) ;
                        last CASE ;
                    }
                    if( $key eq 'changeshape' ) {
                        $val = lc $val ;
                        if( index( $SHAPES, $val ) > -1 ) {
                            $self->set( -changeshape, $val ) ;
                        }
                        else {
                            $warning = "Invalid changeshape `$val'" ;
                        }
                        last CASE ;
                    }
                    if( $key eq 'shape' ) {
                        $val = lc $val ;
                        if( exists $Shape{$val} ) {
                            $self->set( -shape, $Shape{$val} ) ;
                        }
                        else {
                            $warning = "Invalid shape `$val'" ;
                        }
                        last CASE ;
                    }
                    if( $key eq 'hiscore' ) {
                        $self->set( -hiscore, int( $val ) ) ;
                        $self->set( -hiscore_display, int( $val ) ) ;
                        last CASE ;
                    }
                }
            }
            else {
                $warning = "Invalid key `$key'" ;
            }
            if( defined $warning ) {
                $msg = $window->MesgBox(
                        -title => 'TileFall Error',
                        -text  => $warning,
                        -icon  => 'error',
                        ) ;
                $msg->Show ;
            }
        }
        close $fh or die "Failed to close options file `$file': $!\n" ;
    } ;
    if( $@ ) {
        return if $@ =~ /No such file or directory/o ; 
        my $msg = $window->MesgBox( 
                        -title => 'TileFall Error',
                        -text  => $@,
                        ) ;
        $msg->Show ;
    }
}


# Game isn't time driven so we have new instead of start + pause/resume
sub pause_resume { ; }

# Game is mouse driven so we ignore keyboard movements.
sub move_up      { ; }
sub move_down    { ; }
sub move_left    { ; }
sub move_right   { ; }


1 ;

__END__
