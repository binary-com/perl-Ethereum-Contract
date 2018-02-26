# perl-Ethereum-Contract

Abstraction of Ethereum Contracts using Perl.

## Status

Development

## Installation

### cpan

TODO

## Usage

```perl
#!/usr/bin/perl
use strict;
use warnings;
use Ethereum::RPC::Client;
use Ethereum::Contract::Contract;

my $abi = ...
my $bytecode = ...
my $rpc_client = Ethereum::RPC::Client->new;

my $coinbase = $rpc_client->eth_coinbase;

my $contract = Ethereum::Contract->new({
    contract_abi    => $abi,
    rpc_client      => $rpc_client,
    defaults        => {from => $coinbase, gas => 3000000}});
    
# Deploying a Contract
my $contract->deploy($bytecode);

die $response->error if $response->error;

print $contract->...->to_big_int();

```

### Requirements

* perl ^5
* [Ethereum::RPC::Client](https://github.com/binary-com/perl-Ethereum-RPC-Client)

## Testing
prove -vl t/*.t

## License

perl-Ethereum-Contract is licensed under the [GPLv3](https://www.gnu.org/licenses/gpl-3.0.en.html) License.
