# Script to plot fake exponential for withdrawals and consolidations system
# contracts for different excess amounts.
import matplotlib.pyplot as plt
from pathlib import Path

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

# Plot fee in ranges of 10 each (if do not exist yet).
if not Path("fake_expo_plots/00_fee_0-10.png").is_file():
    for i in range(70):
        start = i * 10
        end = start + 10

        excess = [x for x in range(start, end)]
        fee = [fake_exponential(FACTOR, x, DENOMINATOR) / 1e18 for x in excess]

        plt.plot(excess, fee, label='')
        plt.xlabel('excess')
        plt.ylabel('fee in ETH')
        plt.subplots_adjust(left=0.2, right=0.8, bottom=0.2, top=0.8)
        plt.title('Fees')
        plt.legend()
        plt.savefig(f'fake_expo_plots/{i:02}_fee_{start}-{end}.png')

####### DoS Analysis #######
#
# Note that DoS-ing the consolidations contract can only be attributed to
# griefing.
# However, DoS-ing withdrawals may lead to financial gains, eg via preventing
# competitors' payout.
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
# use GAS_COST = 50k.
#
# Current block limit is 30MM gas. To overestimate, lets use GAS_LIMIT=300MM,
# leading to a theoretical maximum of 20k withdrawal requests without fee update.
#
# Adding 20k withdrawal requests has the following fee cost when excess = 0:
fee = (fake_exponential(FACTOR, 0, DENOMINATOR) * 20_000)
# = 20k wei = 0.00000000000002 ETH
#
# The contract fees for such an attack are therefore negligible.
#
# With 16 requests processed per block, the contract is therefore DoSed for:
dos_blocks = 20_000 / 16
dos_seconds = dos_blocks * 12  # Assumes 12s block time
# = 1250 blocks or 15,000 seconds ~= 4 hours
#
# Note that continuing the attack becomes basically as the contract adjusted
# the fee.
fee_after_attack_1_block = fake_exponential(FACTOR, 20_000 - 2, DENOMINATOR)

# FUCK:
# 1) Starting ~2800 we get overflow in fake_expo, meaning fee is incorrect
#
# Note that block producers (lido, coinbase, etc) are _excatly_ the ones that are at suspicion of performing such an attack.

"""
# Attackers has 100 ETH and wants to DoS withdrawals.
# They insert 16 requests per block.
# How much will the 100 ETH last?
total = 0
excess = 0
# TODO: Need to find reasonable number of how many req per block are possible
#       The more per block, the cheaper the attack.
#       TODO: Need exact gas costs for this.
req_per_block = 16 # For withdrawals
target = 2 # For withdrawals
#req_per_block = 10 # For consolidations
#target = 1 # For consolidations
block = 0
while True:
    fee = fake_exponential(1, excess, 17)
    total = total + (req_per_block * fee) # We pushed all for the same fee

    # New block, excess gets updated
    block = block + 1
    count = req_per_block
    excess = excess + count - target

    if total > 1000 * 1e18:
        print(f"DoS block range: {block}")
        print(f"DoS time range: {block * 12}s ~= {block * 12 / 60}mins")
        break

exit
"""
