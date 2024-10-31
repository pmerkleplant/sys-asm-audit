# Constants from the contracts. Same for both - consolidations and withdrawals.
FACTOR = 1
DENOMINATOR = 17

# Copied from EIPs
def fake_exponential(factor: int, numerator: int, denominator: int) -> int:
    i = 1
    output = 0
    numerator_accum = factor * denominator
    while numerator_accum > 0:
        output += numerator_accum
        numerator_accum = (numerator_accum * numerator) // (denominator * i)
        i += 1
    return output // denominator

####### DoS Analysis #######
#
# Note that DoS-ing the consolidations contract can only be attributed to
# griefing. However, DoS-ing withdrawals may lead to financial gains, eg via
# preventing competitors' payout.
#
# Therefore, this analysis is concentrated on the withdrawal contract.
# There are two differences compared to the consolidations contract:
# - The target per block is 2 not 1
# - The max number of requests processed per block is 16 not 1
#
# Note that an attacker can add multiple requests without updating the fee iff
# the requests are added in the same block.
#
# Foundry tells us adding a user request costs ~114k gas. To underestimate, lets
# use GAS_COST = 100k.
#
# Current block limit is 30MM gas. To overestimate, lets use GAS_LIMIT=300MM,
# leading to a theoretical maximum of withdrawal requests without fee update:
max_requests = 300_000_000 / 100_000
print(f"max requests possible: {max_requests}")
# = 3k
#
# Adding 3k withdrawal requests has the following fee cost when excess = 0:
fee = fake_exponential(FACTOR, 0, DENOMINATOR) * max_requests
print(f"fee for max requests: {fee} wei")
# = 3k wei = 0.000000000000003 ETH
#
# The contract fees for such an attack are therefore negligible.
#
# With 16 requests processed per block, the contract is therefore DoSed for:
dos_blocks = max_requests / 16
dos_seconds = dos_blocks * 12  # Assumes 12s block time
print(f"DoS: blocks={dos_blocks}, seconds={dos_seconds}")
# = 188 blocks or 2250 seconds ~= 0.6 hours
#
# [Consolidations]
# Quick check if 1 request is processed per block, as per consolidations
# contract.
dos_blocks_consolidations = max_requests / 1
dos_seconds_consolidations = dos_blocks_consolidations * 12
print(f"[Consolidations] DoS: blocks={dos_blocks_consolidations}, seconds={dos_seconds_consolidations}")
# = 3000 blocks or 36k seconds = 10 hours
# [END Consolidations]
#
# Note that continuing the attack in the next block _SHOULD_ become impossible
# due to the updated excess value and therefore high fee.
excess_after_attack = max_requests - 2 # TARGET=2
print(f"Excess after attack: {excess_after_attack}")
fee_after_attack_1_block = fake_exponential(FACTOR, excess_after_attack, DENOMINATOR)
print(f"Fee 1 block after attack: {fee_after_attack_1_block} wei (using python impl)")
# ~= 3.8e76 wei = too much
#
# However, the python implementation does not yield the same result as a
# Solidity/Geas implementation. This is bc EVM implementation will overflow for
# excess > 2892.
#
# Using an (non-reverting, ie overflowing) EVM implementation, the fee is:
print(f"Fee 1 block after attack: ~5.9e73 wei (using EVM impl)")
#
# Eventhough the computed fees differ, both are in a non-reasonable range
# to possibly continue an attack.
#
# However, this also means the contract is effetctively still DoSed.
#
# Assuming a withdrawal request costing 10 ETH is acceptable, how long does
# it take?
excess = excess_after_attack
blocks = 1
while True:
    # Let next block be processed, ie excess is updated.
    # Note that excess is decreased each block by the target.
    excess = excess - 2
    # Compute new fee.
    fee = fake_exponential(FACTOR, excess, DENOMINATOR)
    if fee <= 10e18:
        break
    else:
        blocks = blocks + 1
print(f"Time until 10 ETH gives request: blocks={blocks}, seconds={blocks * 12}")
# = 1128 blocks or 13,536 seconds ~= 3.7 hours
#
# However, 10 ETH is quite a lot. Whats with 1 ETH?
excess = excess_after_attack
blocks = 1
while True:
    # Let next block be processed, ie excess is updated.
    # Note that excess is decreased each block by the target.
    excess = excess - 2
    # Compute new fee.
    fee = fake_exponential(FACTOR, excess, DENOMINATOR)
    if fee <= 1e18:
        break
    else:
        blocks = blocks + 1
print(f"Time until 1 ETH gives request: blocks={blocks}, seconds={blocks * 12}")
# = 1147 blocks or 13,764 seconds ~= 3.8 hours
# [Consolidations]
excess = excess_after_attack
blocks = 1
while True:
    # Let next block be processed, ie excess is updated.
    # Note that excess is decreased each block by the target.
    excess = excess - 1 # TARGET=1
    # Compute new fee.
    fee = fake_exponential(FACTOR, excess, DENOMINATOR)
    if fee <= 1e18:
        break
    else:
        blocks = blocks + 1
print(f"[Consolidations] Time until 1 ETH gives request: blocks={blocks}, seconds={blocks * 12}")
# = 2294 blocks or 27,528 seconds ~= 7.6 hours
# [END Consolidations]
#
# The time difference is negligible... power of exponentiation.
#
# == Summary ==
#
# In total a block proposer can effectively DoS the withdrawals contract with a
# single block for roughly 3.8 hours with __only__ the opportunity cost of the
# wasted block.
#
# [Consolidations]
# For consolidations, its 7.6 hours.
# [END Consolidations]
#
# Note that there are multiple entities that are producing blocks in a higher
# frequency than 3.8 hours.
#
# Note further that this attack breaks an important _implicit_ invariant:
#
#   For higher excess values, the fee should not decrease
#
# This invariant is broken for `excess >= 2892`. The result starts to oscilate.
# For more info, see fake_expo_plots/emv.png.

