(define-constant DEPLOYER_STANDARD_PRINCIPAL tx-sender)
(define-constant DEPLOYER_CONTRACT_PRINCIPAL (as-contract tx-sender))

(define-constant BNS_NAMESPACE 0x737478)                        ;; buff 'stx'
(define-constant BNS_NAME      0x313031626e737465737430303031)  ;; buff '101bnstest0001'

(define-public (transfer-name-to-contract)
    (contract-call?
        'SP000000000000000000002Q6VF78.bns     
        name-transfer 
        BNS_NAMESPACE
        BNS_NAME
        DEPLOYER_CONTRACT_PRINCIPAL  ;; new owner
        none ;; zonefile
    )
)