###################
# Public function #
###################

def process_consolidation_requests():
    reqs = dequeue_consolidation_requests()
    update_excess_consolidation_requests()
    reset_consolidation_requests_count()
    return ssz.serialize(reqs)

###########
# Helpers #
###########

class ConsolidationRequest(object):
    source_address: Bytes20
    source_pubkey: Bytes48
    target_pubkey: Bytes48

def dequeue_consolidation_requests():
    queue_head_index = sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_QUEUE_HEAD_STORAGE_SLOT)
    queue_tail_index = sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_QUEUE_TAIL_STORAGE_SLOT)
    num_in_queue = queue_tail_index - queue_head_index
    num_dequeued = min(num_in_queue, MAX_CONSOLIDATION_REQUESTS_PER_BLOCK)

    reqs = []
    for i in range(num_dequeued):
        queue_storage_slot = CONSOLIDATION_REQUEST_QUEUE_STORAGE_OFFSET + (queue_head_index + i) * 4
        source_address = address(sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot)[0:20])
        source_pubkey = (
            sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot + 1)[0:32] + sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot + 2)[0:16]
        )
        target_pubkey = (
            sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot + 2)[16:32] + sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, queue_storage_slot + 3)[0:32]
        )
        req = ConsolidationRequest(
            source_address=Bytes20(source_address),
            source_pubkey=Bytes48(source_pubkey),
            target_pubkey=Bytes48(target_pubkey)
        )
        reqs.append(req)

    new_queue_head_index = queue_head_index + num_dequeued
    if new_queue_head_index == queue_tail_index:
        # Queue is empty, reset queue pointers
        sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_QUEUE_HEAD_STORAGE_SLOT, 0)
        sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_QUEUE_TAIL_STORAGE_SLOT, 0)
    else:
        sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_QUEUE_HEAD_STORAGE_SLOT, new_queue_head_index)

    return reqs

def update_excess_consolidation_requests():
    previous_excess = sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, EXCESS_CONSOLIDATION_REQUESTS_STORAGE_SLOT)
    # Check if excess needs to be reset to 0 for first iteration after activation
    if previous_excess == EXCESS_INHIBITOR:
        previous_excess = 0

    count = sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_COUNT_STORAGE_SLOT)

    new_excess = 0
    if previous_excess + count > TARGET_CONSOLIDATION_REQUESTS_PER_BLOCK:
        new_excess = previous_excess + count - TARGET_CONSOLIDATION_REQUESTS_PER_BLOCK

    sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, EXCESS_CONSOLIDATION_REQUESTS_STORAGE_SLOT, new_excess)

def reset_consolidation_requests_count():
    sstore(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, CONSOLIDATION_REQUEST_COUNT_STORAGE_SLOT, 0)
