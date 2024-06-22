
;;  ---------------------------------------------------------
;; SIP-10 Fungible Token Contract | Created on: stx.city/deploy
;; ---------------------------------------------------------

;; Errors 
(define-constant ERR-UNAUTHORIZED u401)
(define-constant ERR-NOT-OWNER u402)
(define-constant ERR-INVALID-PARAMETERS u403)
(define-constant ERR-NOT-ENOUGH-FUND u101)

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Constants
(define-constant MAXSUPPLY u1000000000)

;; Variables
(define-fungible-token USA MAXSUPPLY)
(define-data-var contract-owner principal tx-sender) 



;; SIP-10 Functions
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq from tx-sender)
            (err ERR-UNAUTHORIZED))
        ;; Perform the token transfer
        (ft-transfer? USA amount from to)
    )
)


;; DEFINE METADATA
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://gaia.hiro.so/hub/19XrK7UeJYcPPC9obzh34S2fisVC41tN2v/screen-shot-2024-06-10-at-4-36-33-pm.json"))
(define-data-var token-name (string-ascii 32) "American Coin")
(define-data-var token-symbol (string-ascii 32) "USA")
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
  (ok (ft-get-balance USA owner))
)
(define-read-only (get-total-supply)
  (ok (ft-get-supply USA))
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

(define-private (send-stx (recipient principal) (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract recipient)))
    (ok true) 
  )
)

;; ---------------------------------------------------------
;; Mint
;; ---------------------------------------------------------
(begin
    (try! (send-stx 'SP1FQ3DQDR5N9HJX3XC5DNKFCG4DHH48EFJQV6QH0 u4000000))
    (try! (ft-mint? USA MAXSUPPLY (var-get contract-owner)))
)
