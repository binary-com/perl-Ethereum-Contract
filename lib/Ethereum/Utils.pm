package Ethereum::Utils;

use strict;
use warnings;
use Encode;
use Math::BigInt;
use JSON;

sub to_big_int {
    my $param = shift;
    return Math::BigInt->from_hex($param);
}

sub to_string {
    my $param = shift;
    
    my $packed_response = pack('H*', substr($param, -64));
    $packed_response =~ s/\0+$//;
    
    return $packed_response;
}

sub from_truffle {
    my $file = shift;
    
    my $document = do {
        local $/ = undef;
        open my $fh, "<", $file
            or die "could not open $file: $!";
        <$fh>;
    };
    
    my $decoded_json = decode_json($document);
    
    return { abi => encode_json($decoded_json->{abi}), bytecode => $decoded_json->{bytecode} };
}

1;