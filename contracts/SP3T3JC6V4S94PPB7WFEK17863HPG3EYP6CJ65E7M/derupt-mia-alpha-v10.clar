;; Derupt MIA

(define-constant contract-creator tx-sender)

(define-constant ERR_INVALID_CONTENT u0)

(define-constant ERR_CANNOT_INTERACT_WITH_NON_EXISTENT_CONTENT u1)

(define-constant APP_DEV 'SP3T3JC6V4S94PPB7WFEK17863HPG3EYP6CJ65E7M)

(define-constant HOT_TUB 'SP1ZG09W7XN7S1WH5F06YN25C5CGK2RE01ED0J28E)

;; Data maps and vars
(define-data-var content-index uint u0)

(define-read-only (get-content-index)
  (ok (var-get content-index))
)

(define-map like-state
  { content-index: uint }
  { likes: uint }
)

(define-map dislike-state
  { content-index: uint }
  { dislikes: uint }
)

(define-map publisher-state
  { content-index: uint }
  { publisher: principal }
)

(define-read-only (get-like-count (id uint))
  (ok (default-to { likes: u0 } (map-get? like-state { content-index: id })))
)

(define-read-only (get-dislike-count (id uint))
  (ok (default-to { dislikes: u0 } (map-get? dislike-state { content-index: id })))
)

(define-read-only (get-message-publisher (id uint))
  (ok (unwrap-panic (get publisher (map-get? publisher-state { content-index: id }))))
)

;; Private functions
(define-private (increment-content-index)
  (begin
    (var-set content-index (+ (var-get content-index) u1))
    (ok (var-get content-index))
  )
)

(define-private (get-balance (recipient principal))
  (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2 get-balance recipient)
)

;; Public functions
(define-public (send-message (content (string-utf8 140) ) (attachment-uri (optional (string-utf8 256))) (reply-to (optional uint)))
  (let ((id (unwrap! (increment-content-index) (err u0))))
    (print { content: content, publisher: tx-sender, index: id, attachment-uri: attachment-uri, reply-to: reply-to })
    (map-set like-state
      { content-index: id }
      { likes: u0 }
    )
    (map-set dislike-state
      { content-index: id }
      { dislikes: u0 }
    )    
    (map-set publisher-state
      { content-index: id }
      { publisher: tx-sender }
    )
    (transfer-miamicoin u100 APP_DEV)
  )
)

(define-public (like-message (id uint))
  (begin
    (asserts! (>= (var-get content-index) id) (err ERR_CANNOT_INTERACT_WITH_NON_EXISTENT_CONTENT))
    (map-set like-state
      { content-index: id }
      { likes: (+ u1 (get likes (unwrap! (get-like-count id) (err u0)))) }
    )
    (transfer-miamicoin u100 (unwrap-panic (get-message-publisher id)))
  )
)

(define-public (dislike-message (id uint))
  (begin
    (asserts! (>= (var-get content-index) id) (err ERR_CANNOT_INTERACT_WITH_NON_EXISTENT_CONTENT))
    (map-set dislike-state
      { content-index: id }
      { dislikes: (+ u1 (get dislikes (unwrap! (get-dislike-count id) (err u0)))) }
    )
    (transfer-miamicoin u100 HOT_TUB)
  )
)

;; Token contract interactions
(define-public (transfer-miamicoin (amount uint) (recipient principal))
  (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2 transfer amount tx-sender recipient none)
)