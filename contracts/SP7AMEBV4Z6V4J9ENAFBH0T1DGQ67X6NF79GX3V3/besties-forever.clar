;;                         .::-======-:.               .:--=====-:.                         
;;                     :=+++++++***#####*=:      :-=++++++++***####*=.                     
;;                   .=*++++++++++***####%%%#+-:+***++++++++++***###%%%#:                   
;;                 =**+++++++++++***####%%%%####***++++++++++***###%%%%@*                  
;;                 +#***+++++++++***####%%%%%%####***++++++++***###%%%%%@@#                 
;;                -###****+++++****####%%%%%%%%####*****++*****####%%%%%@@@=                
;;                *#####*********#####%%%%%%%%%%#####********####%%%%%%@@@@#                
;;                #%%###############%%%%%%%%%%%%%%%############%%%%%%%@@@@@%                
;;                #%%%%%%#######%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@@@@@@%                
;;                =%%%%%%%%%%%%%%%%%%%%%%@@@@@%%%%%%%%%%%%%%%%%%%%@@@@@@@@@+                
;;                .%%%%%%%%%%%%%%%%%%@@@@@@@@@@@@@@%%%%%%%%%%%@@@@@@@@@@@@@.                
;;                 +@@@%%%%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+                 
;;                  #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#                  
;;                   #@@@@@@@@@@@@@@@@@@@@-SOULBOUND-@@@@@@@@@@@@@@@@@@@#                   
;;                    *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*                    
;;                     -%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@=                     
;;                       +@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*.                      
;;                        .+@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*.                        
;;                          .+@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+.                          
;;                             =#@@@@@@@@@@@@@@@@@@@@@@@@@@@@%=                             
;;                               .+%@@@@@@@@@@@@@@@@@@@@@@%+:                               
;;                                  :+%@@@@@@@@@@@@@@@@%+:                                  
;;                                     .=*@@@@@@@@@@*=.                                     
;;                                         :=*%%*=:                                                                                                                                                                                                                  


(impl-trait .nft-trait.nft-trait)

;; Non Fungible Token, using sip-009
(define-non-fungible-token Besties-Forever uint)

;; Constants
(define-constant err-invalid-user u500)
(define-constant err-mint u600)
(define-constant err-souldbound u700)

(define-constant COMM u99000)

(define-constant DEPLOYER tx-sender)
(define-constant COMM_ADDR 'SP7AMEBV4Z6V4J9ENAFBH0T1DGQ67X6NF79GX3V3)

(define-map token-count principal uint)
(define-map whitelist
  {user: principal}
  {whitelisted: bool}
)

;; Internal variables
(define-data-var public-sale bool false)
(define-data-var last-id uint u1)
(define-data-var total-price uint u0)
(define-data-var artist-address principal 'SP7AMEBV4Z6V4J9ENAFBH0T1DGQ67X6NF79GX3V3)
(define-data-var ipfs-root (string-ascii 80) "ipfs://QmPfivx8gmCc6ErtBSZrJwRr1J6pFwdzuzKq19GHxRhNU9/")
(define-data-var ipfs-change-enabled bool true)


(define-public (claim (addr principal))
  (begin
    (asserts! (is-eq tx-sender) (err err-invalid-user))
    (mint-many (list addr))
  )
)

(define-public (claim-for (addr principal))
  (mint-many (list addr)))

(define-private (mint-many (orders (list 10 principal)))
  (let (
      (last-nft-id (var-get last-id))
      (enabled true)
      (art-addr (var-get artist-address))
      (id-reached (fold mint-many-iter orders last-nft-id))
      (price (* (var-get total-price) (- id-reached last-nft-id)))
      (total-commission (/ (* price COMM) u10000))
      (total-artist (- price total-commission))
    )
    (var-set last-id id-reached)
    (ok last-nft-id)
  )
)

(define-private (mint-many-iter (user principal) (next-id uint))
  (begin
    (unwrap! (nft-mint? Besties-Forever next-id user) next-id)
    (+ next-id u1)
  )
)

(define-read-only (get-balance (account principal))
  (default-to u0
    (map-get? token-count account)))

;; Non-custodial SIP-009 transfer function
(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err err-souldbound))
    (trnsfr id sender recipient)))

(define-private (trnsfr (id uint) (sender principal) (recipient principal))
  (match (nft-transfer? Besties-Forever id sender recipient)
        success
          (let
            ((sender-balance (get-balance sender))
            (recipient-balance (get-balance recipient)))
              (map-set token-count
                    recipient
                    (+ recipient-balance u1))
              (try! (nft-mint? Besties-Forever (var-get last-id) sender))
              (var-set last-id (+ (var-get last-id) u1))
              (print "<3")
              (ok success))
        error (err error)))

(define-public (set-artist-address (address principal))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) (err err-invalid-user))
    (ok (var-set artist-address address))
  )
)

(define-public (set-price (price uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) (err err-invalid-user))
    (ok (var-set total-price price))))

(define-public (set-ipfs-root (new-ipfs-root (string-ascii 80)))
  (begin
    (asserts! (and (var-get ipfs-change-enabled) (is-eq tx-sender DEPLOYER)) (err err-invalid-user))
    (ok (var-set ipfs-root new-ipfs-root))))

(define-public (freeze-ipfs-root)
  (begin
    (asserts! (and (var-get ipfs-change-enabled) (is-eq tx-sender DEPLOYER)) (err err-invalid-user))
    (ok (var-set ipfs-change-enabled false))))

;; read-only functions
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? Besties-Forever token-id)))

(define-read-only (get-last-token-id)
  (ok (- (var-get last-id) u1)))

(define-read-only (get-token-uri (token-id uint))
    (ok (some (concat (concat (var-get ipfs-root) "besties-forever") ".json"))))

(define-public (burn (token-id uint))
        (begin 
            (print "I thought we were friends?")
            (err err-souldbound)))