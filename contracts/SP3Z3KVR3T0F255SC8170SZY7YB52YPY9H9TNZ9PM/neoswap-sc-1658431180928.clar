(use-trait nft 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-constant agent-1 'SP12VXAS7H2MT7R8116F4RA1FCS21DZ86B4DTN80J)
(define-constant agent-2 'SP1DMPD0JNAVDRCTY17S2MNHX8F6502NB0Z25RVR)
(define-constant agent-3 'SP1Q6N226KFMA496MVWSB0VZC0T0R9FSKTYYYZ403)
(define-constant agent-4 'SP1T07GK9H4M0WP4N1DSSA7NJ7GNTQZ0GBZM0GAR2)
(define-constant agent-5 'SP27E3TDKYNH3C11RBDFPD5WGR6FV0VN08RKX4D2N)
(define-constant agent-6 'SP2BTKF13RC0Y36K3D41RJT6PA3A662BXSM63JSJ2)
(define-constant agent-7 'SP3AJC728JY0Y43E8RT6K4VDWPT265RDMXJ8M0VH0)
(define-constant agent-8 'SP3EHPZ4WHQEKS97JEREXT511T2YEJ5Y9EJP7WNBX)
(define-constant agent-9 'SP3R4NKXMGW6YXA44X2ESZPKJNV25X4ZN7DPW0RXR)
(define-constant agent-10 'SP3TZ3BCB16A0W0PPFYMGTTWTT3DVWTQEP8DFRAG1)
(define-constant agent-11 'SPBDY9Q30HMS60THMEB5D1EZT768QG5GFF87ZG7H)
(define-constant agent-12 'SPN3Y24JD5B17DN9Y8AEQGQV4VVWA644ACXBE3XE)
(define-constant agent-0 'SP1PJ0M4N981B47GT6KERPKHN1APJH2T5NWZSV7GS)

(define-data-var agent-1-status bool false)
(define-data-var agent-2-status bool false)
(define-data-var agent-3-status bool false)
(define-data-var agent-4-status bool false)
(define-data-var agent-5-status bool false)
(define-data-var agent-6-status bool false)
(define-data-var agent-7-status bool false)
(define-data-var agent-8-status bool false)
(define-data-var agent-9-status bool false)
(define-data-var agent-10-status bool false)
(define-data-var agent-11-status bool false)
(define-data-var agent-12-status bool false)


(define-data-var flag bool false)

(define-data-var deal bool false)

(define-constant deal-closed (err u300))
(define-constant cannot-escrow-nft (err u301))
(define-constant cannot-escrow-stx (err u302))
(define-constant sender-already-confirmed (err u303))
(define-constant non-tradable-agent (err u304))
(define-constant release-escrow-failed (err u305))
(define-constant deal-cancelled (err u306))
(define-constant escrow-not-ready (err u307))


;; u501 - Progress ; u502 - Cancelled ; u503 - Finished ; u504 - Escrow Ready
(define-data-var contract-status uint u501)


(define-read-only (check-contract-status) (ok (var-get contract-status)))

(define-private (check-deal) (if (and  (var-get agent-1-status) (var-get agent-2-status) (var-get agent-3-status) (var-get agent-4-status) (var-get agent-5-status) (var-get agent-6-status) (var-get agent-7-status) (var-get agent-8-status) (var-get agent-9-status) (var-get agent-10-status) (var-get agent-11-status) (var-get agent-12-status) true) (ok true) (ok false)))

(define-private (check-deal-status) (unwrap-panic (if (and  (var-get agent-1-status) (var-get agent-2-status) (var-get agent-3-status) (var-get agent-4-status) (var-get agent-5-status) (var-get agent-6-status) (var-get agent-7-status) (var-get agent-8-status) (var-get agent-9-status) (var-get agent-10-status) (var-get agent-11-status) (var-get agent-12-status)) deal-closed (ok true))))

(define-private (release-escrow)
(begin
	(unwrap-panic (as-contract (contract-call? 'SP1EC6JNZCH83K453679PQ6HYPG5XWGANGDC408JK.jacobs-family transfer u10 tx-sender agent-1)))
	(unwrap-panic (as-contract (contract-call? 'SP1EC6JNZCH83K453679PQ6HYPG5XWGANGDC408JK.jacobs-family transfer u7 tx-sender agent-1)))
	(unwrap-panic (as-contract (contract-call? 'SP1XJ6GNTDVF6HR1VHPQDMFZJY87D9W6TGMH3QCP.passion-of-christ transfer u12 tx-sender agent-2)))
	(unwrap-panic (as-contract (contract-call? 'SP2EK5VZQKRR1WYQ3F8MH86QDRDEHMC5WY6E3KA34.happy-easter-eggs transfer u14 tx-sender agent-2)))
	(unwrap-panic (as-contract (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2245 tx-sender agent-2)))
	(unwrap-panic (as-contract (contract-call? 'SP1W61GBSSTV6QFR16N7VEW549M07XP6BD0RXBW6B.btccustoms-components- transfer u22 tx-sender agent-2)))
	(unwrap-panic (as-contract (contract-call? 'SPFS9A6YG373VCPHJAV4QK3DJ0ZHC7RSTGWZS3ZE.sheep-stacks transfer u9 tx-sender agent-2)))
	(unwrap-panic (begin
		(unwrap-panic (as-contract (contract-call? 'SP497E7RX3233ATBS2AB9G4WTHB63X5PBSP5VGAQ.boom-nfts transfer u5346 tx-sender agent-3)))
		(as-contract (stx-transfer? u150000 tx-sender agent-3)))
	)
	(unwrap-panic (as-contract (contract-call? 'SPXG42Y7WDTMZF5MPV02C3AWY1VNP9FH9C23PRXH.Marbling transfer u416 tx-sender agent-4)))
	(unwrap-panic (as-contract (contract-call? 'SP2RFR92YDK6JBZQ9FTKYBYSQWEW447N9N6SZKFSV.vaping-ape transfer u213 tx-sender agent-5)))
	(unwrap-panic (begin
		(unwrap-panic (as-contract (contract-call? 'SPQZF23W7SEYBFG5JQ496NMY0G7379SRYEDREMSV.Candy transfer u1097 tx-sender agent-6)))
		(as-contract (stx-transfer? u6060000 tx-sender agent-6)))
	)
	(unwrap-panic (begin
		(unwrap-panic (as-contract (contract-call? 'SP497E7RX3233ATBS2AB9G4WTHB63X5PBSP5VGAQ.boom-nfts transfer u10450 tx-sender agent-7)))
		(as-contract (stx-transfer? u2470000 tx-sender agent-7)))
	)
	(unwrap-panic (begin
		(as-contract (stx-transfer? u6000000 tx-sender agent-8)))
	)
	(unwrap-panic (begin
		(unwrap-panic (as-contract (contract-call? 'SP22GHCK5W3EK5VC1PEB3VVCBVFRQNTQXV9306QA0.bear-market-buddies transfer u266 tx-sender agent-9)))
		(as-contract (stx-transfer? u17250000 tx-sender agent-9)))
	)
	(unwrap-panic (begin
		(as-contract (stx-transfer? u40000000 tx-sender agent-10)))
	)
	(unwrap-panic (as-contract (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2834 tx-sender agent-11)))
	(unwrap-panic (begin
		(unwrap-panic (as-contract (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2813 tx-sender agent-12)))
		(as-contract (stx-transfer? u540000 tx-sender agent-12)))
	)
	(unwrap-panic (begin
		(as-contract (stx-transfer? u5690000 tx-sender agent-0)))
	)

	(var-set deal true)
	(var-set contract-status u503)
	(ok true)
))

(define-private (cancel-escrow)
(begin        
	(if (is-eq (var-get agent-1-status) true)
	(begin
	(unwrap-panic (begin
		(as-contract (stx-transfer? u6320000 tx-sender agent-1)))
	)
	(var-set agent-1-status false)
	)
	true
	)
	(if (is-eq (var-get agent-2-status) true)
	(begin
	(unwrap-panic (begin
		(unwrap-panic (as-contract (contract-call? 'SP497E7RX3233ATBS2AB9G4WTHB63X5PBSP5VGAQ.boom-nfts transfer u10450 tx-sender agent-2)))
		(unwrap-panic (as-contract (contract-call? 'SP497E7RX3233ATBS2AB9G4WTHB63X5PBSP5VGAQ.boom-nfts transfer u5346 tx-sender agent-2)))
		(as-contract (stx-transfer? u14040000 tx-sender agent-2)))
	)
	(var-set agent-2-status false)
	)
	true
	)
	(if (is-eq (var-get agent-3-status) true)
	(begin
		(unwrap-panic (as-contract (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2813 tx-sender agent-3)))
	(var-set agent-3-status false))
	true)
	(if (is-eq (var-get agent-4-status) true)
	(begin
	(unwrap-panic (begin
		(unwrap-panic (as-contract (contract-call? 'SPQZF23W7SEYBFG5JQ496NMY0G7379SRYEDREMSV.Candy transfer u1097 tx-sender agent-4)))
		(unwrap-panic (as-contract (contract-call? 'SP22GHCK5W3EK5VC1PEB3VVCBVFRQNTQXV9306QA0.bear-market-buddies transfer u266 tx-sender agent-4)))
		(unwrap-panic (as-contract (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2834 tx-sender agent-4)))
		(as-contract (stx-transfer? u17650000 tx-sender agent-4)))
	)
	(var-set agent-4-status false)
	)
	true
	)
	(if (is-eq (var-get agent-5-status) true)
	(begin
	(unwrap-panic (begin
		(unwrap-panic (as-contract (contract-call? 'SP1XJ6GNTDVF6HR1VHPQDMFZJY87D9W6TGMH3QCP.passion-of-christ transfer u12 tx-sender agent-5)))
		(as-contract (stx-transfer? u38990000 tx-sender agent-5)))
	)
	(var-set agent-5-status false)
	)
	true
	)
	(if (is-eq (var-get agent-6-status) true)
	(begin
		(unwrap-panic (as-contract (contract-call? 'SPFS9A6YG373VCPHJAV4QK3DJ0ZHC7RSTGWZS3ZE.sheep-stacks transfer u9 tx-sender agent-6)))
		(unwrap-panic (as-contract (contract-call? 'SP2EK5VZQKRR1WYQ3F8MH86QDRDEHMC5WY6E3KA34.happy-easter-eggs transfer u14 tx-sender agent-6)))
	(var-set agent-6-status false))
	true)
	(if (is-eq (var-get agent-7-status) true)
	(begin
		(unwrap-panic (as-contract (contract-call? 'SP1W61GBSSTV6QFR16N7VEW549M07XP6BD0RXBW6B.btccustoms-components- transfer u22 tx-sender agent-7)))
	(var-set agent-7-status false))
	true)
	(if (is-eq (var-get agent-8-status) true)
	(begin
		(unwrap-panic (as-contract (contract-call? 'SP1EC6JNZCH83K453679PQ6HYPG5XWGANGDC408JK.jacobs-family transfer u10 tx-sender agent-8)))
		(unwrap-panic (as-contract (contract-call? 'SP1EC6JNZCH83K453679PQ6HYPG5XWGANGDC408JK.jacobs-family transfer u7 tx-sender agent-8)))
	(var-set agent-8-status false))
	true)
	(if (is-eq (var-get agent-9-status) true)
	(begin
		(unwrap-panic (as-contract (contract-call? 'SPXG42Y7WDTMZF5MPV02C3AWY1VNP9FH9C23PRXH.Marbling transfer u416 tx-sender agent-9)))
	(var-set agent-9-status false))
	true)
	(if (is-eq (var-get agent-10-status) true)
	(begin
		(unwrap-panic (as-contract (contract-call? 'SP2RFR92YDK6JBZQ9FTKYBYSQWEW447N9N6SZKFSV.vaping-ape transfer u213 tx-sender agent-10)))
	(var-set agent-10-status false))
	true)
	(if (is-eq (var-get agent-11-status) true)
	(begin
	(unwrap-panic (begin
		(as-contract (stx-transfer? u1160000 tx-sender agent-11)))
	)
	(var-set agent-11-status false)
	)
	true
	)
	(if (is-eq (var-get agent-12-status) true)
	(begin
		(unwrap-panic (as-contract (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2245 tx-sender agent-12)))
	(var-set agent-12-status false))
	true)

	(var-set contract-status u502)
	(ok true)
))

(define-public (confirm-and-escrow)
(begin
	(asserts! (not (is-eq (var-get contract-status) u503)) deal-closed)
	(asserts! (not (is-eq (var-get contract-status) u502)) deal-cancelled)
	(var-set flag false)
	(unwrap-panic (begin
		(if (is-eq tx-sender agent-1)
		(begin
		(asserts! (is-eq (var-get agent-1-status) false) sender-already-confirmed)
		(asserts! (is-ok (stx-transfer? u6320000 tx-sender (as-contract tx-sender))) cannot-escrow-stx )
		(var-set agent-1-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-2)
		(begin
		(asserts! (is-eq (var-get agent-2-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SP497E7RX3233ATBS2AB9G4WTHB63X5PBSP5VGAQ.boom-nfts transfer u10450 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(asserts! (is-ok (contract-call? 'SP497E7RX3233ATBS2AB9G4WTHB63X5PBSP5VGAQ.boom-nfts transfer u5346 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(asserts! (is-ok (stx-transfer? u14040000 tx-sender (as-contract tx-sender))) cannot-escrow-stx )
		(var-set agent-2-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-3)
		(begin
		(asserts! (is-eq (var-get agent-3-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2813 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(var-set agent-3-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-4)
		(begin
		(asserts! (is-eq (var-get agent-4-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SPQZF23W7SEYBFG5JQ496NMY0G7379SRYEDREMSV.Candy transfer u1097 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(asserts! (is-ok (contract-call? 'SP22GHCK5W3EK5VC1PEB3VVCBVFRQNTQXV9306QA0.bear-market-buddies transfer u266 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(asserts! (is-ok (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2834 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(asserts! (is-ok (stx-transfer? u17650000 tx-sender (as-contract tx-sender))) cannot-escrow-stx )
		(var-set agent-4-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-5)
		(begin
		(asserts! (is-eq (var-get agent-5-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SP1XJ6GNTDVF6HR1VHPQDMFZJY87D9W6TGMH3QCP.passion-of-christ transfer u12 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(asserts! (is-ok (stx-transfer? u38990000 tx-sender (as-contract tx-sender))) cannot-escrow-stx )
		(var-set agent-5-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-6)
		(begin
		(asserts! (is-eq (var-get agent-6-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SPFS9A6YG373VCPHJAV4QK3DJ0ZHC7RSTGWZS3ZE.sheep-stacks transfer u9 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(asserts! (is-ok (contract-call? 'SP2EK5VZQKRR1WYQ3F8MH86QDRDEHMC5WY6E3KA34.happy-easter-eggs transfer u14 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(var-set agent-6-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-7)
		(begin
		(asserts! (is-eq (var-get agent-7-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SP1W61GBSSTV6QFR16N7VEW549M07XP6BD0RXBW6B.btccustoms-components- transfer u22 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(var-set agent-7-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-8)
		(begin
		(asserts! (is-eq (var-get agent-8-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SP1EC6JNZCH83K453679PQ6HYPG5XWGANGDC408JK.jacobs-family transfer u10 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(asserts! (is-ok (contract-call? 'SP1EC6JNZCH83K453679PQ6HYPG5XWGANGDC408JK.jacobs-family transfer u7 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(var-set agent-8-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-9)
		(begin
		(asserts! (is-eq (var-get agent-9-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SPXG42Y7WDTMZF5MPV02C3AWY1VNP9FH9C23PRXH.Marbling transfer u416 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(var-set agent-9-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-10)
		(begin
		(asserts! (is-eq (var-get agent-10-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SP2RFR92YDK6JBZQ9FTKYBYSQWEW447N9N6SZKFSV.vaping-ape transfer u213 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(var-set agent-10-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-11)
		(begin
		(asserts! (is-eq (var-get agent-11-status) false) sender-already-confirmed)
		(asserts! (is-ok (stx-transfer? u1160000 tx-sender (as-contract tx-sender))) cannot-escrow-stx )
		(var-set agent-11-status true)
		(var-set flag true))
		true)
		(if (is-eq tx-sender agent-12)
		(begin
		(asserts! (is-eq (var-get agent-12-status) false) sender-already-confirmed)
		(asserts! (is-ok (contract-call? 'SPJJYJVZ4H7B34GG8D3SSN70WVWDYSHCC9E9ZV4V.bitcoin-toadz transfer u2245 tx-sender (as-contract tx-sender))) cannot-escrow-nft )
		(var-set agent-12-status true)
		(var-set flag true))
		true)

	(ok true)))

	(if (and  (var-get agent-1-status) (var-get agent-2-status) (var-get agent-3-status) (var-get agent-4-status) (var-get agent-5-status) (var-get agent-6-status) (var-get agent-7-status) (var-get agent-8-status) (var-get agent-9-status) (var-get agent-10-status) (var-get agent-11-status) (var-get agent-12-status) true)
		(var-set contract-status u504)
		true)
	(if (is-eq (var-get flag) true) (ok true) non-tradable-agent)
))

(define-public (cancel)
(begin (check-deal-status)
	(if (or  (is-eq tx-sender agent-1) (is-eq tx-sender agent-2) (is-eq tx-sender agent-3) (is-eq tx-sender agent-4) (is-eq tx-sender agent-5) (is-eq tx-sender agent-6) (is-eq tx-sender agent-7) (is-eq tx-sender agent-8) (is-eq tx-sender agent-9) (is-eq tx-sender agent-10) (is-eq tx-sender agent-11) (is-eq tx-sender agent-12))
	(begin
	(unwrap-panic (cancel-escrow))
	(ok true))
	non-tradable-agent)
))

(define-public (complete-neoswap)
(begin
	(asserts! (not (is-eq (var-get contract-status) u501)) escrow-not-ready)
	(asserts! (not (is-eq (var-get contract-status) u503)) deal-closed)
	(asserts! (not (is-eq (var-get contract-status) u502)) deal-cancelled)
	(unwrap-panic (release-escrow))
	(ok true)
))
