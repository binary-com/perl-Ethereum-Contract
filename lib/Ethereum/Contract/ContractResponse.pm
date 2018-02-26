package Ethereum::Contract::ContractResponse;

use strict;
use warnings;
use Moose;
use Encode;
use Math::BigInt;

has response => ( is => 'ro' );
has error    => ( is => 'ro' );

=head2 to_big_int

Convert response to a Math::BigInt if not undef

Parameters: 
    hexadecimal response
    
Return:
    new Math::BigInt

=cut

sub to_big_int {
    my $self = shift;
    return Math::BigInt->from_hex($self->response) if $self->response;
}

=head2 to_string

Convert response to a string if not undef

Parameters: 
    hexadecimal response
    
Return:
    string

=cut

sub to_string {
    my $self = shift;
    
    return undef unless $self->response;
    
    my $packed_response = pack('H*', substr($self->response, -64));
    $packed_response =~ s/\0+$//;
    
    return $packed_response;
}

=head2 to_hex

Convert response to a hexadecimal if not undef and is not already a hex

Parameters: 
    hexadecimal response
    
Return:
    hexadecimal string

=cut

sub to_hex {
    my $self = shift;
    
    return undef unless $self->response;
    
    if( $self->response =~ /^0x[0-9A-F]+$/i ) {
        return $self->response;
    }
    
    return undef;
}

1;