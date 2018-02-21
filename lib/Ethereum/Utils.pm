package Ethereum::Utils;

use strict;
use warnings;

use JSON;

sub from_truffle {
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