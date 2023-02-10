;; ordinal-phunks
;; contractType: continuous

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
;;(impl-trait .nft-trait.nft-trait)

(define-non-fungible-token ordinal-phunks uint)

(define-constant DEPLOYER tx-sender)

(define-constant ERR-NOT-AUTHORIZED u101)
(define-constant ERR-INVALID-USER u102)
(define-constant ERR-LISTING u103)
(define-constant ERR-WRONG-COMMISSION u104)
(define-constant ERR-NOT-FOUND u105)
(define-constant ERR-NFT-MINT u106)
(define-constant ERR-CONTRACT-LOCKED u107)
(define-constant ERR-METADATA-FROZEN u111)
(define-constant ERR-INVALID-PERCENTAGE u114)

(define-data-var last-id uint u0)
(define-data-var artist-address principal 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4)
(define-data-var locked bool false)
(define-data-var metadata-frozen bool false)

(define-map cids uint (string-ascii 64))

(define-public (lock-contract)
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (var-set locked true)
    (ok true)))

(define-public (set-artist-address (address principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (ok (var-set artist-address address))))

(define-public (burn (token-id uint))
  (begin 
    (asserts! (is-owner token-id tx-sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? market token-id)) (err ERR-LISTING))
    (nft-burn? ordinal-phunks token-id tx-sender)))

(define-public (set-token-uri (hash (string-ascii 64)) (token-id uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (var-get metadata-frozen)) (err ERR-METADATA-FROZEN))
    (print { notification: "token-metadata-update", payload: { token-class: "nft", token-ids: (list token-id), contract-id: (as-contract tx-sender) }})
    (map-set cids token-id hash)
    (ok true)))

(define-public (freeze-metadata)
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (var-set metadata-frozen true)
    (ok true)))

(define-private (is-owner (token-id uint) (user principal))
    (is-eq user (unwrap! (nft-get-owner? ordinal-phunks token-id) false)))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? market id)) (err ERR-LISTING))
    (trnsfr id sender recipient)))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? ordinal-phunks token-id)))

(define-read-only (get-last-token-id)
  (ok (var-get last-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat "ipfs://" (unwrap-panic (map-get? cids token-id))))))

(define-read-only (get-artist-address)
  (ok (var-get artist-address)))

(define-public (claim (uris (list 25 (string-ascii 64))))
  (mint-many uris))

(define-private (mint-many (uris (list 25 (string-ascii 64))))
  (let 
    (
      (token-id (+ (var-get last-id) u1))
      (art-addr (var-get artist-address))
      (id-reached (fold mint-many-iter uris token-id))
      (current-balance (get-balance tx-sender))
    )
    (asserts! (or (is-eq tx-sender DEPLOYER) (is-eq tx-sender art-addr)) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-eq (var-get locked) false) (err ERR-CONTRACT-LOCKED))
    (var-set last-id (- id-reached u1))
    (map-set token-count tx-sender (+ current-balance (- id-reached token-id)))    
    (ok id-reached)))

(define-private (mint-many-iter (hash (string-ascii 64)) (next-id uint))
  (begin
    (unwrap! (nft-mint? ordinal-phunks next-id tx-sender) next-id)
    (map-set cids next-id hash)      
    (+ next-id u1)))

;; NON-CUSTODIAL FUNCTIONS START
(use-trait commission-trait 'SP3D6PV2ACBPEKYJTCMH7HEN02KP87QSP8KTEH335.commission-trait.commission)

(define-map token-count principal uint)
(define-map market uint {price: uint, commission: principal, royalty: uint})

(define-read-only (get-balance (account principal))
  (default-to u0
    (map-get? token-count account)))

(define-private (trnsfr (id uint) (sender principal) (recipient principal))
  (match (nft-transfer? ordinal-phunks id sender recipient)
    success
      (let
        ((sender-balance (get-balance sender))
        (recipient-balance (get-balance recipient)))
          (map-set token-count
            sender
            (- sender-balance u1))
          (map-set token-count
            recipient
            (+ recipient-balance u1))
          (ok success))
    error (err error)))

(define-private (is-sender-owner (id uint))
  (let ((owner (unwrap! (nft-get-owner? ordinal-phunks id) false)))
    (or (is-eq tx-sender owner) (is-eq contract-caller owner))))

(define-read-only (get-listing-in-ustx (id uint))
  (map-get? market id))

(define-public (list-in-ustx (id uint) (price uint) (comm-trait <commission-trait>))
  (let ((listing  {price: price, commission: (contract-of comm-trait), royalty: (var-get royalty-percent)}))
    (asserts! (is-sender-owner id) (err ERR-NOT-AUTHORIZED))
    (map-set market id listing)
    (print (merge listing {a: "list-in-ustx", id: id}))
    (ok true)))

(define-public (unlist-in-ustx (id uint))
  (begin
    (asserts! (is-sender-owner id) (err ERR-NOT-AUTHORIZED))
    (map-delete market id)
    (print {a: "unlist-in-ustx", id: id})
    (ok true)))

(define-public (buy-in-ustx (id uint) (comm-trait <commission-trait>))
  (let ((owner (unwrap! (nft-get-owner? ordinal-phunks id) (err ERR-NOT-FOUND)))
      (listing (unwrap! (map-get? market id) (err ERR-LISTING)))
      (price (get price listing))
      (royalty (get royalty listing)))
    (asserts! (is-eq (contract-of comm-trait) (get commission listing)) (err ERR-WRONG-COMMISSION))
    (try! (stx-transfer? price tx-sender owner))
    (try! (pay-royalty price royalty))
    (try! (contract-call? comm-trait pay id price))
    (try! (trnsfr id owner tx-sender))
    (map-delete market id)
    (print {a: "buy-in-ustx", id: id})
    (ok true)))
    
(define-data-var royalty-percent uint u500)

(define-read-only (get-royalty-percent)
  (ok (var-get royalty-percent)))

(define-public (set-royalty-percent (royalty uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (asserts! (and (>= royalty u0) (<= royalty u1000)) (err ERR-INVALID-PERCENTAGE))
    (ok (var-set royalty-percent royalty))))

(define-private (pay-royalty (price uint) (royalty uint))
  (let (
    (royalty-amount (/ (* price royalty) u10000))
  )
  (if (and (> royalty-amount u0) (not (is-eq tx-sender (var-get artist-address))))
    (try! (stx-transfer? royalty-amount tx-sender (var-get artist-address)))
    (print false)
  )
  (ok true)))

;; NON-CUSTODIAL FUNCTIONS END

(try! (nft-mint? ordinal-phunks u1 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u1 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/1.json")
(try! (nft-mint? ordinal-phunks u2 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u2 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/2.json")
(try! (nft-mint? ordinal-phunks u3 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u3 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/3.json")
(try! (nft-mint? ordinal-phunks u4 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u4 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/4.json")
(try! (nft-mint? ordinal-phunks u5 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u5 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/5.json")
(try! (nft-mint? ordinal-phunks u6 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u6 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/6.json")
(try! (nft-mint? ordinal-phunks u7 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u7 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/7.json")
(try! (nft-mint? ordinal-phunks u8 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u8 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/8.json")
(try! (nft-mint? ordinal-phunks u9 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u9 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/9.json")
(try! (nft-mint? ordinal-phunks u10 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u10 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/10.json")
(try! (nft-mint? ordinal-phunks u11 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u11 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/11.json")
(try! (nft-mint? ordinal-phunks u12 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u12 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/12.json")
(try! (nft-mint? ordinal-phunks u13 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u13 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/13.json")
(try! (nft-mint? ordinal-phunks u14 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u14 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/14.json")
(try! (nft-mint? ordinal-phunks u15 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u15 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/15.json")
(try! (nft-mint? ordinal-phunks u16 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u16 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/16.json")
(try! (nft-mint? ordinal-phunks u17 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u17 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/17.json")
(try! (nft-mint? ordinal-phunks u18 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u18 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/18.json")
(try! (nft-mint? ordinal-phunks u19 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u19 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/19.json")
(try! (nft-mint? ordinal-phunks u20 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u20 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/20.json")
(try! (nft-mint? ordinal-phunks u21 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u21 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/21.json")
(try! (nft-mint? ordinal-phunks u22 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u22 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/22.json")
(try! (nft-mint? ordinal-phunks u23 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u23 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/23.json")
(try! (nft-mint? ordinal-phunks u24 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u24 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/24.json")
(try! (nft-mint? ordinal-phunks u25 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u25 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/25.json")
(try! (nft-mint? ordinal-phunks u26 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u26 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/26.json")
(try! (nft-mint? ordinal-phunks u27 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u27 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/27.json")
(try! (nft-mint? ordinal-phunks u28 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u28 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/28.json")
(try! (nft-mint? ordinal-phunks u29 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u29 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/29.json")
(try! (nft-mint? ordinal-phunks u30 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u30 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/30.json")
(try! (nft-mint? ordinal-phunks u31 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u31 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/31.json")
(try! (nft-mint? ordinal-phunks u32 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u32 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/32.json")
(try! (nft-mint? ordinal-phunks u33 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u33 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/33.json")
(try! (nft-mint? ordinal-phunks u34 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u34 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/34.json")
(try! (nft-mint? ordinal-phunks u35 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u35 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/35.json")
(try! (nft-mint? ordinal-phunks u36 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u36 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/36.json")
(try! (nft-mint? ordinal-phunks u37 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u37 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/37.json")
(try! (nft-mint? ordinal-phunks u38 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u38 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/38.json")
(try! (nft-mint? ordinal-phunks u39 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u39 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/39.json")
(try! (nft-mint? ordinal-phunks u40 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u40 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/40.json")
(try! (nft-mint? ordinal-phunks u41 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u41 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/41.json")
(try! (nft-mint? ordinal-phunks u42 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u42 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/42.json")
(try! (nft-mint? ordinal-phunks u43 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u43 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/43.json")
(try! (nft-mint? ordinal-phunks u44 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u44 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/44.json")
(try! (nft-mint? ordinal-phunks u45 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u45 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/45.json")
(try! (nft-mint? ordinal-phunks u46 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u46 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/46.json")
(try! (nft-mint? ordinal-phunks u47 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u47 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/47.json")
(try! (nft-mint? ordinal-phunks u48 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u48 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/48.json")
(try! (nft-mint? ordinal-phunks u49 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u49 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/49.json")
(try! (nft-mint? ordinal-phunks u50 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u50 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/50.json")
(try! (nft-mint? ordinal-phunks u51 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u51 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/51.json")
(try! (nft-mint? ordinal-phunks u52 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u52 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/52.json")
(try! (nft-mint? ordinal-phunks u53 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u53 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/53.json")
(try! (nft-mint? ordinal-phunks u54 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u54 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/54.json")
(try! (nft-mint? ordinal-phunks u55 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u55 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/55.json")
(try! (nft-mint? ordinal-phunks u56 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u56 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/56.json")
(try! (nft-mint? ordinal-phunks u57 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u57 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/57.json")
(try! (nft-mint? ordinal-phunks u58 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u58 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/58.json")
(try! (nft-mint? ordinal-phunks u59 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u59 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/59.json")
(try! (nft-mint? ordinal-phunks u60 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u60 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/60.json")
(try! (nft-mint? ordinal-phunks u61 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u61 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/61.json")
(try! (nft-mint? ordinal-phunks u62 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u62 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/62.json")
(try! (nft-mint? ordinal-phunks u63 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u63 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/63.json")
(try! (nft-mint? ordinal-phunks u64 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u64 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/64.json")
(try! (nft-mint? ordinal-phunks u65 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u65 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/65.json")
(try! (nft-mint? ordinal-phunks u66 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u66 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/66.json")
(try! (nft-mint? ordinal-phunks u67 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u67 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/67.json")
(try! (nft-mint? ordinal-phunks u68 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u68 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/68.json")
(try! (nft-mint? ordinal-phunks u69 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u69 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/69.json")
(try! (nft-mint? ordinal-phunks u70 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u70 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/70.json")
(try! (nft-mint? ordinal-phunks u71 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u71 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/71.json")
(try! (nft-mint? ordinal-phunks u72 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u72 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/72.json")
(try! (nft-mint? ordinal-phunks u73 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u73 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/73.json")
(try! (nft-mint? ordinal-phunks u74 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u74 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/74.json")
(try! (nft-mint? ordinal-phunks u75 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u75 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/75.json")
(try! (nft-mint? ordinal-phunks u76 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u76 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/76.json")
(try! (nft-mint? ordinal-phunks u77 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u77 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/77.json")
(try! (nft-mint? ordinal-phunks u78 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u78 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/78.json")
(try! (nft-mint? ordinal-phunks u79 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u79 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/79.json")
(try! (nft-mint? ordinal-phunks u80 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u80 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/80.json")
(try! (nft-mint? ordinal-phunks u81 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u81 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/81.json")
(try! (nft-mint? ordinal-phunks u82 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u82 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/82.json")
(try! (nft-mint? ordinal-phunks u83 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u83 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/83.json")
(try! (nft-mint? ordinal-phunks u84 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u84 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/84.json")
(try! (nft-mint? ordinal-phunks u85 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u85 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/85.json")
(try! (nft-mint? ordinal-phunks u86 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u86 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/86.json")
(try! (nft-mint? ordinal-phunks u87 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u87 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/87.json")
(try! (nft-mint? ordinal-phunks u88 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u88 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/88.json")
(try! (nft-mint? ordinal-phunks u89 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u89 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/89.json")
(try! (nft-mint? ordinal-phunks u90 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u90 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/90.json")
(try! (nft-mint? ordinal-phunks u91 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u91 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/91.json")
(try! (nft-mint? ordinal-phunks u92 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u92 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/92.json")
(try! (nft-mint? ordinal-phunks u93 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u93 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/93.json")
(try! (nft-mint? ordinal-phunks u94 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u94 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/94.json")
(try! (nft-mint? ordinal-phunks u95 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u95 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/95.json")
(try! (nft-mint? ordinal-phunks u96 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u96 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/96.json")
(try! (nft-mint? ordinal-phunks u97 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u97 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/97.json")
(try! (nft-mint? ordinal-phunks u98 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u98 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/98.json")
(try! (nft-mint? ordinal-phunks u99 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u99 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/99.json")
(try! (nft-mint? ordinal-phunks u100 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4))
(map-set token-count 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4 (+ (get-balance 'SP1T02D65RCFSN6A7FSMJ8F8VCN7KATFV6H782BD4) u1))
(map-set cids u100 "QmdrUtvno9ToQ7iZGgvPN7syLdCwgc3hRK48UhkqphVGMM/json/100.json")
(var-set last-id u100)

(define-data-var license-uri (string-ascii 80) "https://arweave.net/zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/0")
(define-data-var license-name (string-ascii 40) "PUBLIC")

(define-read-only (get-license-uri)
  (ok (var-get license-uri)))
  
(define-read-only (get-license-name)
  (ok (var-get license-name)))
  
(define-public (set-license-uri (uri (string-ascii 80)))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set license-uri uri))))
    
(define-public (set-license-name (name (string-ascii 40)))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set license-name name))))