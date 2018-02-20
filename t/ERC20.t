use strict;
use warnings;
use Test::More;
use Ethereum::Contract;
use Ethereum::Utils;
use Math::BigInt;

my $rpc_client = Ethereum::RPC::Client->new;

my $coinbase = $rpc_client->eth_coinbase;

my $truffle_project = Ethereum::Utils::from_truffle("./t/builds/SimpleToken.json");

my $contract = Ethereum::Contract->new({
    contract_abi    => $truffle_project->{abi},
    rpc_client      => $rpc_client,
    defaults        => {from => $coinbase, gas => 3000000}});
    
$contract->deploy($truffle_project->{bytecode});
    
my @account_list = @{$rpc_client->eth_accounts()};

is Ethereum::Utils::to_string($contract->name()), "SimpleToken";
is Ethereum::Utils::to_string($contract->symbol()), "SIM";
is Ethereum::Utils::to_big_int($contract->decimals()), 18;

my $coinbase_balance = Ethereum::Utils::to_big_int($contract->balanceOf([$coinbase]));
my $account_one_balance = Ethereum::Utils::to_big_int($contract->balanceOf([$account_list[1]])), 0;

$contract->approve(\@{[$coinbase, 1000]}, 1);
$contract->transferFrom(\@{[$coinbase, $account_list[1], 1000]}, 1);

is Ethereum::Utils::to_big_int($contract->balanceOf([$coinbase])), Math::BigInt->new($coinbase_balance - 1000);
is Ethereum::Utils::to_big_int($contract->balanceOf([$account_list[1]])), Math::BigInt->new($account_one_balance + 1000);

done_testing();