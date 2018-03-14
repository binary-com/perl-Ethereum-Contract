use strict;
use warnings;
use Test::More;
use Ethereum::RPC::Client;
use Ethereum::Contract;
use Ethereum::Contract::Utils;
use Math::BigInt;

my $rpc_client = Ethereum::RPC::Client->new;

my $coinbase = $rpc_client->eth_coinbase;

my $truffle_project = Ethereum::Contract::Utils::from_truffle_build("./t/builds/SimpleToken.json");

die "can't read json" unless $truffle_project;

my $contract = Ethereum::Contract->new({
    contract_abi    => $truffle_project->{abi},
    rpc_client      => $rpc_client,
    from            => $coinbase,
    gas             => 4000000,
});
    
my $response = $contract->deploy($truffle_project->{bytecode})->get_contract_address(35);
die $response->error if $response->error;

$contract->contract_address($response->response);
    
my @account_list = @{$rpc_client->eth_accounts()};

is $contract->invoke("name")->call->to_string, "SimpleToken";
is $contract->invoke("symbol")->call->to_string, "SIM";
is $contract->invoke("decimals")->call->to_big_int, 18;

my $coinbase_balance = $contract->invoke("balanceOf", $coinbase)->call->to_big_int;
my $account_one_balance = $contract->invoke("balanceOf", $account_list[1])->call->to_big_int;

$contract->invoke("approve", $account_list[1], 1000)->send;

is $contract->invoke("allowance", $coinbase, $account_list[1])->call->to_big_int, 1000;
$contract->invoke("transfer", $account_list[1], 1000)->send;

is $contract->invoke("balanceOf", $coinbase)->call->to_big_int, Math::BigInt->new($coinbase_balance - 1000);
is $contract->invoke("balanceOf", $account_list[1])->call->to_big_int, Math::BigInt->new($account_one_balance + 1000);

done_testing();
