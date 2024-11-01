import sys
import rlp
import json
from eth_utils import to_bytes, to_hex

# Expect exactly one argument
if len(sys.argv) != 2:
    exit(1)

# Read arg as tx .json file.
tx_file = sys.argv[1]

with open(tx_file, 'r') as file:
    tx_data = json.load(file)

# Convert the transaction fields from hex to bytes
nonce = to_bytes(hexstr=tx_data["nonce"])
max_priority_fee_per_gas = b''
max_fee_per_gas = b''
gas_limit = to_bytes(hexstr="0xFFFFFFFFFFFFFFFF")
to = b''
value = to_bytes(hexstr=tx_data["value"])
data = to_bytes(hexstr=tx_data["input"])
access_list = []  # EIP-1559 transactions can include an access list, leave empty if none
v = to_bytes(hexstr=tx_data["v"])
r = to_bytes(hexstr=tx_data["r"])
s = to_bytes(hexstr=tx_data["s"])

# Construct the transaction as a list for RLP encoding
tx_list = [
    nonce, max_priority_fee_per_gas, max_fee_per_gas, gas_limit, to, value, data, access_list, v, r, s
]

# Encode the transaction type 0x02 (EIP-1559) and RLP-encode the transaction
encoded_tx = b'\x02' + rlp.encode(tx_list)

print(to_hex(encoded_tx))

