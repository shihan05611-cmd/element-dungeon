class_name ElementReclaimPort
extends RefCounted

## Agent C implements the spatial query and atomic carrier/energy mutation.
## A successful result owns a prepared, infallible commit transaction.

func prepare(_request: ElementReclaimRequest) -> ElementReclaimPrepareResult:
	return ElementReclaimPrepareResult.rejected(
		CastAttemptResult.RejectReason.MISSING_COMPONENT,
		&"element_reclaim_port_not_configured"
	)
