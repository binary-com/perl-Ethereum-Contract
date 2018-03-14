package Ethereum::Contract;
# ABSTRACT: Support for interacting with Ethereum contracts using the geth RPC interface

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

    Ethereum::Contract - Support for interacting with Ethereum contracts using the geth RPC interface

=cut

use Moo;
use JSON::MaybeXS;

use Ethereum::RPC::Client;
use Ethereum::Contract::ContractResponse;
use Ethereum::Contract::ContractTransaction;
use Ethereum::Contract::Helper::UnitConversion;

has contract_address => ( is => 'rw' );
has contract_abi     => ( is => 'ro', required => 1 );
has rpc_client       => ( is => 'ro', default => sub { Ethereum::RPC::Client->new } );
has from             => ( is => 'rw');
has gas              => ( is => 'rw');
has gas_price        => ( is => 'rw');

my $contract_decoded = {};

=head2 BUILD

Constructor: Here we get all functions from the passed ABI and bring it to contract class subs.

Parameters: 
    contract_address    (Optional - only if the contract already exists), 
    contract_abi        (Required - https://solidity.readthedocs.io/en/develop/abi-spec.html), 
    rpc_client          (Optional - Ethereum::RPC::Client(https://github.com/binary-com/perl-Ethereum-RPC-Client) - if not given, new instance will be created);
    from                (Optional - Address)
    gas                 (Optional - Integer gas)
    gas_price           (Optional - Integer gasPrice)
    
Return:
    New contract instance

=cut

sub BUILD {
    my ($self) = @_;
    
    my @decoded_json = @{decode_json($self->contract_abi)};
    
    foreach my $json_input (@decoded_json) {
        $contract_decoded->{$json_input->{name}} = \@{$json_input->{inputs}} if $json_input->{type}  eq 'function';
    }

    $self->from($self->rpc_client->eth_coinbase()) unless $self->from;
    $self->gas_price($self->rpc_client->eth_gasPrice()) unless $self->gas_price;
    
}

=head2 invoke

Invokes all calls from ABI to the contract.

Parameters: 
    name (Required - the string function name )
    params (Optional - the parameters)
    
Return:
    Ethereum::Contract::ContractTransaction

=cut

sub invoke {
    my ($self, $name, @params) = @_;
    
    my $function_id = substr($self->get_function_id($name, @{$contract_decoded->{$name}}), 0, 10);
    
    my $res = $self->call($function_id, \@params);
    
    return $res;
}

=head2 get_function_id

Get the function and parameters and merge to create the hashed ethereum function ID

Ex: function approve with the inputs address _spender and uint value must be represented as:
    SHA3("approve(address,uint)")

Parameters: 
    function_string (Required - the string function name )
    inputs (Required - the input list given on the contract ABI)
    
Return:
    New function ID hash

=cut

sub get_function_id {
    
    my ($self, $function_string, @inputs) = @_;
    
    $function_string .= "(";
    $function_string .= $_->{type} ? "$_->{type}," : "" for @inputs;
    chop($function_string) if scalar @inputs > 0;
    $function_string .= ")";
    
    my $hex_function = $self->append_prefix(unpack("H*", $function_string));
    
    my $sha3_hex_function = $self->rpc_client->web3_sha3($hex_function);
    
    return $sha3_hex_function;
    
}

=head2 call

We prepare and send the transaction:
    Already with the functionID (see get_function_id), we get all the inserted parameters in hexadecimal format (see get_hex_param)
    and concatenate with the functionID. The result will be our transaction DATA.

Parameters: 
    function_id (Required - the hashed function string name with parameters)
    params (Required - the parameters args given by the method call)
    
Return:
    Ethereum::Contract::ContractTransaction instance

=cut

sub call {

    my ($self, $function_id, $params) = @_;

    return Ethereum::Contract::ContractResponse->new({ error => "The parameters count differs from ABI information" }) 
        unless not $contract_decoded->{$function_id} or scalar @{$params} == scalar $contract_decoded->{$function_id};
    
    my $data = join("", $function_id, map { $self->get_hex_param($_) } @{$params});
    
    return Ethereum::Contract::ContractTransaction->new(
        contract_address=> $self->contract_address,
        rpc_client      => $self->rpc_client,
        data            => $self->append_prefix($data),
        from            => $self->from,
        gas             => $self->gas,
        gas_price       => $self->gas_price,
    );
    
}

=head2 get_hex_param

Convert the given value to hexadecimal format

Parameters: 
    function_id (Required - arg to be converted to hexadecimal)
    
Return:
    Hexadecimal string

=cut

sub get_hex_param {
    my ($self, $param) = @_;
    
    my $new_param;
    # Is hexadecimal string
    if( $param =~ /^0x[0-9A-F]+$/i ) {
        $new_param = sprintf( "%064s", substr($param, 2) );
    # Is integer
    } elsif ( $param =~ /^[+-]?[0-9]+$/ ) {
        $new_param = sprintf( "%064s", sprintf("%x", $param) );
    # Is string
    } else {
        $param =~ s/(.)/sprintf("%x",ord($1))/eg;
        $new_param = sprintf( "%064s", unpack("H*", $param) );
    }
    
    return $new_param;
    
}

=head2 read_all_events_from_block

Create a filter based on the given block to listen all events sent by the contract.

The filter is killed before the list return, so for any request a new filter will be created.

Parameters: 
    from_block ( Optional - start search block )
    function     ( Required - function name )
    
Return:
    https://github.com/ethereum/wiki/wiki/JSON-RPC#returns-42

=cut

sub read_all_events_from_block {
    
    my ($self, $from_block, $function) = @_;
    
    my $function_id = $self->get_function_id($function, @{$contract_decoded->{$function}});
    
    $from_block = $self->append_prefix(unpack( "H*", $from_block // "latest" ));
    
    my $res = $self->rpc_client->eth_getLogs([{
        address      => $self->contract_address,
        fromBlock    => $from_block,
        topics       => [$function_id]
    }]);
    
    return $res;

}

=head2 deploy

With given contract ABI and Bytecode, create a transaction with the contract code and return the contract address.

Parameters: 
    compiled (Required - Bytecode from the contract code)
    params   (Required - params from the constructor contract code)
    wait_seconds (Optional - how much time will try to get the contract_address)
    
Return:
    Ethereum::Contract::ContractResponse instance
    
    If the contract_address not found, the return will be an Ethereum::Contract::ContractResponse 
    with a error and a result that will be the contract creation transaction where you can find the 
    contract_address posteriorly.

=cut

sub deploy {
    my ($self, $compiled, @params) = @_;
    
    my $data = join("", $compiled, map { $self->get_hex_param($_) } @params);
    
    return Ethereum::Contract::ContractTransaction->new(
        rpc_client      => $self->rpc_client,
        data            => $data,
        from            => $self->from,
        gas             => $self->gas,
        gas_price       => $self->gas_price,
    );
    
}

=head2 append_prefix

Ensure that the given hexadecimal string starts with 0x.

=cut

sub append_prefix {
    my ($self, $str) = @_;
    return "0x$str" unless $str =~ /^0x/;
    return $str;
}

1;
