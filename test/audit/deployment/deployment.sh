#!/bin/bash
#
# Deploy withdrawals and consolidations contracts and verify constructor
# behaved as expected.
set -euf -o pipefail

# Start anvil in background
anvil -b 1 --chain-id 1 > /dev/null &
anvilPID=$!

rpc="http://127.0.0.1:8545"

# Default funded wallet used to fund deployer address.
funder_pk="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

################################################################################
## Withdrawals
################################################################################
echo "Checking withdrawals deployment"
echo "---"
# Recevied via script/addr.sh
sender="0x184883fFD0ee9e1C5D2491e32B6CB0a1eE3a5202"
addr="0xE7F0335dD507E5f243C28117b28B3f114d591f80"
tx_raw="0xf902418085e8d4a510008303d0908080b9022a7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5f556101fd80602d5f395ff33373fffffffffffffffffffffffffffffffffffffffe1460cd57361560bd5736603814156101f95760115f54807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff146101f957600182026001905f5b5f82111560765781019083028483029004916001019190605b565b9093900434106101f957600154600101600155600354806003026004013381556001015f35815560010160203590553360601b5f5260385f601437604c5fa0600101600355005b3415156101f9575f545f5260205ff35b6003546002548082038060101160e1575060105b5f5b81811461018857828101600302600401805490600101805490600101549183604c029060601b8152601401908152602001817fffffffffffffffffffffffffffffffff000000000000000000000000000000001681526010019060401c908160381c81600701538160301c81600601538160281c81600501538160201c81600401538160181c81600301538160101c81600201538160081c81600101535360010160e3565b910180921461019a57906002556101a5565b90505f6002555f6003555b5f54807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff14156101d257505f5b6001546002828201116101e75750505f6101ed565b01600290035b5f555f600155604c025ff35b5f5ffd1b820539821337"

# Fund sender
cast send "$sender" --value "1 ether" --private-key "$funder_pk" --rpc-url "$rpc"

# Publish deployment tx
cast publish "$tx_raw" --rpc-url "$rpc"

# Verify slots are correct
slot0=$(cast storage "$addr" 0) # excess
echo "$slot0"
if ! [ "$slot0" == "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ]; then
    echo "excess not inhibitor"
    exit 1
else
    echo "excess us inhibitor"
fi
slot1=$(cast storage "$addr" 1) # counter
if ! [ "$slot1" == "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "counter not zero"
    exit 1
else
    echo "counter is zero"
fi
slot2=$(cast storage "$addr" 2) # head
if ! [ "$slot2" == "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "head not zero"
    exit 1
else
    echo "head is zero"
fi
slot3=$(cast storage "$addr" 3) # tail
if ! [ "$slot3" == "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "tail not zero"
    exit 1
else
    echo "tail is zero"
fi

echo ""
echo ""

################################################################################
## Consolidations
################################################################################
echo "Checking withdrawals deployment"
echo "---"
# Recevied via script/addr.sh
sender="0x206416B4420b0c31b9187b7ECF145975736a4E0d"
addr="0x8F9C6F82E71885eFc5332B8b144f1F6bd2B6Ba1F"
tx_raw="0xf901ee8085e8d4a510008303d0908080b901d77fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5f556101aa80602d5f395ff33373fffffffffffffffffffffffffffffffffffffffe1460d557361560c55736606014156101a65760115f54807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff146101a657600182026001905f5b5f82111560765781019083028483029004916001019190605b565b9093900434106101a657600154600101600155600354806004026004013381556001015f358155600101602035815560010160403590553360601b5f5260605f60143760745fa0600101600355005b3415156101a6575f545f5260205ff35b6003546002548082038060011160e9575060015b5f5b8181146101355782810160040260040180549060010180549060010180549060010154846074029360601b84529360601b84529183601401528260340152906054015260010160eb565b91018092146101475790600255610152565b90505f6002555f6003555b5f54807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff141561017f57505f5b6001546001828201116101945750505f61019a565b01600190035b5f555f6001556074025ff35b5f5ffd1b820539821337"

# Fund sender
cast send "$sender" --value "1 ether" --private-key "$funder_pk" --rpc-url "$rpc"

# Publish deployment tx
cast publish "$tx_raw" --rpc-url "$rpc"

# Verify slots are correct
slot0=$(cast storage "$addr" 0) # excess
echo "$slot0"
if ! [ "$slot0" == "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff" ]; then
    echo "excess not inhibitor"
    exit 1
else
    echo "excess us inhibitor"
fi
slot1=$(cast storage "$addr" 1) # counter
if ! [ "$slot1" == "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "counter not zero"
    exit 1
else
    echo "counter is zero"
fi
slot2=$(cast storage "$addr" 2) # head
if ! [ "$slot2" == "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "head not zero"
    exit 1
else
    echo "head is zero"
fi
slot3=$(cast storage "$addr" 3) # tail
if ! [ "$slot3" == "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo "tail not zero"
    exit 1
else
    echo "tail is zero"
fi

echo ""
echo ""

# Kill anvil
kill "$anvilPID"
