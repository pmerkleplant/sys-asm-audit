import rlp
from eth_utils import to_bytes, to_hex
import json

# Output from nick tool.
tx_data = {
    "type": "0x0",
    "nonce": "0x0",
    "to": None,
    "gas": "0x3d090",
    "gasPrice": "0xe8d4a51000",
    "value": "0x0",
    "input": "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5f556101fd80602d5f395ff33373fffffffffffffffffffffffffffffffffffffffe1460cd57361560bd5736603814156101f95760115f54807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff146101f957600182026001905f5b5f82111560765781019083028483029004916001019190605b565b9093900434106101f957600154600101600155600354806003026004013381556001015f35815560010160203590553360601b5f5260385f601437604c5fa0600101600355005b3415156101f9575f545f5260205ff35b6003546002548082038060101160e1575060105b5f5b81811461018857828101600302600401805490600101805490600101549183604c029060601b8152601401908152602001817fffffffffffffffffffffffffffffffff000000000000000000000000000000001681526010019060401c908160381c81600701538160301c81600601538160281c81600501538160201c81600401538160181c81600301538160101c81600201538160081c81600101535360010160e3565b910180921461019a57906002556101a5565b90505f6002555f6003555b5f54807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff14156101d257505f5b6001546002828201116101e75750505f6101ed565b01600290035b5f555f600155604c025ff35b5f5ffd",
    "v": "0x1b",
    "r": "0x539",
    "s": "0xb1d471c48e730791"
}


# Convert fields from hex to bytes
nonce = to_bytes(hexstr=tx_data["nonce"])
gas_price = to_bytes(hexstr=tx_data["gasPrice"])
gas_limit = to_bytes(hexstr=tx_data["gas"])
to = b''  # 'to' is None, so we use an empty byte string
value = to_bytes(hexstr=tx_data["value"])
data = to_bytes(hexstr=tx_data["input"])

v = int(tx_data["v"], 16).to_bytes(1, byteorder='big')
r = to_bytes(hexstr=tx_data["r"]).rjust(32, b'\x00')  # Pad 'r' to 32 bytes
s = to_bytes(hexstr=tx_data["s"]).rjust(32, b'\x00')  # Pad 's' to 32 bytes

# Construct the transaction list for RLP encoding
tx_list = [nonce, gas_price, gas_limit, to, value, data, v, r, s]

# RLP-encode the transaction
encoded_tx = rlp.encode(tx_list)

# Output the raw transaction in hex format
raw_tx_hex = to_hex(encoded_tx)
print(raw_tx_hex)

