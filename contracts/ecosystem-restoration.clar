;; Ecosystem Restoration Contract
;; Manages regenerative initiatives and environmental projects

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_PROJECT_NOT_FOUND (err u501))
(define-constant ERR_INSUFFICIENT_FUNDING (err u502))
(define-constant ERR_INVALID_STATUS (err u503))

;; Project status constants
(define-constant STATUS_PROPOSED u0)
(define-constant STATUS_FUNDED u1)
(define-constant STATUS_ACTIVE u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_VERIFIED u4)

;; Restoration projects
(define-map restoration-projects
  { project-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    project-type: (string-ascii 50),
    target-area: uint,
    funding-goal: uint,
    funding-raised: uint,
    status: uint,
    proposer: principal,
    start-date: uint,
    completion-date: uint,
    impact-metrics: (string-ascii 200)
  }
)

;; Project funding contributions
(define-map project-contributions
  { project-id: uint, contributor: principal }
  { amount: uint, timestamp: uint }
)

;; Project counter
(define-data-var project-counter uint u0)

;; Ecosystem restoration fund
(define-data-var restoration-fund uint u0)

;; Authorized project managers
(define-map project-managers principal bool)

;; Initialize contract owner as project manager
(map-set project-managers CONTRACT_OWNER true)

;; Propose new restoration project
(define-public (propose-project
  (title (string-ascii 100))
  (description (string-ascii 500))
  (project-type (string-ascii 50))
  (target-area uint)
  (funding-goal uint)
  (impact-metrics (string-ascii 200)))
  (let ((project-id (+ (var-get project-counter) u1)))

    (map-set restoration-projects
      { project-id: project-id }
      {
        title: title,
        description: description,
        project-type: project-type,
        target-area: target-area,
        funding-goal: funding-goal,
        funding-raised: u0,
        status: STATUS_PROPOSED,
        proposer: tx-sender,
        start-date: u0,
        completion-date: u0,
        impact-metrics: impact-metrics
      }
    )

    (var-set project-counter project-id)

    (print {
      event: "project-proposed",
      project-id: project-id,
      title: title,
      proposer: tx-sender,
      funding-goal: funding-goal
    })
    (ok project-id)
  )
)

;; Contribute to project funding
(define-public (contribute-to-project (project-id uint) (amount uint))
  (let ((project (map-get? restoration-projects { project-id: project-id })))
    (asserts! (is-some project) ERR_PROJECT_NOT_FOUND)

    (let ((project-data (unwrap-panic project))
          (current-contribution (default-to
            { amount: u0, timestamp: u0 }
            (map-get? project-contributions { project-id: project-id, contributor: tx-sender }))))

      ;; Update contribution record
      (map-set project-contributions
        { project-id: project-id, contributor: tx-sender }
        {
          amount: (+ (get amount current-contribution) amount),
          timestamp: block-height
        }
      )

      ;; Update project funding
      (let ((new-funding-raised (+ (get funding-raised project-data) amount)))
        (map-set restoration-projects
          { project-id: project-id }
          (merge project-data {
            funding-raised: new-funding-raised,
            status: (if (>= new-funding-raised (get funding-goal project-data)) STATUS_FUNDED (get status project-data))
          })
        )
      )

      ;; Add to restoration fund
      (var-set restoration-fund (+ (var-get restoration-fund) amount))

      (print {
        event: "project-contribution",
        project-id: project-id,
        contributor: tx-sender,
        amount: amount
      })
      (ok true)
    )
  )
)

;; Start project (only project managers)
(define-public (start-project (project-id uint))
  (let ((project (map-get? restoration-projects { project-id: project-id }))
        (is-manager (default-to false (map-get? project-managers tx-sender))))

    (asserts! is-manager ERR_UNAUTHORIZED)
    (asserts! (is-some project) ERR_PROJECT_NOT_FOUND)

    (let ((project-data (unwrap-panic project)))
      (asserts! (is-eq (get status project-data) STATUS_FUNDED) ERR_INVALID_STATUS)

      (map-set restoration-projects
        { project-id: project-id }
        (merge project-data {
          status: STATUS_ACTIVE,
          start-date: block-height
        })
      )

      (print { event: "project-started", project-id: project-id })
      (ok true)
    )
  )
)

;; Complete project (only project managers)
(define-public (complete-project (project-id uint))
  (let ((project (map-get? restoration-projects { project-id: project-id }))
        (is-manager (default-to false (map-get? project-managers tx-sender))))

    (asserts! is-manager ERR_UNAUTHORIZED)
    (asserts! (is-some project) ERR_PROJECT_NOT_FOUND)

    (let ((project-data (unwrap-panic project)))
      (asserts! (is-eq (get status project-data) STATUS_ACTIVE) ERR_INVALID_STATUS)

      (map-set restoration-projects
        { project-id: project-id }
        (merge project-data {
          status: STATUS_COMPLETED,
          completion-date: block-height
        })
      )

      (print { event: "project-completed", project-id: project-id })
      (ok true)
    )
  )
)

;; Add project manager (only contract owner)
(define-public (add-project-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set project-managers manager true)
    (print { event: "project-manager-added", manager: manager })
    (ok true)
  )
)

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? restoration-projects { project-id: project-id })
)

;; Get contribution details
(define-read-only (get-contribution (project-id uint) (contributor principal))
  (map-get? project-contributions { project-id: project-id, contributor: contributor })
)

;; Get total restoration fund
(define-read-only (get-restoration-fund)
  (var-get restoration-fund)
)

;; Get project count
(define-read-only (get-project-count)
  (var-get project-counter)
)
