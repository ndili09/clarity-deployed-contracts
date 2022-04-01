;; drawings-megapont-apes-robots

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-non-fungible-token drawings-megapont-apes-robots uint)

;; Constants
(define-constant DEPLOYER tx-sender)
(define-constant COMM u1000)
(define-constant COMM-ADDR 'SPNWZ5V2TPWGQGVDR6T7B6RQ4XMGZ4PXTEE0VQ0S)

(define-constant ERR-NO-MORE-NFTS u100)
(define-constant ERR-NOT-ENOUGH-PASSES u101)
(define-constant ERR-PUBLIC-SALE-DISABLED u102)
(define-constant ERR-CONTRACT-INITIALIZED u103)
(define-constant ERR-NOT-AUTHORIZED u104)
(define-constant ERR-INVALID-USER u105)
(define-constant ERR-LISTING u106)
(define-constant ERR-WRONG-COMMISSION u107)
(define-constant ERR-NOT-FOUND u108)
(define-constant ERR-PAUSED u109)
(define-constant ERR-MINT-LIMIT u110)
(define-constant ERR-METADATA-FROZEN u111)
(define-constant ERR-AIRDROP-CALLED u112)
(define-constant ERR-NO-MORE-MINTS u113)

;; Internal variables
(define-data-var mint-limit uint u5)
(define-data-var last-id uint u1)
(define-data-var total-price uint u10000000)
(define-data-var artist-address principal 'SP1DS1YN0D4ANG66Z98RKRXSNV0TS136Y75CRVKK5)
(define-data-var ipfs-root (string-ascii 80) "ipfs://ipfs/QmSWRk5cuDmFwaQrCWJ2E72uQMT4sRXWfyzXAjyJzksVBs/json/")
(define-data-var mint-paused bool false)
(define-data-var premint-enabled bool false)
(define-data-var sale-enabled bool false)
(define-data-var metadata-frozen bool false)
(define-data-var airdrop-called bool false)
(define-data-var mint-cap uint u0)

(define-map mints-per-user principal uint)
(define-map mint-passes principal uint)

(define-public (claim) 
  (mint (list true)))

;; Default Minting
(define-private (mint (orders (list 25 bool)))
  (mint-many orders))

(define-private (mint-many (orders (list 25 bool )))  
  (let 
    (
      (last-nft-id (var-get last-id))
      (enabled (asserts! (<= last-nft-id (var-get mint-limit)) (err ERR-NO-MORE-NFTS)))
      (art-addr (var-get artist-address))
      (id-reached (fold mint-many-iter orders last-nft-id))
      (price (* (var-get total-price) (- id-reached last-nft-id)))
      (total-commission (/ (* price COMM) u10000))
      (current-balance (get-balance tx-sender))
      (total-artist (- price total-commission))
      (capped (> (var-get mint-cap) u0))
      (user-mints (get-mints tx-sender))
    )
    (asserts! (or (is-eq false (var-get mint-paused)) (is-eq tx-sender DEPLOYER)) (err ERR-PAUSED))
    (asserts! (or (not capped) (is-eq tx-sender DEPLOYER) (is-eq tx-sender art-addr) (>= (var-get mint-cap) (+ (len orders) user-mints))) (err ERR-NO-MORE-MINTS))
    (map-set mints-per-user tx-sender (+ (len orders) user-mints))
    (if (or (is-eq tx-sender art-addr) (is-eq tx-sender DEPLOYER) (is-eq (var-get total-price) u0000000))
      (begin
        (var-set last-id id-reached)
        (map-set token-count tx-sender (+ current-balance (- id-reached last-nft-id)))
      )
      (begin
        (var-set last-id id-reached)
        (map-set token-count tx-sender (+ current-balance (- id-reached last-nft-id)))
        (try! (stx-transfer? total-artist tx-sender (var-get artist-address)))
        (try! (stx-transfer? total-commission tx-sender COMM-ADDR))
      )    
    )
    (ok id-reached)))

(define-private (mint-many-iter (ignore bool) (next-id uint))
  (if (<= next-id (var-get mint-limit))
    (begin
      (unwrap! (nft-mint? drawings-megapont-apes-robots next-id tx-sender) next-id)
      (+ next-id u1)    
    )
    next-id))

(define-public (set-artist-address (address principal))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (ok (var-set artist-address address))))

(define-public (set-price (price uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (ok (var-set total-price price))))

(define-public (toggle-pause)
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (ok (var-set mint-paused (not (var-get mint-paused))))))

(define-public (set-mint-limit (limit uint))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-INVALID-USER))
    (asserts! (< limit (var-get mint-limit)) (err ERR-MINT-LIMIT))
    (ok (var-set mint-limit limit))))

(define-public (burn (token-id uint))
  (begin 
    (asserts! (is-owner token-id tx-sender) (err ERR-NOT-AUTHORIZED))
    (nft-burn? drawings-megapont-apes-robots token-id tx-sender)))

(define-private (is-owner (token-id uint) (user principal))
    (is-eq user (unwrap! (nft-get-owner? drawings-megapont-apes-robots token-id) false)))

(define-public (set-base-uri (new-base-uri (string-ascii 80)))
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (var-get metadata-frozen)) (err ERR-METADATA-FROZEN))
    (var-set ipfs-root new-base-uri)
    (ok true)))

(define-public (freeze-metadata)
  (begin
    (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
    (var-set metadata-frozen true)
    (ok true)))

;; Non-custodial SIP-009 transfer function
(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? market id)) (err ERR-LISTING))
    (trnsfr id sender recipient)))

;; read-only functions
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? drawings-megapont-apes-robots token-id)))

(define-read-only (get-last-token-id)
  (ok (- (var-get last-id) u1)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (concat (concat (var-get ipfs-root) "{id}") ".json"))))

(define-read-only (get-paused)
  (ok (var-get mint-paused)))

(define-read-only (get-price)
  (ok (var-get total-price)))

(define-read-only (get-mints (caller principal))
  (default-to u0 (map-get? mints-per-user caller)))

(define-read-only (get-mint-limit)
  (ok (var-get mint-limit)))

;; Non-custodial marketplace extras
(define-trait commission-trait
  ((pay (uint uint) (response bool uint))))

(define-map token-count principal uint)
(define-map market uint {price: uint, commission: principal})

(define-read-only (get-balance (account principal))
  (default-to u0
    (map-get? token-count account)))

(define-private (trnsfr (id uint) (sender principal) (recipient principal))
  (match (nft-transfer? drawings-megapont-apes-robots id sender recipient)
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
  (let ((owner (unwrap! (nft-get-owner? drawings-megapont-apes-robots id) false)))
    (or (is-eq tx-sender owner) (is-eq contract-caller owner))))

(define-read-only (get-listing-in-ustx (id uint))
  (map-get? market id))

(define-public (list-in-ustx (id uint) (price uint) (comm-trait <commission-trait>))
  (let ((listing  {price: price, commission: (contract-of comm-trait)}))
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
  (let ((owner (unwrap! (nft-get-owner? drawings-megapont-apes-robots id) (err ERR-NOT-FOUND)))
      (listing (unwrap! (map-get? market id) (err ERR-LISTING)))
      (price (get price listing)))
    (asserts! (is-eq (contract-of comm-trait) (get commission listing)) (err ERR-WRONG-COMMISSION))
    (try! (stx-transfer? price tx-sender owner))
    (try! (contract-call? comm-trait pay id price))
    (try! (trnsfr id owner tx-sender))
    (map-delete market id)
    (print {a: "buy-in-ustx", id: id})
    (ok true)))
  

;; Airdrop
(define-public (admin-airdrop)
  (let
    (
      (last-nft-id (var-get last-id))
    )
    (begin
      (asserts! (or (is-eq tx-sender (var-get artist-address)) (is-eq tx-sender DEPLOYER)) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-eq false (var-get airdrop-called)) (err ERR-AIRDROP-CALLED))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u0) 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A))
      (map-set token-count 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A (+ (get-balance 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u1) 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH))
      (map-set token-count 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH (+ (get-balance 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u2) 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1))
      (map-set token-count 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1 (+ (get-balance 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u3) 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K))
      (map-set token-count 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K (+ (get-balance 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u4) 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80))
      (map-set token-count 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80 (+ (get-balance 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u5) 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A))
      (map-set token-count 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A (+ (get-balance 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u6) 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH))
      (map-set token-count 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH (+ (get-balance 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u7) 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1))
      (map-set token-count 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1 (+ (get-balance 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u8) 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K))
      (map-set token-count 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K (+ (get-balance 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u9) 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80))
      (map-set token-count 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80 (+ (get-balance 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u10) 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A))
      (map-set token-count 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A (+ (get-balance 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u11) 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH))
      (map-set token-count 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH (+ (get-balance 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u12) 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1))
      (map-set token-count 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1 (+ (get-balance 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u13) 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K))
      (map-set token-count 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K (+ (get-balance 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u14) 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80))
      (map-set token-count 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80 (+ (get-balance 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u15) 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A))
      (map-set token-count 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A (+ (get-balance 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u16) 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH))
      (map-set token-count 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH (+ (get-balance 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u17) 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1))
      (map-set token-count 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1 (+ (get-balance 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u18) 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K))
      (map-set token-count 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K (+ (get-balance 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u19) 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80))
      (map-set token-count 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80 (+ (get-balance 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u20) 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A))
      (map-set token-count 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A (+ (get-balance 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u21) 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH))
      (map-set token-count 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH (+ (get-balance 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u22) 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1))
      (map-set token-count 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1 (+ (get-balance 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u23) 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K))
      (map-set token-count 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K (+ (get-balance 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u24) 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80))
      (map-set token-count 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80 (+ (get-balance 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u25) 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A))
      (map-set token-count 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A (+ (get-balance 'SP2F40S465JTD7AMZ2X9SMN229617HZ9YB0HHY98A) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u26) 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH))
      (map-set token-count 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH (+ (get-balance 'SP2HV9HYWZRAPTCC10VXCK72P3W4F9NDB8E1HBEZH) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u27) 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1))
      (map-set token-count 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1 (+ (get-balance 'SPZ5DJGRVZHXEEEYYGWEX84KQB8P69GC715ZRNW1) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u28) 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K))
      (map-set token-count 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K (+ (get-balance 'SP1P94TYSJZ25849PHEBR5Y4J9BCW8MJMZCE0TD4K) u1))
      (try! (nft-mint? drawings-megapont-apes-robots (+ last-nft-id u29) 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80))
      (map-set token-count 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80 (+ (get-balance 'SP2VJG4K68TCF1FQ67N1CE9MFJMJ008VKG5HY9S80) u1))

      (var-set last-id (+ last-nft-id u30))
      (var-set airdrop-called true)
      (ok true))))