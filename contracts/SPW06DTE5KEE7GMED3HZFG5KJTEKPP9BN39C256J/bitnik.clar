;; bitnik
;; contractType: continuous

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
;;(impl-trait .nft-trait.nft-trait)

(define-non-fungible-token bitnik uint)

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
(define-data-var artist-address principal 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J)
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
    (nft-burn? bitnik token-id tx-sender)))

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
    (is-eq user (unwrap! (nft-get-owner? bitnik token-id) false)))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? market id)) (err ERR-LISTING))
    (trnsfr id sender recipient)))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? bitnik token-id)))

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
    (unwrap! (nft-mint? bitnik next-id tx-sender) next-id)
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
  (match (nft-transfer? bitnik id sender recipient)
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
  (let ((owner (unwrap! (nft-get-owner? bitnik id) false)))
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
  (let ((owner (unwrap! (nft-get-owner? bitnik id) (err ERR-NOT-FOUND)))
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

(try! (nft-mint? bitnik u1 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u1 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/1.json")
(try! (nft-mint? bitnik u2 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u2 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/2.json")
(try! (nft-mint? bitnik u3 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u3 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/3.json")
(try! (nft-mint? bitnik u4 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u4 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/4.json")
(try! (nft-mint? bitnik u5 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u5 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/5.json")
(try! (nft-mint? bitnik u6 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u6 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/6.json")
(try! (nft-mint? bitnik u7 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u7 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/7.json")
(try! (nft-mint? bitnik u8 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u8 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/8.json")
(try! (nft-mint? bitnik u9 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u9 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/9.json")
(try! (nft-mint? bitnik u10 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u10 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/10.json")
(try! (nft-mint? bitnik u11 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u11 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/11.json")
(try! (nft-mint? bitnik u12 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u12 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/12.json")
(try! (nft-mint? bitnik u13 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u13 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/13.json")
(try! (nft-mint? bitnik u14 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u14 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/14.json")
(try! (nft-mint? bitnik u15 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u15 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/15.json")
(try! (nft-mint? bitnik u16 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u16 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/16.json")
(try! (nft-mint? bitnik u17 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u17 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/17.json")
(try! (nft-mint? bitnik u18 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u18 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/18.json")
(try! (nft-mint? bitnik u19 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u19 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/19.json")
(try! (nft-mint? bitnik u20 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u20 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/20.json")
(try! (nft-mint? bitnik u21 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u21 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/21.json")
(try! (nft-mint? bitnik u22 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u22 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/22.json")
(try! (nft-mint? bitnik u23 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u23 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/23.json")
(try! (nft-mint? bitnik u24 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u24 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/24.json")
(try! (nft-mint? bitnik u25 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u25 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/25.json")
(try! (nft-mint? bitnik u26 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u26 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/26.json")
(try! (nft-mint? bitnik u27 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u27 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/27.json")
(try! (nft-mint? bitnik u28 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u28 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/28.json")
(try! (nft-mint? bitnik u29 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u29 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/29.json")
(try! (nft-mint? bitnik u30 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u30 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/30.json")
(try! (nft-mint? bitnik u31 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u31 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/31.json")
(try! (nft-mint? bitnik u32 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u32 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/32.json")
(try! (nft-mint? bitnik u33 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u33 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/33.json")
(try! (nft-mint? bitnik u34 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u34 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/34.json")
(try! (nft-mint? bitnik u35 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u35 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/35.json")
(try! (nft-mint? bitnik u36 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u36 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/36.json")
(try! (nft-mint? bitnik u37 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u37 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/37.json")
(try! (nft-mint? bitnik u38 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u38 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/38.json")
(try! (nft-mint? bitnik u39 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u39 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/39.json")
(try! (nft-mint? bitnik u40 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u40 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/40.json")
(try! (nft-mint? bitnik u41 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u41 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/41.json")
(try! (nft-mint? bitnik u42 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u42 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/42.json")
(try! (nft-mint? bitnik u43 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u43 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/43.json")
(try! (nft-mint? bitnik u44 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u44 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/44.json")
(try! (nft-mint? bitnik u45 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u45 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/45.json")
(try! (nft-mint? bitnik u46 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u46 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/46.json")
(try! (nft-mint? bitnik u47 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u47 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/47.json")
(try! (nft-mint? bitnik u48 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u48 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/48.json")
(try! (nft-mint? bitnik u49 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u49 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/49.json")
(try! (nft-mint? bitnik u50 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u50 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/50.json")
(try! (nft-mint? bitnik u51 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u51 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/51.json")
(try! (nft-mint? bitnik u52 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u52 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/52.json")
(try! (nft-mint? bitnik u53 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u53 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/53.json")
(try! (nft-mint? bitnik u54 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u54 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/54.json")
(try! (nft-mint? bitnik u55 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u55 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/55.json")
(try! (nft-mint? bitnik u56 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u56 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/56.json")
(try! (nft-mint? bitnik u57 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u57 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/57.json")
(try! (nft-mint? bitnik u58 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u58 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/58.json")
(try! (nft-mint? bitnik u59 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u59 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/59.json")
(try! (nft-mint? bitnik u60 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u60 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/60.json")
(try! (nft-mint? bitnik u61 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u61 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/61.json")
(try! (nft-mint? bitnik u62 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u62 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/62.json")
(try! (nft-mint? bitnik u63 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u63 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/63.json")
(try! (nft-mint? bitnik u64 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u64 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/64.json")
(try! (nft-mint? bitnik u65 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u65 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/65.json")
(try! (nft-mint? bitnik u66 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u66 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/66.json")
(try! (nft-mint? bitnik u67 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u67 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/67.json")
(try! (nft-mint? bitnik u68 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u68 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/68.json")
(try! (nft-mint? bitnik u69 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u69 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/69.json")
(try! (nft-mint? bitnik u70 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u70 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/70.json")
(try! (nft-mint? bitnik u71 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u71 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/71.json")
(try! (nft-mint? bitnik u72 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u72 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/72.json")
(try! (nft-mint? bitnik u73 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u73 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/73.json")
(try! (nft-mint? bitnik u74 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u74 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/74.json")
(try! (nft-mint? bitnik u75 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u75 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/75.json")
(try! (nft-mint? bitnik u76 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u76 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/76.json")
(try! (nft-mint? bitnik u77 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u77 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/77.json")
(try! (nft-mint? bitnik u78 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u78 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/78.json")
(try! (nft-mint? bitnik u79 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u79 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/79.json")
(try! (nft-mint? bitnik u80 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u80 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/80.json")
(try! (nft-mint? bitnik u81 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u81 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/81.json")
(try! (nft-mint? bitnik u82 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u82 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/82.json")
(try! (nft-mint? bitnik u83 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u83 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/83.json")
(try! (nft-mint? bitnik u84 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u84 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/84.json")
(try! (nft-mint? bitnik u85 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u85 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/85.json")
(try! (nft-mint? bitnik u86 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u86 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/86.json")
(try! (nft-mint? bitnik u87 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u87 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/87.json")
(try! (nft-mint? bitnik u88 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u88 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/88.json")
(try! (nft-mint? bitnik u89 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u89 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/89.json")
(try! (nft-mint? bitnik u90 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u90 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/90.json")
(try! (nft-mint? bitnik u91 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u91 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/91.json")
(try! (nft-mint? bitnik u92 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u92 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/92.json")
(try! (nft-mint? bitnik u93 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u93 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/93.json")
(try! (nft-mint? bitnik u94 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u94 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/94.json")
(try! (nft-mint? bitnik u95 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u95 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/95.json")
(try! (nft-mint? bitnik u96 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u96 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/96.json")
(try! (nft-mint? bitnik u97 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u97 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/97.json")
(try! (nft-mint? bitnik u98 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u98 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/98.json")
(try! (nft-mint? bitnik u99 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u99 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/99.json")
(try! (nft-mint? bitnik u100 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J))
(map-set token-count 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J (+ (get-balance 'SPW06DTE5KEE7GMED3HZFG5KJTEKPP9BN39C256J) u1))
(map-set cids u100 "QmRpyVu1VrvQBhXzZfihKMHpLVq7fagA5AnCoXB8veKHwy/json/100.json")
(var-set last-id u100)

(define-data-var license-uri (string-ascii 80) "https://arweave.net/zmc1WTspIhFyVY82bwfAIcIExLFH5lUcHHUN0wXg4W8/5")
(define-data-var license-name (string-ascii 40) "PERSONAL-NO-HATE")

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