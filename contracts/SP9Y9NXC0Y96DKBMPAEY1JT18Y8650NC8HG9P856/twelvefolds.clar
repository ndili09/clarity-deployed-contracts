;; twelvefolds
;; contractType: continuous

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
;;(impl-trait .nft-trait.nft-trait)

(define-non-fungible-token twelvefolds uint)

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
(define-data-var artist-address principal 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856)
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
    (nft-burn? twelvefolds token-id tx-sender)))

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
    (is-eq user (unwrap! (nft-get-owner? twelvefolds token-id) false)))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? market id)) (err ERR-LISTING))
    (trnsfr id sender recipient)))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? twelvefolds token-id)))

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
    (unwrap! (nft-mint? twelvefolds next-id tx-sender) next-id)
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
  (match (nft-transfer? twelvefolds id sender recipient)
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
  (let ((owner (unwrap! (nft-get-owner? twelvefolds id) false)))
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
  (let ((owner (unwrap! (nft-get-owner? twelvefolds id) (err ERR-NOT-FOUND)))
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

(try! (nft-mint? twelvefolds u1 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u1 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/1.json")
(try! (nft-mint? twelvefolds u2 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u2 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/2.json")
(try! (nft-mint? twelvefolds u3 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u3 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/3.json")
(try! (nft-mint? twelvefolds u4 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u4 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/4.json")
(try! (nft-mint? twelvefolds u5 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u5 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/5.json")
(try! (nft-mint? twelvefolds u6 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u6 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/6.json")
(try! (nft-mint? twelvefolds u7 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u7 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/7.json")
(try! (nft-mint? twelvefolds u8 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u8 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/8.json")
(try! (nft-mint? twelvefolds u9 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u9 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/9.json")
(try! (nft-mint? twelvefolds u10 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u10 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/10.json")
(try! (nft-mint? twelvefolds u11 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u11 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/11.json")
(try! (nft-mint? twelvefolds u12 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u12 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/12.json")
(try! (nft-mint? twelvefolds u13 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u13 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/13.json")
(try! (nft-mint? twelvefolds u14 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u14 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/14.json")
(try! (nft-mint? twelvefolds u15 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u15 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/15.json")
(try! (nft-mint? twelvefolds u16 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u16 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/16.json")
(try! (nft-mint? twelvefolds u17 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u17 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/17.json")
(try! (nft-mint? twelvefolds u18 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u18 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/18.json")
(try! (nft-mint? twelvefolds u19 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u19 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/19.json")
(try! (nft-mint? twelvefolds u20 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u20 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/20.json")
(try! (nft-mint? twelvefolds u21 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u21 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/21.json")
(try! (nft-mint? twelvefolds u22 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u22 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/22.json")
(try! (nft-mint? twelvefolds u23 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u23 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/23.json")
(try! (nft-mint? twelvefolds u24 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u24 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/24.json")
(try! (nft-mint? twelvefolds u25 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u25 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/25.json")
(try! (nft-mint? twelvefolds u26 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u26 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/26.json")
(try! (nft-mint? twelvefolds u27 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u27 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/27.json")
(try! (nft-mint? twelvefolds u28 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u28 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/28.json")
(try! (nft-mint? twelvefolds u29 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u29 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/29.json")
(try! (nft-mint? twelvefolds u30 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u30 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/30.json")
(try! (nft-mint? twelvefolds u31 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u31 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/31.json")
(try! (nft-mint? twelvefolds u32 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u32 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/32.json")
(try! (nft-mint? twelvefolds u33 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u33 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/33.json")
(try! (nft-mint? twelvefolds u34 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u34 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/34.json")
(try! (nft-mint? twelvefolds u35 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u35 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/35.json")
(try! (nft-mint? twelvefolds u36 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u36 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/36.json")
(try! (nft-mint? twelvefolds u37 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u37 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/37.json")
(try! (nft-mint? twelvefolds u38 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u38 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/38.json")
(try! (nft-mint? twelvefolds u39 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u39 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/39.json")
(try! (nft-mint? twelvefolds u40 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u40 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/40.json")
(try! (nft-mint? twelvefolds u41 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u41 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/41.json")
(try! (nft-mint? twelvefolds u42 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u42 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/42.json")
(try! (nft-mint? twelvefolds u43 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u43 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/43.json")
(try! (nft-mint? twelvefolds u44 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u44 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/44.json")
(try! (nft-mint? twelvefolds u45 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u45 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/45.json")
(try! (nft-mint? twelvefolds u46 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u46 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/46.json")
(try! (nft-mint? twelvefolds u47 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u47 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/47.json")
(try! (nft-mint? twelvefolds u48 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u48 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/48.json")
(try! (nft-mint? twelvefolds u49 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u49 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/49.json")
(try! (nft-mint? twelvefolds u50 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856))
(map-set token-count 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856 (+ (get-balance 'SP9Y9NXC0Y96DKBMPAEY1JT18Y8650NC8HG9P856) u1))
(map-set cids u50 "QmZsrRzn5BZouQSS4hP5NAaSVRm4top3j7892bGZmxdUdN/json/50.json")
(var-set last-id u50)

(define-data-var license-uri (string-ascii 80) "")
(define-data-var license-name (string-ascii 40) "")

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