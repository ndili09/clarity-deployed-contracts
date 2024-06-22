;;  ---------------------------------------------------------
;; SIP-10 Fungible Token Contract | Created on: stx.city/deploy
;; BOME
;; ---------------------------------------------------------

;; Errors 
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-NOT-OWNER u402)
(define-constant ERR-INVALID-PARAMETERS u403)
(define-constant ERR-NOT-ENOUGH-FUND u101)

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant MAXSUPPLY u2560000000)
;; Variables
(define-fungible-token BOME MAXSUPPLY)
(define-data-var contract-owner principal tx-sender) 



;; SIP-10 Functions
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq from tx-sender)
            (err ERR-UNAUTHORIZED))
        ;; Perform the token transfer
        (ft-transfer? BOME amount from to)
    )
)


;; DEFINE METADATA
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://gaia.hiro.so/hub/1Nq7K2fxRUcTeS86RcWdvHfo1jfNrrKLYH/bome.json"))
(define-data-var token-name (string-ascii 32) "BOOK OF STACKS")
(define-data-var token-symbol (string-ascii 32) "BOME")
(define-data-var token-decimals uint u0)

(define-public 
    (set-metadata 
        (uri (optional (string-utf8 256))) 
        (name (string-ascii 32))
        (symbol (string-ascii 32))
        (decimals uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-UNAUTHORIZED))
        (asserts! 
            (and 
                (is-some uri)
                (> (len name) u0)
                (> (len symbol) u0)
                (<= decimals u10))
            (err ERR-INVALID-PARAMETERS))
        (var-set token-uri uri)
        (var-set token-name name)
        (var-set token-symbol symbol)
        (var-set token-decimals decimals)
        (print 
            {
                notification: "token-metadata-update",
                payload: {
                    token-class: "ft", 
                    contract-id: (as-contract tx-sender) 
                }
            })
(ok true)))

(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance BOME owner))
)
(define-read-only (get-total-supply)
  (ok (ft-get-supply BOME))
)

(define-read-only (get-name)
	(ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    ;; Checks if the sender is the current owner
    (if (is-eq tx-sender (var-get contract-owner))
      (begin
        ;; Sets the new owner
        (var-set contract-owner new-owner)
        ;; Returns success message
        (ok "Ownership transferred successfully"))
      ;; Error if the sender is not the owner
      (err ERR-NOT-OWNER)))
)


;; ---------------------------------------------------------
;; Utility Functions
;; ---------------------------------------------------------
(define-public (send-many (recipients (list 200 { to: principal, amount: uint, memo: (optional (buff 34)) })))
  (fold check-err (map send-token recipients) (ok true))
)

(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value))
)

(define-private (send-token (recipient { to: principal, amount: uint, memo: (optional (buff 34)) }))
  (send-token-with-memo (get amount recipient) (get to recipient) (get memo recipient))
)

(define-private (send-token-with-memo (amount uint) (to principal) (memo (optional (buff 34))))
  (let ((transferOk (try! (transfer amount tx-sender to memo))))
    (ok transferOk)
  )
)

;; ---------------------------------------------------------
;; Mint
;; ---------------------------------------------------------
(begin
    (try! (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.velar-token transfer u10000000 tx-sender 'SP1FQ3DQDR5N9HJX3XC5DNKFCG4DHH48EFJQV6QH0 none ))
    (try! (ft-mint? BOME u2557440000 (var-get contract-owner)))
 (try! (ft-mint? BOME u2560000 'SP1FQ3DQDR5N9HJX3XC5DNKFCG4DHH48EFJQV6QH0))
 
)