def add_consolidation_request(Bytes48: source_pubkey, Bytes48: target_pubkey):
    """
    Add consolidation request adds new request to the consolidation request queue, so long as a sufficient fee is provided.
    """

    # Verify sufficient fee was provided.
    fee = get_fee()
    require(msg.value >= fee, 'Insufficient value for fee')

    # Increment consolidation request count.
    count = sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_COUNT_STORAGE_SLOT)
    sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_COUNT_STORAGE_SLOT, count + 1)

    # Insert into queue.
    queue_tail_index = sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_QUEUE_TAIL_STORAGE_SLOT)
    queue_storage_slot = CONSOLIDATION_REQUEST_QUEUE_STORAGE_OFFSET + queue_tail_index * 4
    sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot, msg.sender)
    sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot + 1, source_pubkey[0:32])
    sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot + 2, source_pubkey[32:48] ++ target_pubkey[0:16])
    sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot + 3, target_pubkey[16:48])
    sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_QUEUE_TAIL_STORAGE_SLOT, queue_tail_index + 1)

def get_fee() -> int:
    excess = sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, EXCESS_CONSOLIDATION_REQUESTS_STORAGE_SLOT)
    require(excess != EXCESS_INHIBITOR, 'Inhibitor still active')
    return fake_exponential(
        MIN_CONSOLIDATION_REQUEST_FEE,
        excess,
        CONSOLIDATION_REQUEST_FEE_UPDATE_FRACTION
    )

def fake_exponential(factor: int, numerator: int, denominator: int) -> int:
    i = 1
    output = 0
    numerator_accum = factor * denominator
    while numerator_accum > 0:
        output += numerator_accum
        numerator_accum = (numerator_accum * numerator) // (denominator * i)
        i += 1
    return output // denominator
