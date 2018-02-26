use strict;
use warnings;
use Test::More;
use Ethereum::RPC::Client;
use Ethereum::Contract::Contract;
use Ethereum::Contract::Utils;
use Math::BigInt;

my $rpc_client = Ethereum::RPC::Client->new;

my $coinbase = $rpc_client->eth_coinbase;

my $truffle_project = Ethereum::Contract::Utils::from_truffle_build("./t/builds/SimpleToken.json");

die "can't read json" unless $truffle_project;

my $contract = Ethereum::Contract->new({
    contract_abi    => $truffle_project->{abi},
    rpc_client      => $rpc_client,
    defaults        => {from => $coinbase, gas => 3000000}});
    
my $response = $contract->deploy($truffle_project->{bytecode});
die $response->error if $response->error;
    
my @account_list = @{$rpc_client->eth_accounts()};

is $contract->name->to_string, "SimpleToken";
is $contract->symbol->to_string, "SIM";
is $contract->decimals->to_big_int, 18;

my $coinbase_balance = $contract->balanceOf([$coinbase])->to_big_int;
my $account_one_balance = $contract->balanceOf([$account_list[1]])->to_big_int, 0;

$contract->approve(\@{[$coinbase, 1000]}, 1);
$contract->transferFrom(\@{[$coinbase, $account_list[1], 1000]}, 1);

is $contract->balanceOf([$coinbase])->to_big_int, Math::BigInt->new($coinbase_balance - 1000);
is $contract->balanceOf([$account_list[1]])->to_big_int, Math::BigInt->new($account_one_balance + 1000);

done_testing();