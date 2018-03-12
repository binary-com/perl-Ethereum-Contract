package Ethereum::Contract::Helper::UnitConversion;

use strict;
use warnings;
use Math::BigInt;

=head1 NAME

    Ethereum::Contract::Helper::UnitConversion - Ethereum Unit Converter
    
    wei:        ‘1’
    kwei:       ‘1000’
    mwei:       ‘1000000’
    gwei:       ‘1000000000’
    szabo:      ‘1000000000000’
    finney:     ‘1000000000000000’
    ether:      ‘1000000000000000000’
    kether:     ‘1000000000000000000000’
    mether:     ‘1000000000000000000000000’
    gether:     ‘1000000000000000000000000000’
    tether:     ‘1000000000000000000000000000000’

=cut

sub to_wei {
    return to_hex(shift, 1);
}

sub to_kwei {
    return to_hex(shift, 1000);
}

sub to_mwei {
    return to_hex(shift, 1000000);
}

sub to_gwei {
    return to_hex(shift, 1000000000);
}

sub to_szabo {
    return to_hex(shift, 1000000000000);
}

sub to_finney {
    return to_hex(shift, 1000000000000000);
}

sub to_ether {
    return to_hex(shift, 1000000000000000000);
}

sub to_kether {
    return to_hex(shift, 1000000000000000000000);
}

sub to_mether {
    return to_hex(shift, 1000000000000000000000000)
}

sub to_gether {
    return to_hex(shift, 1000000000000000000000000000);
}

sub to_tether {
    return to_hex(shift, 1000000000000000000000000000000);
}

sub to_hex {
    my ($number, $precision) = @_;
    return "0x" . Math::BigFloat->new($number)->bmul($precision)->to_hex;
}

1;