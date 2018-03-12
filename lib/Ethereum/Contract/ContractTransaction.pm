package Ethereum::Contract::ContractTransaction;

use strict;
use warnings;

=head1 NAME

   Ethereum::Contract::ContractTransaction - Centralize contract transactions

=cut


use Moo;
use Ethereum::Contract::ContractResponse;

has contract_address => ( is => 'rw' );
has rpc_client       => ( is => 'ro', default => sub { Ethereum::RPC::Client->new } );
has defaults         => ( is => 'rw' );
has data             => ( is => 'rw' );

sub call {
    
    my $self = shift;
    
    my $res = $self->rpc_client->eth_call([{
        to    => $self->contract_address,
        data  => $self->data,
    }, "latest"]);
    
    return Ethereum::Contract::ContractResponse->new({ error => $res })
         if (index(lc $res,  "exception") != -1);
    
    return Ethereum::Contract::ContractResponse->new({ response => $res });
        
}

sub send {
    
    my $self = shift;
    
    my $res = $self->rpc_client->eth_sendTransaction([{
        to      => $self->contract_address,
        from    => $self->defaults->{from},
        gas     => $self->defaults->{gas},
        gasPrice=> $self->defaults->{gasPrice},
        data    => $self->data,
    }]);
    
    # VM Exception while processing transaction: revert
    # VM Exception while processing transaction: invalid OP_Code
    if( $res =~ /^0x/ ) {
        return Ethereum::Contract::ContractResponse->new({ response => $res });
    }

    return Ethereum::Contract::ContractResponse->new({ error => $res });
    
}

sub get_contract_address {
    
    my ($self, $wait_seconds, $transaction) = @_;
    
    my $res = $transaction // $self->send;
    
    return $res if $res->error;
    
    my $deployed = $self->rpc_client->eth_getTransactionReceipt($res->response);
    
    while ($wait_seconds and not $deployed and $wait_seconds > 0) {
        sleep(1);
        $wait_seconds--;
        $deployed = $self->rpc_client->eth_getTransactionReceipt($res->response);
    }
    
    return Ethereum::Contract::ContractResponse->new({
        error => "Can't get the contract address for transaction: $res", 
        response=> $res->response }) if not $deployed;
        
    # VM Exception while processing transaction: revert
    # VM Exception while processing transaction: invalid OP_Code
    return Ethereum::Contract::ContractResponse->new({ error => $res })
         if (index(lc $deployed,  "invalid") != -1);
    
    return Ethereum::Contract::ContractResponse->new({ response => $deployed->{contractAddress} });
    
}

1;