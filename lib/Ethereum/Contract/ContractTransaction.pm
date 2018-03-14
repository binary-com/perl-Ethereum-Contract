package Ethereum::Contract::ContractTransaction;

use strict;
use warnings;

=head1 NAME

   Ethereum::Contract::ContractTransaction - Centralize contract transactions

=cut


use Moo;
use Ethereum::Contract::ContractResponse;
use Ethereum::Contract::Helper::UnitConversion;

has contract_address => ( is => 'rw' );
has rpc_client       => ( is => 'ro', default => sub { Ethereum::RPC::Client->new } );
has data             => ( is => 'rw' );
has from             => ( is => 'rw');
has gas              => ( is => 'rw');
has gas_price        => ( is => 'rw');

=head2 call

Call - call a public functions and variables from a ethereum contract
    
Return:
    Ethereum::Contract::ContractResponse

=cut

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

=head2 send

Send - send a transaction to a payable functions from a ethereum contract

The parameter GAS is required to send a payable request.
    
Return:
    Ethereum::Contract::ContractResponse

=cut

sub send {
    
    my $self = shift;
    
    return Ethereum::Contract::ContractResponse->new({error => "the transaction can't be sent without the GAS parameter"}) unless $self->gas;
    
    my $res = $self->rpc_client->eth_sendTransaction([{
        to          => $self->contract_address,
        from        => $self->from,
        gas         => Ethereum::Contract::Helper::UnitConversion::to_wei($self->gas),
        gasPrice    => $self->gas_price,
        data        => $self->data,
    }]);
    
    return Ethereum::Contract::ContractResponse->new({ response => $res }) if $res and $res =~ /^0x/;
    
    return Ethereum::Contract::ContractResponse->new({ error => $res });
    
}

=head2 get_contract_address

Try to get a contract address based on a transaction hash

Parameters: 
    $wait_seconds    (Optional - max time to wait for the contract address response), 
    $transaction     (Optional - response of the send method, if not informed send a new transaction and then try to get the address ), 
    
Return:
    Ethereum::Contract::ContractResponse

=cut

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
        response=> $res->response }) unless $deployed;
    
    return Ethereum::Contract::ContractResponse->new({ response => $deployed->{contractAddress} }) 
        if ref($deployed) eq 'HASH';
        
    return Ethereum::Contract::ContractResponse->new({ error => $res });
    
}

1;
