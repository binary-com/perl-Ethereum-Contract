use strict;
use warnings;
use Test::More;
use Ethereum::Contract;
use Ethereum::Utils;
use Math::BigInt;

my $rpc_client = Ethereum::RPC::Client->new;

my $coinbase = $rpc_client->eth_coinbase;

my $truffle_project = Ethereum::Utils::from_truffle("./t/builds/SimpleCrowdsale.json");

my $contract = Ethereum::Contract->new({
    contract_abi    => $truffle_project->{abi},
    rpc_client      => $rpc_client,
    defaults        => {from => $coinbase, gas => 4000000}});
    
my $block = $rpc_client->eth_getBlockByNumber('latest', 1);
    
my $timestamp   = hex $block->{timestamp};
my $start_time   = $timestamp + 86400;
my $end_time     = $start_time + (86400 * 20);
my $rate        = Math::BigInt->new(1000);
my $wallet      = $coinbase;

$contract->deploy($truffle_project->{bytecode}, \@{[$start_time, $end_time, $rate, $wallet]});
    
my @account_list = @{$rpc_client->eth_accounts()};

is Ethereum::Utils::to_big_int($contract->startTime()), $start_time;
is Ethereum::Utils::to_big_int($contract->endTime()), $end_time;
is Ethereum::Utils::to_big_int($contract->hasEnded()), 0;
ok $contract->token;

done_testing();