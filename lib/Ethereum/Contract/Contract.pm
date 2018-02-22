package Ethereum::Contract;

use strict;
use warnings;

use Moose;
use JSON;

use Ethereum::RPC::Client;
use Ethereum::Contract::ContractResponse;

has contract_address => ( is => 'rw', isa => 'Str' );
has contract_abi     => ( is => 'ro', isa => 'Str', required => 1 );
has rpc_client       => ( is => 'ro', default => sub { Ethereum::RPC::Client->new } );
has defaults         => ( is => 'rw' );

my $contract_decoded = {};

my $meta = __PACKAGE__->meta;

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
                
                my ($self, $params, $payable) = @_;
                
                my $function_id = $self->get_function_id($name, @inputs);
                
                my $res = $self->call($function_id, $params, $payable);
                
                return $res;
                
            });
            
            $contract_decoded->{$name} = @inputs;
            
        }
    }
    
    if($self->defaults->{gas}){
        $self->defaults->{gas} = sprintf("0x%x", $self->defaults->{gas});
    }
    
    $meta->make_immutable;
    
}

sub get_function_id {
    
    my ($self, $function_string, @inputs) = @_;
    
    $function_string .= "(";
    
    my $comma = "";
    
    foreach my $input (@inputs) {
        if($input->{type}) {
            $function_string .= $comma . $input->{type};
            $comma = ",";
        }
    }
    
    $function_string .= ")";
    
    my $full_hex_function = $self->rpc_client->web3_sha3($function_string);
    
    return substr($full_hex_function, 0, 10);
    
}

sub call {

    my ($self, $function_id, $params, $payable) = @_;
    
    return Ethereum::Contract::ContractResponse->new({ error => "The number of parameters entered differs from ABI information" }) 
        unless not $contract_decoded->{$function_id} or scalar $params == scalar $contract_decoded->{$function_id};
    
    my $data = $function_id;
    
    foreach my $param (@{$params}) {
        
        my $new_param = $self->get_hex_param($param);
        
        $data .= $new_param;
        
    }
    
    my $res;
    if ($payable){
        $res = $self->rpc_client->eth_sendTransaction([{
            to      => $self->contract_address,
            data    => $data,
            from    => $self->defaults->{from},
            gas     => $self->defaults->{gas},
        }]);
    }else{
        $res = $self->rpc_client->eth_call([{
            to    => $self->contract_address,
            data  => $data,
        }, "latest"]);
    }
    
    return Ethereum::Contract::ContractResponse->new({ response => $res });
    
}

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
        $new_param = sprintf( "%064s", $param );
    }
    
    return $new_param;
    
}

sub read_all_transactions_from_block {
    
    my ($self, $block_number) = @_;
    
    my $hex_block_number = sprintf("0x%x", $block_number);
    
    my $filter_id = $self->rpc_client->eth_newFilter([{
        address      => $self->contract_address,
        fromBlock    => $hex_block_number,
    }]);
    
    my $res = $self->rpc_client->eth_getFilterLogs([$filter_id]);
    
    $self->rpc_client->eth_uninstallFilter([$filter_id]);
    
    return $res;

}

sub deploy {
    my ($self, $compiled, $params) = @_;
    
    foreach my $param (@{$params}) {
        my $new_param = $self->get_hex_param($param);
        $compiled .= $new_param;
    }
    
    my $res = $self->rpc_client->eth_sendTransaction([{
        data        => $compiled,
        from        => $self->defaults->{from},
        gas         => $self->defaults->{gas},
    }]);
    
    my $deployed = $self->rpc_client->eth_getTransactionReceipt($res);
    
    $self->contract_address($deployed->{contractAddress});
    
}

1;