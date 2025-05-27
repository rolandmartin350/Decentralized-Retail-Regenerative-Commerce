;; Business Verification Contract
;; Validates and manages regenerative retailers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_BUSINESS_EXISTS (err u101))
(define-constant ERR_BUSINESS_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Business verification status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_SUSPENDED u3)

;; Business data structure
(define-map businesses
  { business-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    category: (string-ascii 50),
    status: uint,
    verification-date: uint,
    regenerative-score: uint
  }
)

;; Business counter
(define-data-var business-counter uint u0)

;; Authorized verifiers
(define-map verifiers principal bool)

;; Initialize contract owner as verifier
(map-set verifiers CONTRACT_OWNER true)

;; Register a new business for verification
(define-public (register-business (name (string-ascii 100)) (category (string-ascii 50)))
  (let ((business-id (+ (var-get business-counter) u1)))
    (map-set businesses
      { business-id: business-id }
      {
        owner: tx-sender,
        name: name,
        category: category,
        status: STATUS_PENDING,
        verification-date: u0,
        regenerative-score: u0
      }
    )
    (var-set business-counter business-id)
    (print { event: "business-registered", business-id: business-id, owner: tx-sender })
    (ok business-id)
  )
)

;; Verify a business (only authorized verifiers)
(define-public (verify-business (business-id uint) (regenerative-score uint))
  (let ((verifier-authorized (default-to false (map-get? verifiers tx-sender)))
        (business (map-get? businesses { business-id: business-id })))
    (asserts! verifier-authorized ERR_UNAUTHORIZED)
    (asserts! (is-some business) ERR_BUSINESS_NOT_FOUND)

    (map-set businesses
      { business-id: business-id }
      (merge (unwrap-panic business)
        {
          status: STATUS_VERIFIED,
          verification-date: block-height,
          regenerative-score: regenerative-score
        }
      )
    )
    (print { event: "business-verified", business-id: business-id, score: regenerative-score })
    (ok true)
  )
)

;; Add authorized verifier (only contract owner)
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set verifiers verifier true)
    (print { event: "verifier-added", verifier: verifier })
    (ok true)
  )
)

;; Get business details
(define-read-only (get-business (business-id uint))
  (map-get? businesses { business-id: business-id })
)

;; Check if business is verified
(define-read-only (is-business-verified (business-id uint))
  (match (map-get? businesses { business-id: business-id })
    business (is-eq (get status business) STATUS_VERIFIED)
    false
  )
)

;; Get business count
(define-read-only (get-business-count)
  (var-get business-counter)
)
