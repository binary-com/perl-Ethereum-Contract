package Ethereum::Contract;

use strict;
use warnings;

our $VERSION = '0.001';

=head1 NAME

    Ethereum::Contract - Ethereum Contracts Abstraction using Perl

=cut

use Moose;
use JSON;

use Ethereum::RPC::Client;
use Ethereum::Contract::ContractResponse;
use Ethereum::Contract::ContractTransaction;
use Ethereum::Contract::Helper::UnitConversion;

has contract_address => ( is => 'rw', isa => 'Str' );
has contract_abi     => ( is => 'ro', isa => 'Str', required => 1 );
has rpc_client       => ( is => 'ro', default => sub { Ethereum::RPC::Client->new } );
has defaults         => ( is => 'rw' );

my $contract_decoded = {};

my $meta = __PACKAGE__->meta;

=head2 BUILD

Constructor: Here we get all functions from the passed ABI and bring it to contract class subs.

Parameters: 
    contract_address (Optional - only if the contract already exists), 
    contract_abi (Required - https://solidity.readthedocs.io/en/develop/abi-spec.html), 
    rpc_client (Optional - Ethereum::RPC::Client(https://github.com/binary-com/perl-Ethereum-RPC-Client) - if not given, new instance will be created);
    defaults (Optional - gas, from)
    
Return:
    New contract instance

=cut

sub BUILD {
    
    $meta->make_mutable;
    
    my ($self) = @_;
    
    my @decoded_json = @{decode_json($self->contract_abi)};
    my $actions = {};
    
    foreach my $json_input (@decoded_json) {
        if ($json_input->{type}  eq 'function') {
            
            my $name = $json_input->{name};
            my @inputs = @{$json_input->{inputs}};
            
            $meta->add_method( $name => sub {
                
                my ($self, @params, $payable) = @_;
                
                my $function_id = $self->get_function_id($name, @inputs);
                
                my $res = $self->call($function_id, \@params, $payable);
                
                return $res;
                
            });
            
            $contract_decoded->{$name} = \@inputs;
            
        }
    }
    
    $self->defaults->{gas} = Ethereum::Contract::Helper::UnitConversion::to_wei($self->defaults->{gas} // 4000000);
        
    $self->defaults->{from} = $self->rpc_client->eth_coinbase() unless $self->defaults->{from};
    $self->defaults->{gasPrice} = $self->rpc_client->eth_gasPrice() unless $self->defaults->{gasPrice};
    
    $meta->make_immutable;
    
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
    
    my $hex_function = "0x". unpack("H*", $function_string);
    
    my $sha3_hex_function = $self->rpc_client->web3_sha3($hex_function);
    
    return substr($sha3_hex_function, 0, 10);
    
}

=head2 call

We prepare and send the transaction:
    Already with the functionID (see get_function_id), we get all the inserted parameters in hexadecimal format (see get_hex_param)
    and concatenate with the functionID. The result will be our transaction DATA.

If payable is true we call the RPC function sendtransaction:
    https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_sendtransaction
If payable is false we call the RPC function call:
    https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_call

Parameters: 
    function_id (Required - the hashed function string name with parameters)
    params (Required - the parameters args given by the method call)
    payable (Optional - Default: false, if true require that some gas be paid to execute the transaction)
    
Return:
    Ethereum::Contract::ContractTransaction instance

=cut

sub call {

    my ($self, $function_id, $params) = @_;

    return Ethereum::Contract::ContractResponse->new({ error => "The parameters number entered differs from ABI information" }) 
        unless not $contract_decoded->{$function_id} or scalar @{$params} == scalar $contract_decoded->{$function_id};

    my $data = $function_id;
    $data .= $self->get_hex_param($_) for @{$params};
    
    return Ethereum::Contract::ContractTransaction->new(
        contract_address=> $self->contract_address,
        rpc_client      => $self->rpc_client,
        defaults        => $self->defaults,
        data            => $data,
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
    } elsif ( $param =~ /^[+-]?\d+$/ ) {
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
    block_number (Optional - start search block)
    
Return:
    https://github.com/ethereum/wiki/wiki/JSON-RPC#returns-42

=cut

sub read_all_events_from_block {
    
    my ($self, $block_number, $function) = @_;
    
    my $function_id = $self->get_function_id($function, @{$contract_decoded->{$function}});
    
    $block_number = "0x".unpack("H*", "latest") unless $block_number;
    
    my $filter_id = $self->rpc_client->eth_newFilter([{
        address      => $self->contract_address,
        fromBlock    => $block_number,
        topics       => [$function_id]
    }]);
    
    my $res = $self->rpc_client->eth_getLogs([$filter_id]);
    
    $self->rpc_client->eth_uninstallFilter([$filter_id]);
    
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
    
    foreach my $param (@params) {
        my $new_param = $self->get_hex_param($param);
        $compiled .= $new_param;
    }
    
    return Ethereum::Contract::ContractTransaction->new(
        rpc_client      => $self->rpc_client,
        defaults        => $self->defaults,
        data            => $compiled,
    );
    
}

no Moose;

1;