(define-constant A tx-sender)

(define-public (purchase-name (a0 uint))
(let ((sender tx-sender))
	(asserts! (is-eq tx-sender A) (err u0))
	(try! (stx-transfer? a0 sender (as-contract tx-sender)))
	(as-contract
	(let (
	(b0 (try! (contract-call?
		'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 swap-x-for-y
		'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
		'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex
		u100000000 (* a0 u100) none)))
	(a1 (get dy b0))
	(b1 (try! (contract-call?
		'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 swap-x-for-y
		'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex
		'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wlong
		u100000000 a1 none)))
	(a2 (/ (get dy b1) u100))
	(b2 (try! (contract-call?
		'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router swap-exact-tokens-for-tokens
		u14
		'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
		'SP265WBWD4NH7TVPYQTVD23X3607NNK4484DTXQZ3.longcoin
		'SP265WBWD4NH7TVPYQTVD23X3607NNK4484DTXQZ3.longcoin
		'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
		'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
		a2 u1)))
	(a3 (get amt-out b2))
	)
		(asserts! (> a3 a0) (err a3))
		(try! (stx-transfer? a3 tx-sender sender))
		(ok (list a0 a1 a2 a3))
	))))