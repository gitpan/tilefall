package Tk::MesgBox ;    # Documented at the __END__.

# $Id: MesgBox.pm,v 1.9 1999/12/13 19:44:31 root Exp $

require 5.004 ;

use strict ;

use Tk ;
use Carp ;

require Tk::Toplevel ;

use vars qw( $VERSION @ISA ) ;

$VERSION = '1.10' ;

@ISA = qw( Tk::Toplevel ) ;

Construct Tk::Widget 'MesgBox' ;

#############################
sub Populate {
    my( $win, $args ) = @_ ;

    my %arg = (
        -title     => 'Message',
        -text      => 'Press OK to continue.',
        -icon      => undef,
        -defbutton => 'OK',    
        -canbutton => '', # Usually 'Cancel'.
        -buttons   => [ 'OK' ],
        -aspect    => 500,
        -justify   => 'center',
        -bindctrl  => 1,
        -bindalt   => 1,
        -bindord   => 1,
        %$args, 
        ) ;

    # We don't delete the title.
    delete $args->{-text} ;
    delete $args->{-icon} ;
    delete $args->{-defbutton} ;
    delete $args->{-canbutton} ;
    delete $args->{-buttons} ;
    delete $args->{-aspect} ;
    delete $args->{-justify} ;
    delete $args->{-bindctrl} ;
    delete $args->{-bindalt} ;
    delete $args->{-bindord} ;

    $win->SUPER::Populate( $args ) ;

    $win->withdraw ;
    $win->iconname( $arg{-title} ) ;
    $win->protocol( 'WM_DELETE_WINDOW' => sub { } ) ;
    $win->transient( $win->toplevel ) ;

    $win->{-default_button}  = &create_buttons( $win, %arg ) ;
    &create_text_frame( $win, %arg ) ;

    $win->{-selected_button} = '' ;
}

#############################
sub Show {
    my $win = shift ;

    $win->Popup() ; 

    if( defined $win->{-default_button} ) {
        $win->{-default_button}->focus ;
    } 
    else {
      $win->focus ;
    }

    $win->waitVariable( \$win->{-selected_button} ) ;
    $win->withdraw ;

    $win->{-selected_button} ;
}

#############################
sub create_buttons {
    my $win = shift ;
    my %arg = @_ ;

    my $defbutton = undef ;

    my $ButtonFrame = $win->Frame(
                        )->pack( -padx => 5, -pady => 5, -side => 'bottom' ) ;

    foreach my $button ( @{$arg{-buttons}} ) {
        next unless $button ; 
        my $Button = $ButtonFrame->Button(
            -text      => $button,
            -underline => 0,
            -width     => 8,
            -command   => [ \&msg_close, $win, $button ],
            )->pack( -side => 'left' ) ;
        $defbutton = $Button if $button eq $arg{-defbutton} ;
     }

    &set_key_bindings( $win, %arg ) ;

    $defbutton ;
}

#############################
sub set_key_bindings {
    my $win = shift ;
    my %arg = @_ ;

    foreach my $button ( @{$arg{-buttons}} ) {
        next unless $button ; 
        my $char = lc substr( $button, 0, 1 ) ;
        $win->bind( "<Control-${char}>", [ \&msg_close, $win, $button ] ) 
        if $arg{-bindctrl} ;
        $win->bind( "<Alt-${char}>",     [ \&msg_close, $win, $button ] )
        if $arg{-bindalt} ;
        $win->bind( "<${char}>",         [ \&msg_close, $win, $button ] )
        if $arg{-bindord} ;
        $win->bind( "<Return>",          [ \&msg_close, $win, $button ] ) 
        if $button eq 'OK' ;
        $win->bind( "<Escape>",          [ \&msg_close, $win, $button ] ) 
        if $button eq 'Cancel' ;
    }

    $win->bind( '<Return>', [ \&msg_close, $win, $arg{-defbutton} ] ) 
    if $arg{-defbutton} ; 

    $win->bind( '<Escape>', [ \&msg_close, $win, $arg{-canbutton} ] ) 
    if $arg{-canbutton} ; 
}

#############################
sub create_text_frame {
    my $win = shift ;
    my %arg = @_ ;

    my $Frame ;

    if( $arg{-icon} ) {
        my $Frame = $win->Frame()->pack( -side => 'left', ) ;
        &set_icon( $arg{-icon}, $Frame ) if $arg{-icon} ;
    }

    $Frame = $win->Frame(
                )->pack( -fill => 'x', -expand => 'y' ) ;

    $Frame->Message( 
        -text    => $arg{-text},
        -justify => $arg{-justify},
        -aspect  => $arg{-aspect},
        )->pack( -padx => 5, -pady => 5, -fill => 'x', ) ;
}

#############################
sub set_icon {
    my $icon  = shift ;
    my $frame = shift ;

    my( $text, $colour ) ;

    CASE : {
        if( $icon eq 'INFO' ) {
            $text   = 'i' ;
            $colour = 'black' ;
            last CASE ;
        }
        if( $icon eq 'ERROR' ) {
            $text   = 'E' ;
            $colour = 'darkred' ;
            last CASE ;
        }
        if( $icon eq 'WARNING' ) {
            $text   = '!' ;
            $colour = 'blue' ;
            last CASE ;
        }
        if( $icon eq 'QUESTION' ) {
            $text   = '?' ;
            $colour = 'darkgreen' ;
            last CASE ;
        }
        if( $icon eq 'info'    or $icon eq 'error' or 
            $icon eq 'warning' or $icon eq 'question' ) {
            # Need do nothing.
            last CASE ;
        }
        DEFAULT : {
            return ;
        }
    }
    if( defined $text ) {
        $frame->Label( 
            -text => " $text", 
            -font => '-*-times-bold-r-*-*-40-*-*-*-*-*-*-*',
            -fg   => $colour,
            )->pack() ;
    }
    else {
        $frame->Label( -bitmap => $icon )->pack( -padx => 10, -pady => 10 ) ;
    }
}

#############################
sub msg_close {
    # This strange hack is necessary because the first parameter is a
    # reference of type Button, the second of type MesgBox, even though the
    # $win variable which is passed down the application is *always* the
    # MesgBox! I don't know if this is due to a bug in the Tk
    # implementation since I've noticed unwanted object references being
    # passed in at other times in other routines - or if its due to me
    # misunderstanding.
    my $win ;
    while( ref $_[0] ) {
        $win = shift ;
        last if ref $win =~ /MesgBox/o ;
    }
    my $button = shift ;

    $win->{-selected_button} = $button ;
}

1 ;

__END__

=head1 NAME

MesgBox - Perl/Tk module for message and button dialogue boxes.

=head1 SYNOPSIS

    use MesgBox ; 

    # Example 1: an 'OK' box.
    # Pressing <Space>, <Return>, <o>, <Control-o> or <Alt-o> will close the box.

    my $msg = $Window->MesgBox( -title => 'Test', -text => 'Test Complete.' ) ;
    $msg->Show ;

    # Example 2: a 'Yes/No' box.
    # Pressing <Space>, <Return>, <y>, <Control-y> or <Alt-y> 
    # presses the 'Yes' button;
    # pressing <n>, <Control-n> or <Alt-n> presses the 'No' button.

    my $msg = $Window->MesgBox(
        -title     => 'Save File?',
        -text      => "Save '$filename'?",
        -icon      => 'QUESTION',
        -buttons   => [ 'Yes', 'No' ],
        -defbutton => 'Yes',
        ) ;
    my $ans = $msg->Show ;
    &save_file if $ans eq 'Yes' ;

    # Example 3: an 'OK/Cancel' box.
    # Pressing <Space>, <Return>, <o>, <Control-o> or <Alt-o> presses the 'OK'
    # button;
    # pressing <Escape>, <c>, <Control-c> or <Alt-c> presses the 'Cancel'
    # button.

    my $msg = $Window->MesgBox(
        -title   => 'Print',
        -text    => 'Print the page',
        -buttons => [ 'OK', 'Cancel' ],
        ) ;
    my $ans = $msg->Show ;
    &print if $ans eq 'OK' ;

=head1 DESCRIPTION

This message box is similar to the MsgBox function provided with Windows. It
provides a message text with an optional 'icon' and any buttons required. It
is not as versatile as the Dialog box supplied with Tk but is simpler, and
it provides automatic keyboard bindings.

All options are optional, although defining a C<-title> and C<-text> is
only sensible. Leaving out everything else will provide a simple OK button.

The keyboard is bound such that the first letter of each button is bound both
as a letter alone and in conjunction with both Control and Alt. This letter is
also displayed underlined. It is recommended that each button's text begins
with a unique letter. Any button with the text 'OK' will be the default button
responding to <Return>, unless overridden by the C<-defbutton> option. Any
button with the text 'Cancel' will be the default cancel button responding to
<Escape> unless overridden by the C<-canbutton> option.

C<-title> is the text which appears in the title bar.

C<-text> is the text which appears in the body of the message. It may include
newlines which are respected, but it will wrap.

C<-icon> is the 'icon' which appears to the left of the message. It may be one
of Tk's standard bitmaps: info 'i', error '(\)', warning '!', question '?'; or
one of the MesgBox versions: INFO 'i', ERROR 'E', WARNING '!', QUESTION '?'. It
may be undefined meaning no image appears.

C<-defbutton> is the default button. It defaults to the 'OK' button if there
is one. The default button is the button 'pressed' when the user presses
<Return>.

C<-canbutton> is the cancel button. It defaults to the 'Cancel' button if there
is one. The cancel button is the button 'pressed' when the user presses
<Escape>.

C<-buttons> is an array of button captions. By default it is set to a list
consisting of one element, 'OK'. You may use any text, e.g. 'OK', 'Cancel',
'Yes', 'Retry', etc. You may have as many buttons as you like - although too
many might not fit on the screen...

C<-aspect> is the ratio of width to height. Generally increase this past the
default of 200, say to 300, 400 or 500 to make the message box wider and
shorter.

C<-justify> sets the justification for the C<-text> - may be 'center', 'left'
or 'right'. Defaults to 'center'.

C<-bindctrl> sets the keyboard bindings to include <Control-$letter>, defaults
to true.

C<-bindalt> sets the keyboard bindings to include <Alt-$letter>, defaults
to true.

C<-bindord> sets the keyboard bindings to include <$letter>, defaults
to true.

=head1 INSTALLATION

MesgBox.pm should be placed in any Tk directory in any lib directory in
Perl's %INC path, for example, '/usr/lib/perl5/Tk'.

=head1 BUGS

MesgBox does almost no error checking.

=head1 CHANGES

1999/01/18  First public release.

1999/01/22  Minor documentation changes.

1999/01/23  Tidied up set_icon.

1999/02/23  Should now be Windows compatible.

1999/08/05  Just changed the files to make them more CPAN friendly.

1999/08/08  Changed licence to LGPL.

1999/09/06  Minor change to packaging for CPAN.

1999/10/01  Changed the Show() method so that it is now compatible with
            Tk800.015 as well as earlier Tk800 versions.

=head1 AUTHOR

Mark Summerfield. I can be contacted as <summer@perlpress.com> -
please include the word 'mesgbox' in the subject line.

The code draws very heavily from Stephen O. Lidie's Dialog.pm module.

=head1 COPYRIGHT

Copyright (c) Mark Summerfield 1999. All Rights Reserved.

This module may be used/distributed/modified under the LGPL. 

=cut

