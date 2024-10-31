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

# Plot EVM implementation value (if do not exist yet).
if not Path("fake_expo_plots/evm.png").is_file():
    with open('fake_expo_evm.txt', 'r') as file:
        excess = [i for i in range(20_000)]
        fee = [float(line.strip()) for line in file]

        plt.plot(excess, fee, label='')
        plt.xlabel('excess')
        plt.ylabel('fee in WEI')
        plt.subplots_adjust(left=0.2, right=0.8, bottom=0.2, top=0.8)
        plt.title('Fees')
        plt.legend()
        plt.savefig(f'fake_expo_plots/evm.png')
