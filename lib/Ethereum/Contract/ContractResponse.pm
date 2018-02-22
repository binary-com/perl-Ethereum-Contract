package Ethereum::Contract::ContractResponse;

use strict;
use warnings;
use Moose;
use Encode;
use Math::BigInt;

has response => ( is => 'ro' );
has error    => ( is => 'ro' );

sub to_big_int {
    my $self = shift;
    return Math::BigInt->from_hex($self->response);
}

sub to_string {
    my $self = shift;
    
    my $packed_response = pack('H*', substr($self->response, -64));
    $packed_response =~ s/\0+$//;
    
    return $packed_response;
}

sub to_hex {
    my $self = shift;
    
    if( $self->response =~ /^0x[0-9A-F]+$/i ) {
        return $self->response;
    }
    
    return undef;
}

1;