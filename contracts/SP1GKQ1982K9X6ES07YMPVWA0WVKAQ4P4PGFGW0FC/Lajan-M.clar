;; Title: MultiSafe
;; Author: Talha Bugra Bulut & Trust Machines
;;
;; Synopsis:
;; A multi-owner contract to manage Stacks Blockchain resources that requires n number of confirmations.
;; Owners submit new transactions specifying a target executor function of a smart contract that implements
;; executor-trait interface. The executor function gets triggered along with two parameters (param-p a principal 
;; parameter and param-u an uint parameter) when the transaction receive sufficient number of confirmations from 
;; owners. The target executor function can execute any kind of code with authority of the safe contract instance
;; such as STX transfer, sip-009-nft transfer, sip-010-trait-ft transfer and much more. Owners list limited to 20 
;; members at maximum considering a realistic use case for this kind of multi-owner safe contract.

(use-trait executor-trait 'SP1Z5Z68R05X2WKSSPQ0QN0VYPB1902884KPDJVNF.multisafe-traits.executor-trait) 
(use-trait safe-trait 'SP1Z5Z68R05X2WKSSPQ0QN0VYPB1902884KPDJVNF.multisafe-traits.safe-trait)
(use-trait nft-trait 'SP1Z5Z68R05X2WKSSPQ0QN0VYPB1902884KPDJVNF.multisafe-traits.sip-009-trait)
(use-trait ft-trait 'SP1Z5Z68R05X2WKSSPQ0QN0VYPB1902884KPDJVNF.multisafe-traits.sip-010-trait)

(impl-trait 'SP1Z5Z68R05X2WKSSPQ0QN0VYPB1902884KPDJVNF.multisafe-traits.safe-trait)

;; Errors
(define-constant ERR-CALLER-MUST-BE-SELF (err u100))
(define-constant ERR-OWNER-ALREADY-EXISTS (err u110))
(define-constant ERR-OWNER-NOT-EXISTS (err u120))
(define-constant ERR-UNAUTHORIZED-SENDER (err u130))
(define-constant ERR-TX-NOT-FOUND (err u140))
(define-constant ERR-TX-ALREADY-CONFIRMED-BY-OWNER (err u150))
(define-constant ERR-TX-INVALID-EXECUTOR (err u160))
(define-constant ERR-INVALID-SAFE (err u170))
(define-constant ERR-TX-CONFIRMED (err u180))
(define-constant ERR-TX-NOT-CONFIRMED-BY-SENDER (err u190))
(define-constant ERR-AT-LEAST-ONE-OWNER-REQUIRED (err u200))
(define-constant ERR-THRESHOLD-CANT-BE-ZERO (err u210))
(define-constant ERR-THRESHOLD-OVERFLOW (err u220))
(define-constant ERR-THRESHOLD-OVERFLOW-OWNERS (err u230))
(define-constant ERR-TX-INVALID-FT (err u240))
(define-constant ERR-TX-INVALID-NFT (err u250))

;; Principal of deployed contract
(define-constant SELF (as-contract tx-sender))

;; --- Version

;; Version string
(define-constant VERSION "0.0.2.alpha")

;; Returns version of the safe contract
;; @returns string-ascii
(define-read-only (get-version) 
    VERSION
)

;; --- Owners

;; The owners list
(define-data-var owners (list 20 principal) (list)) 

;; Returns owner list
;; @returns list
(define-read-only (get-owners)
    (var-get owners)
)

;; Private function to push a new member to the owners list
;; @params owner
;; @returns bool
(define-private (add-owner-internal (owner principal))
    (var-set owners (unwrap-panic (as-max-len? (append (var-get owners) owner) u20)))
)

;; Adds new owner
;; @restricted to SELF
;; @params owner
;; @returns (response bool)
(define-public (add-owner (owner principal))
    (begin
        (asserts! (is-eq tx-sender SELF) ERR-CALLER-MUST-BE-SELF)
        (asserts! (is-none (index-of (var-get owners) owner)) ERR-OWNER-ALREADY-EXISTS)
        (ok (add-owner-internal owner))
    )
)

;; A helper variable to filter owners while removing one
(define-data-var rem-owner principal tx-sender)

;; Returns a new owner list removing the given as parameter
;; @param owner
;; @returns list
(define-private (remove-owner-filter (owner principal)) (not (is-eq owner (var-get rem-owner))))

;; Removes an owner
;; @restricted to SELF
;; @params owner
;; @returns (response bool)
(define-public (remove-owner (owner principal))
    (let
        (
            (owners-list (var-get owners))
        )
        (asserts! (is-eq tx-sender SELF) ERR-CALLER-MUST-BE-SELF)
        (asserts! (is-some (index-of owners-list owner)) ERR-OWNER-NOT-EXISTS)
        (asserts! (> (len owners-list) u1) ERR-AT-LEAST-ONE-OWNER-REQUIRED)
        (asserts! (>= (- (len owners-list) u1) (var-get threshold)) ERR-THRESHOLD-OVERFLOW-OWNERS)
        (var-set rem-owner owner)
        (ok (var-set owners (unwrap-panic (as-max-len? (filter remove-owner-filter owners-list) u20))))
    )
)


;; --- Minimum confirmation threshold 

(define-data-var threshold uint u0)

;; Returns confirmation threshold
;; @returns uint 
(define-read-only (get-threshold)
    (var-get threshold)
)

;; Private function to set confirmation threshold
;; @params value
;; return bool
(define-private (set-threshold-internal (value uint))
    (var-set threshold value)
)

;; Updates minimum confirmation threshold
;; @restricted to SELF
;; @params value
;; @returns (response bool)
(define-public (set-threshold (value uint))
    (begin
        (asserts! (is-eq tx-sender SELF) ERR-CALLER-MUST-BE-SELF)
        (asserts! (> value u0) ERR-THRESHOLD-CANT-BE-ZERO)
        (asserts! (<= value u20) ERR-THRESHOLD-OVERFLOW)
        (asserts! (<= value (len (var-get owners))) ERR-THRESHOLD-OVERFLOW-OWNERS)
        (ok (set-threshold-internal value))
    )
)

;; --- Nonce

;; Incrementing number to use as id for new transactions
(define-data-var nonce uint u0)

;; Returns nonce 
;; @returns uint
(define-read-only (get-nonce)
 (var-get nonce)
)

;; Increases nonce
;; @returns bool
(define-private (increase-nonce)
    (var-set nonce (+ (var-get nonce) u1))
)


;; --- Read all basic safe information at once

(define-read-only (get-info)
    {
        version: (get-version),
        owners: (get-owners),
        threshold: (get-threshold),
        nonce: (get-nonce)
    }
)


;; --- Transactions

;; SOME NOTES ON DESIGN
;; It's not possible to get principal of an optional trait parameter using `contract-of` function.
;; Also trait references cannot be stored on clarity contracts either.
;; That's why we can't have optional `param-ft` and `param-nft` while having optional directives for `param-p`, `param-u` and `param-b`.

(define-map transactions 
    uint 
    {
        executor: principal,
        threshold: uint,
        confirmations: (list 20 principal),
        confirmed: bool,
        param-ft: principal,
        param-nft: principal,
        param-p: (optional principal),
        param-u: (optional uint),
        param-b: (optional (buff 20))
    }
)

;; Private function to insert a new transaction into transactions map
;; @params executor ; contract address to be executed
;; @params param-ft ; fungible token reference for token transfers
;; @params param-nft ; non-Fungible token reference for token transfers
;; @params param-p ; optional principal parameter to be passed to the executor function
;; @params param-u ; optional uint parameter to be passed to the executor function
;; @params param-b ; optional buffer parameter to be passed to the executor function
;; @returns uint
(define-private (add (executor <executor-trait>) (param-ft <ft-trait>) (param-nft <nft-trait>) (param-p (optional principal)) (param-u (optional uint)) (param-b (optional (buff 20))))
    (let 
        (
            (tx-id (get-nonce))
        ) 
        (map-insert transactions tx-id {
            executor: (contract-of executor),
            threshold: (var-get threshold), 
            confirmations: (list), 
            confirmed: false,
            param-ft: (contract-of param-ft),
            param-nft: (contract-of param-nft),
            param-p: param-p,
            param-u: param-u,
            param-b: param-b
        })
        (increase-nonce)
        tx-id
    )
)

;; Returns a transaction by id
;; @params tx-id ; transaction id
;; @returns tuple
(define-read-only (get-transaction (tx-id uint))
    (merge {id: tx-id} (unwrap-panic (map-get? transactions tx-id)))
)

;; Returns transactions by ids
;; @params tx-ids ; transaction id list
;; @returns list
(define-read-only (get-transactions (tx-ids (list 20 uint)))
    (map get-transaction tx-ids)
)

;; A helper variable to filter confirmations while removing one
(define-data-var rem-confirmation principal tx-sender)

;; Returns a new confirmations list removing the given as parameter
;; @param owner
;; @returns list
(define-private (remove-confirmation-filter (owner principal)) (not (is-eq owner (var-get rem-confirmation))))


;; Allows an owner to remove their confirmation on the transaction
;; @restricted to owner who confirmed the transaction before
;; @params tx-id ; transaction id
;; @returns (response bool)
(define-public (revoke (tx-id uint))
    (let 
        (
            (tx (unwrap! (map-get? transactions tx-id) ERR-TX-NOT-FOUND))
            (confirmations (get confirmations tx))
        )
        (asserts! (is-eq (get confirmed tx) false) ERR-TX-CONFIRMED)
        (asserts! (is-some (index-of confirmations tx-sender)) ERR-TX-NOT-CONFIRMED-BY-SENDER)
        (var-set rem-confirmation tx-sender)
        (let 
            (
                (new-confirmations  (unwrap-panic (as-max-len? (filter remove-confirmation-filter confirmations) u20)))
                (new-tx (merge tx {confirmations: new-confirmations}))
            )
            (map-set transactions tx-id new-tx)
            (print {action: "multisafe-revoke", sender: tx-sender, tx-id: tx-id})
            (ok true)
        )
    )
)


;; Allows an owner to confirm a tranaction. If the transaction reaches sufficient confirmation number 
;; then the executor specified on the transaction gets triggered.
;; @restricted to owners who hasn't confirmed the transaction yet
;; @params executor ; contract address to be executed
;; @params safe ; address of safe instance / SELF
;; @params param-ft ; fungible token reference for token transfers
;; @params param-nft ; non-fungible token reference for token transfers
;; @returns (response bool)
(define-public (confirm (tx-id uint) (executor <executor-trait>) (safe <safe-trait>) (param-ft <ft-trait>) (param-nft <nft-trait>))
    (begin
        (asserts! (is-some (index-of (var-get owners) tx-sender)) ERR-UNAUTHORIZED-SENDER)
        (asserts! (is-eq (contract-of safe) SELF) ERR-INVALID-SAFE) 
        (let
            (
                (tx (unwrap! (map-get? transactions tx-id) ERR-TX-NOT-FOUND))
                (confirmations (get confirmations tx))
            )

            (asserts! (is-eq (get confirmed tx) false) ERR-TX-CONFIRMED)
            (asserts! (is-none (index-of confirmations tx-sender)) ERR-TX-ALREADY-CONFIRMED-BY-OWNER)
            (asserts! (is-eq (get executor tx) (contract-of executor)) ERR-TX-INVALID-EXECUTOR)
            (asserts! (is-eq (get param-ft tx) (contract-of param-ft)) ERR-TX-INVALID-FT)
            (asserts! (is-eq (get param-nft tx) (contract-of param-nft)) ERR-TX-INVALID-NFT)
            
            (let 
                (
                    (new-confirmations (unwrap-panic (as-max-len? (append confirmations tx-sender) u20)))
                    (confirmed (>= (len new-confirmations) (get threshold tx)))
                    (new-tx (merge tx {confirmations: new-confirmations, confirmed: confirmed}))
                )
                (map-set transactions tx-id new-tx)
                (and confirmed (try! (as-contract (contract-call? executor execute safe param-ft param-nft (get param-p tx) (get param-u tx) (get param-b tx)))))
                (print {action: "multisafe-confirmation", sender: tx-sender, tx-id: tx-id, confirmed: confirmed})
                (ok confirmed)
            )
        )
    )
)

;; Allows an owner to add a new transaction and confirms it for the owner who submitted it. 
;; So, a newly submitted transaction gets one confirmation automatically. If the safe's minimum
;; required confirmation number is one then the transaction gets executed in this step.
;; @restricted to owners
;; @params executor ; contract address to be executed
;; @params safe ; address of safe instance / SELF
;; @params param-ft ; fungible token reference for token transfers
;; @params param-nft ; non-Fungible token reference for token transfers
;; @params param-p ; optional principal parameter to be passed to the executor function
;; @params param-u ; optional uint parameter to be passed to the executor function
;; @params param-u ; optional buffer parameter to be passed to the executor function
;; @returns (response uint)
(define-public (submit (executor <executor-trait>) (safe <safe-trait>) (param-ft <ft-trait>) (param-nft <nft-trait>) (param-p (optional principal)) (param-u (optional uint)) (param-b (optional (buff 20))))
    (begin
        (asserts! (is-some (index-of (var-get owners) tx-sender)) ERR-UNAUTHORIZED-SENDER)
        (asserts! (is-eq (contract-of safe) SELF) ERR-INVALID-SAFE) 
        (let
            ((tx-id (add executor param-ft param-nft param-p param-u param-b)))
            (print {action: "multisafe-submit", sender: tx-sender, tx-id: tx-id, executor: executor, param-ft: param-ft, param-nft: param-nft, param-p: param-p, param-u: param-u, param-b: param-b})
            (unwrap-panic (confirm tx-id executor safe param-ft param-nft))
            (ok tx-id)
        )
    )
)


;; Safe initializer
;; @params o ; owners list
;; @params m ; minimum required confirmation number
(define-private (init (o (list 20 principal)) (m uint))
    (begin
        (map add-owner-internal o)
        (set-threshold-internal m)
        (print {action: "multisafe-init"})
    )
)

(init (list
 'SP1GKQ1982K9X6ES07YMPVWA0WVKAQ4P4PGFGW0FC
 'SPH4DV0P21NC1Z5SJ7X4XXBR6SSWYGG6H0FGDVVC 
) u1)  