# AjnaLenderWithdrawEstimator

- In Terminal 1, run `anvil -m "talent dust essay arctic input daughter depth force stadium absorb cruel lemon" -a 16 --chain-id 1337 -p 8545 --steps-tracing --load-state snapshots/AjnaLenderWithdrawEstimator.json --auto-impersonate`
- In Terminal 2, run `forge create AjnaLenderWithdrawEstimator --rpc-url 127.0.0.1:8545 --private-key 0x2bbf23876aee0b3acd1502986da13a0f714c143fcc8ede8e2821782d75033ad1 --constructor-args 0x6c5c7fD98415168ada1930d44447790959097482`
- In Terminal 3, run `forge test -vvv --rpc-url http://127.0.0.1:8545`

```
Ran 4 tests for test/AjnaLenderWithdrawEstimator.t.sol:AjnaLenderWithdrawEstimatorTest
[PASS] testAjnaLenderWithdrawEstimatorWithActiveLiquidation() (gas: 446545)
Logs:
  lpBalance for user: 499977060860708820535
  amount available to withdraw: 0

[PASS] testAjnaLenderWithdrawEstimatorWithAll() (gas: 701793)
Logs:
  lpBalance for user: 499977168949771689500
  amount available to withdraw: 499977266586039718337
  amount removed: 499977266586039718337
  amount redeemed: 499977168949771689500
  lpBalance for user: 0
  New amount available to withdraw: 0

[PASS] testAjnaLenderWithdrawEstimatorWithLUP() (gas: 816216)
Logs:
  lpBalance for user: 499977168949771689500
  amount available to withdraw: 497968449503865484127
  amount removed: 497968449503865484127
  amount redeemed: 497967400645692141119
  lpBalance for user: 2009768304079548381
  New amount available to withdraw: 0

[PASS] testAjnaLenderWithdrawEstimatorWithLUP2() (gas: 816272)
Logs:
  lpBalance for user: 999954337899543379000
  amount available to withdraw: 497968449503865484127
  amount removed: 497968449503865484127
  amount redeemed: 497967400645692141119
  lpBalance for user: 501986937253851237881
  New amount available to withdraw: 0

Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 27.31ms (68.54ms CPU time)

Ran 1 test suite in 171.34ms (27.31ms CPU time): 4 tests passed, 0 failed, 0 skipped (4 total tests)
```