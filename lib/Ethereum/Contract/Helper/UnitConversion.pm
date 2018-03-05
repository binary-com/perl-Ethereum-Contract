package Ethereum::Contract::Helper::UnitConversion;

use strict;
use warnings;
use Math::BigFloat;

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

my $WEI_CONSTANT = 1000000000000000000;

sub to_wei {
    return shift
}

sub to_kwei {
    return to_hex(sprintf "%.3f", shift);
}

sub to_mwei {
    return to_hex(sprintf "%.6f", shift);
}

sub to_gwei {
    return to_hex(sprintf "%.9f", shift);
}

sub to_szabo {
    return to_hex(sprintf "%.12f", shift);
}

sub to_finney {
    return to_hex(sprintf "%.15f", shift);
}

sub to_ether {
    return to_hex(sprintf "%.18f", shift);
}

sub to_kether {
    return to_hex(sprintf "%.21f", shift);
}

sub to_mether {
    return to_hex(sprintf "%.24f", shift);
}

sub to_gether {
    return to_hex(sprintf "%.27f", shift);
}

sub to_tether {
    return to_hex(sprintf "%.30f", shift);
}

sub to_hex {
    Math::BigFloat->new(shift)->to_hex;    
}

1;