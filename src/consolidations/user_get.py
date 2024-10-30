def get_excess_consolidation_requests():
    count = sload(CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS, EXCESS_CONSOLIDATION_REQUESTS_STORAGE_SLOT)
    return count
