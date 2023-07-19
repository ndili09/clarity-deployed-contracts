;; $TEST FT Contract
;; This contract represents the $TEST FT - the fungible token for the CrashPunks metaverse.
;; Written by StrataLabs

;; $TEST FT Unique Properties
;; 1. Minting is only allowed by the staking contract

(impl-trait .ft-trait.sip-010-trait)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Cons, Vars, & Maps ;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant contract-owner tx-sender)
(define-constant TOKEN_NAME "TEST")
(define-constant TOKEN_SYMBOL "TST")
(define-constant TOKEN_DECIMALS u6)
(define-constant TOKEN_MAX_SUPPLY u100000000000000)

;;;;;;;;;;;;;;;;;;;
;; FT Vars/Cons ;;
;;;;;;;;;;;;;;;;;;;

(define-fungible-token TEST TOKEN_MAX_SUPPLY)
(define-data-var activate-transfer bool false)
(define-data-var TOKEN_URI (optional (string-utf8 256)) (some u"https://gateway.pinata.cloud/ipfs/QmSAm2phKjR28DpE6vdejpQgXLg9wLKZs4WE6cqvE7gyww"))

;;;;;;;;;;;;;;;;
;; Error Cons ;;
;;;;;;;;;;;;;;;;

(define-constant ERR_SENDER_NOT_VALID (err u1000))
(define-constant ERR_SENDER_AND_RECIPENT_IS_EQUAL (err u1001))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u1002))
(define-constant ERR_GETING_BALANCE_OF_SENDER (err u1003))
(define-constant ERR_SENDER_BALANCE_NOT_VALID (err u1004))
(define-constant ERR_NOT_ALLOWED (err u1005))
(define-constant ERR_RECIPIENT_NOT_VALID (err u1006))
(define-constant ERR_TRANSFER_NOT_ACTIVATED (err u1007))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; SIP10 Functions ;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Regular transfer function for SIP-010 but we need to activita the transfer function before being able to actually transfer
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin

    ;; assert sender is tx-sender
    (asserts! (is-eq tx-sender sender) ERR_SENDER_NOT_VALID)

    ;; assert sender is not recipient
    (asserts! (not (is-eq sender recipient)) ERR_SENDER_AND_RECIPENT_IS_EQUAL)

    ;; assert amount transferred > 0
    (asserts! (> amount u0) ERR_INSUFFICIENT_AMOUNT)

    ;; assert amount transferred =< balance of sender
    (asserts! (<= amount (unwrap! (get-balance sender) ERR_GETING_BALANCE_OF_SENDER)) ERR_SENDER_BALANCE_NOT_VALID)

    ;; assert the transfer function is activated
    (asserts! (var-get activate-transfer) ERR_TRANSFER_NOT_ACTIVATED)

    ;; transfer
    (try! (ft-transfer? TEST amount sender recipient))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

(define-public (change-transfer-state) 
 (begin
  (asserts! (is-eq tx-sender contract-owner) (err u100))
  (ok (var-set activate-transfer true))
 )
)

(define-public (update-token-uri (new-uri (optional (string-utf8 256))))
  (begin 
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (ok (var-set TOKEN_URI new-uri))
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Read Functions ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-read-only (get-name)
  (ok TOKEN_NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance TEST account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply TEST))
)

(define-read-only (get-token-uri)
  (ok (var-get TOKEN_URI))
)

(define-read-only (get-max-supply)
  (ok TOKEN_MAX_SUPPLY)
)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Mint Functions ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Regular SIP-010 mint function, except this is only callable by the CrashPunks staking contract or admin
(define-public (mint (amount uint) (recipient principal))
  (let
    (
      (current-total-supply (ft-get-supply TEST))
    )

    ;; asserts that caller is either admin(?) or staking contract
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq contract-caller .staking)) (err u3))


    ;; asserts that recipient is not staking contract
    (asserts! (not (is-eq recipient .staking)) ERR_RECIPIENT_NOT_VALID)

    ;; asserts that amount is greater than 0
    (asserts! (> amount u0) ERR_INSUFFICIENT_AMOUNT)

    ;; asserts that amount is less than
    (asserts! (<= amount (- TOKEN_MAX_SUPPLY current-total-supply)) ERR_NOT_ALLOWED)
    (ft-mint? TEST amount recipient)
  )
)

(ft-mint? TEST u10000 'SP3D03X5BHMNSAAW71NN7BQRMV4DW2G4JB3MZAGJ8)

(define-public (burn (amount uint) (sender principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_SENDER_NOT_VALID)
    (asserts! (> amount u0) ERR_INSUFFICIENT_AMOUNT)
    (asserts! (<= amount (ft-get-balance TEST sender)) ERR_SENDER_BALANCE_NOT_VALID)
    (ft-burn? TEST amount sender)
  )
)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;; Admin Functions ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

