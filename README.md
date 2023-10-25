# Drips Fuzzing Campaign

| Property                                                                       | Result |
|--------------------------------------------------------------------------------|--------|
| Withdrawing directly from Drips should always fail                             | PASSED |
| `amtPerSec` should never be lower than `drips.minAmtPerSec()`                  | PASSED |
| Total of internal balances should match token balance of Drips                 | PASSED |
| The sum of all `amtDelta`s for an account should be zero                       | PASSED |
| Giving an amount `<=` token balance should never revert                          | PASSED |
| Test internal accounting after squeezing                                       | PASSED |
| `drips.squeezeStreamsResult` should match actual squeezed amount               | PASSED |
| Squeezing should never revert                                                  | PASSED |
| Test internal accounting after receiving streams                               | PASSED |
| If there is a receivable amount, there should be at least one receivable cycle | PASSED |
| `drips.receiveStreamsResult` should match actual received amount               | PASSED |
| Receiving streams should never revert                                          | PASSED |
| Test internal accounting after splitting                                       | PASSED |
| Splitting should never revert                                                  | PASSED |
| Test internal accounting after collecting                                      | PASSED |
| Collecting should never revert                                                 | PASSED |
| Setting streams with sane defaults should not revert                           | PASSED |
| Adding streams with sane defaults should not revert                            | PASSED |
| Removing streams should not revert                                             | PASSED |
| Test internal accounting after updating stream balance                         | PASSED |
| Updating stream balance with sane defaults should not revert                   | PASSED |
| Withdrawing all stream balance should not revert                               | PASSED |
