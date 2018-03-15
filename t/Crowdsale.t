use strict;
use warnings;
use Test::More;
use Ethereum::RPC::Client;
use Ethereum::Contract;
use Ethereum::Contract::Helper::ImportHelper;
use Math::BigInt;

my $rpc_client = Ethereum::RPC::Client->new;

my $coinbase = $rpc_client->eth_coinbase;

my $truffle_project = Ethereum::Contract::Helper::ImportHelper::from_truffle_build("./t/builds/SimpleCrowdsale.json");

die "can't read json" unless $truffle_project;

my $contract = Ethereum::Contract->new({
    contract_abi    => $truffle_project->{abi},
    rpc_client      => $rpc_client,
});
    
my $block = $rpc_client->eth_getBlockByNumber('latest', 1);
    
my $timestamp   = hex $block->{timestamp};
my $start_time   = $timestamp + 86400;
my $end_time     = $start_time + (86400 * 20);
my $rate        = Math::BigInt->new(1000);
my $wallet      = $coinbase;

my ($message, $error) = $contract->invoke_deploy($truffle_project->{bytecode}, $start_time, $end_time, $rate, $wallet)->get_contract_address(35);
ok $error;

$contract->gas(4000000);
$contract->from($coinbase);

($message, $error) = $contract->invoke_deploy($truffle_project->{bytecode}, $start_time, $end_time, $rate, $wallet)->get_contract_address(35);

$contract->contract_address($message->response);
    
my @account_list = @{$rpc_client->eth_accounts()};

($message, $error) = $contract->invoke("startTime")->call();
ok !$error;
is $message->to_big_int, $start_time;

($message, $error) = $contract->invoke("endTime")->call();
ok !$error;
is $message->to_big_int, $end_time;

($message, $error) = $contract->invoke("hasEnded")->call();
ok !$error;
is $message->to_big_int, 0;

($message, $error) = $contract->invoke("token")->call();
ok !$error;
ok $message->to_hex;

done_testing();
