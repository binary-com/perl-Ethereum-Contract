package Ethereum::Contract::Helper::ImportHelper;

use strict;
use warnings;

=head1 NAME

    Ethereum::Contract::Helper::ImportHelper - ImportHelper

=cut


use JSON;

=head2 to_hex

Auxiliar to get bytecode and the ABI from the compiled truffle json.

Parameters: 
    file path
    
Return:
    {abi, bytecode}

=cut

sub from_truffle_build {
    my $file = shift;
    
    my $document = do {
        local $/ = undef;
        open my $fh, "<", $file
            or return undef;
        <$fh>;
    };
    
    my $decoded_json = decode_json($document);
    
    return { abi => encode_json($decoded_json->{abi}), bytecode => $decoded_json->{bytecode} };
}

1;