;; Conflict Resolution Contract
;; Mediates disputes between couples and vendors

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_DISPUTE_NOT_FOUND (err u501))
(define-constant ERR_DISPUTE_ALREADY_EXISTS (err u502))
(define-constant ERR_INVALID_AMOUNT (err u503))
(define-constant ERR_ARBITRATOR_NOT_FOUND (err u504))
(define-constant ERR_INVALID_STATUS (err u505))
(define-constant ERR_EVIDENCE_NOT_FOUND (err u506))
(define-constant ERR_RESOLUTION_NOT_FOUND (err u507))

;; Data Variables
(define-data-var next-dispute-id uint u1)
(define-data-var next-evidence-id uint u1)
(define-data-var arbitration-fee uint u100)

;; Data Maps
(define-map disputes
  { dispute-id: uint }
  {
    complainant: principal,
    respondent: principal,
    dispute-type: (string-ascii 50),
    description: (string-ascii 500),
    amount-disputed: uint,
    status: (string-ascii 20),
    arbitrator: principal,
    created-at: uint,
    resolved-at: uint,
    resolution-deadline: uint
  }
)

(define-map dispute-evidence
  { evidence-id: uint }
  {
    dispute-id: uint,
    submitted-by: principal,
    evidence-type: (string-ascii 50),
    evidence-data: (string-ascii 500),
    submitted-at: uint,
    verified: bool
  }
)

(define-map dispute-resolutions
  { dispute-id: uint }
  {
    resolution-type: (string-ascii 50),
    resolution-details: (string-ascii 500),
    compensation-amount: uint,
    compensation-recipient: principal,
    arbitrator-notes: (string-ascii 300),
    resolved-at: uint
  }
)

(define-map arbitrators
  { arbitrator: principal }
  {
    name: (string-ascii 100),
    specialization: (string-ascii 100),
    cases-handled: uint,
    success-rate: uint,
    active: bool,
    registered-at: uint
  }
)

(define-map dispute-votes
  { dispute-id: uint, voter: principal }
  {
    vote: (string-ascii 20),
    reasoning: (string-ascii 300),
    voted-at: uint
  }
)

;; Read-only functions
(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (get-evidence (evidence-id uint))
  (map-get? dispute-evidence { evidence-id: evidence-id })
)

(define-read-only (get-resolution (dispute-id uint))
  (map-get? dispute-resolutions { dispute-id: dispute-id })
)

(define-read-only (get-arbitrator (arbitrator principal))
  (map-get? arbitrators { arbitrator: arbitrator })
)

(define-read-only (get-dispute-vote (dispute-id uint) (voter principal))
  (map-get? dispute-votes { dispute-id: dispute-id, voter: voter })
)

(define-read-only (get-next-dispute-id)
  (var-get next-dispute-id)
)

(define-read-only (get-next-evidence-id)
  (var-get next-evidence-id)
)

(define-read-only (get-arbitration-fee)
  (var-get arbitration-fee)
)

;; Public functions
(define-public (register-arbitrator
  (name (string-ascii 100))
  (specialization (string-ascii 100)))
  (let
    (
      (current-block stacks-block-height)
    )
    (asserts! (is-none (map-get? arbitrators { arbitrator: tx-sender })) ERR_DISPUTE_ALREADY_EXISTS)

    (map-set arbitrators
      { arbitrator: tx-sender }
      {
        name: name,
        specialization: specialization,
        cases-handled: u0,
        success-rate: u0,
        active: true,
        registered-at: current-block
      }
    )

    (ok true)
  )
)

(define-public (create-dispute
  (respondent principal)
  (dispute-type (string-ascii 50))
  (description (string-ascii 500))
  (amount-disputed uint)
  (arbitrator principal))
  (let
    (
      (dispute-id (var-get next-dispute-id))
      (current-block stacks-block-height)
      (resolution-deadline (+ current-block u1440)) ;; 24 hours in blocks
      (arbitrator-info (unwrap! (map-get? arbitrators { arbitrator: arbitrator }) ERR_ARBITRATOR_NOT_FOUND))
    )
    (asserts! (not (is-eq tx-sender respondent)) ERR_UNAUTHORIZED)
    (asserts! (get active arbitrator-info) ERR_UNAUTHORIZED)

    ;; Create dispute
    (map-set disputes
      { dispute-id: dispute-id }
      {
        complainant: tx-sender,
        respondent: respondent,
        dispute-type: dispute-type,
        description: description,
        amount-disputed: amount-disputed,
        status: "open",
        arbitrator: arbitrator,
        created-at: current-block,
        resolved-at: u0,
        resolution-deadline: resolution-deadline
      }
    )

    ;; Increment dispute ID
    (var-set next-dispute-id (+ dispute-id u1))

    (ok dispute-id)
  )
)

(define-public (submit-evidence
  (dispute-id uint)
  (evidence-type (string-ascii 50))
  (evidence-data (string-ascii 500)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) ERR_DISPUTE_NOT_FOUND))
      (evidence-id (var-get next-evidence-id))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender (get complainant dispute)) (is-eq tx-sender (get respondent dispute))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status dispute) "open") ERR_INVALID_STATUS)

    ;; Submit evidence
    (map-set dispute-evidence
      { evidence-id: evidence-id }
      {
        dispute-id: dispute-id,
        submitted-by: tx-sender,
        evidence-type: evidence-type,
        evidence-data: evidence-data,
        submitted-at: current-block,
        verified: false
      }
    )

    ;; Increment evidence ID
    (var-set next-evidence-id (+ evidence-id u1))

    (ok evidence-id)
  )
)

(define-public (verify-evidence (evidence-id uint))
  (let
    (
      (evidence (unwrap! (map-get? dispute-evidence { evidence-id: evidence-id }) ERR_EVIDENCE_NOT_FOUND))
      (dispute (unwrap! (map-get? disputes { dispute-id: (get dispute-id evidence) }) ERR_DISPUTE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get arbitrator dispute)) ERR_UNAUTHORIZED)

    (map-set dispute-evidence
      { evidence-id: evidence-id }
      (merge evidence { verified: true })
    )

    (ok true)
  )
)

(define-public (resolve-dispute
  (dispute-id uint)
  (resolution-type (string-ascii 50))
  (resolution-details (string-ascii 500))
  (compensation-amount uint)
  (compensation-recipient principal)
  (arbitrator-notes (string-ascii 300)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) ERR_DISPUTE_NOT_FOUND))
      (current-block stacks-block-height)
      (arbitrator-info (unwrap! (map-get? arbitrators { arbitrator: (get arbitrator dispute) }) ERR_ARBITRATOR_NOT_FOUND))
      (new-cases-handled (+ (get cases-handled arbitrator-info) u1))
    )
    (asserts! (is-eq tx-sender (get arbitrator dispute)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status dispute) "open") ERR_INVALID_STATUS)
    (asserts! (or (is-eq compensation-recipient (get complainant dispute)) (is-eq compensation-recipient (get respondent dispute))) ERR_UNAUTHORIZED)

    ;; Create resolution
    (map-set dispute-resolutions
      { dispute-id: dispute-id }
      {
        resolution-type: resolution-type,
        resolution-details: resolution-details,
        compensation-amount: compensation-amount,
        compensation-recipient: compensation-recipient,
        arbitrator-notes: arbitrator-notes,
        resolved-at: current-block
      }
    )

    ;; Update dispute status
    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute {
        status: "resolved",
        resolved-at: current-block
      })
    )

    ;; Update arbitrator stats
    (map-set arbitrators
      { arbitrator: (get arbitrator dispute) }
      (merge arbitrator-info { cases-handled: new-cases-handled })
    )

    (ok true)
  )
)

(define-public (appeal-resolution (dispute-id uint))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) ERR_DISPUTE_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender (get complainant dispute)) (is-eq tx-sender (get respondent dispute))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status dispute) "resolved") ERR_INVALID_STATUS)
    (asserts! (< current-block (+ (get resolved-at dispute) u720)) ERR_UNAUTHORIZED) ;; 12 hours to appeal

    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute { status: "appealed" })
    )

    (ok true)
  )
)

(define-public (vote-on-dispute
  (dispute-id uint)
  (vote (string-ascii 20))
  (reasoning (string-ascii 300)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) ERR_DISPUTE_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get status dispute) "appealed") ERR_INVALID_STATUS)
    (asserts! (not (is-eq tx-sender (get complainant dispute))) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq tx-sender (get respondent dispute))) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq tx-sender (get arbitrator dispute))) ERR_UNAUTHORIZED)

    (map-set dispute-votes
      { dispute-id: dispute-id, voter: tx-sender }
      {
        vote: vote,
        reasoning: reasoning,
        voted-at: current-block
      }
    )

    (ok true)
  )
)

(define-public (update-dispute-status
  (dispute-id uint)
  (status (string-ascii 20)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) ERR_DISPUTE_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get arbitrator dispute)) ERR_UNAUTHORIZED)

    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute { status: status })
    )

    (ok true)
  )
)

(define-public (set-arbitration-fee (fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set arbitration-fee fee)
    (ok true)
  )
)

(define-public (deactivate-arbitrator (arbitrator principal))
  (let
    (
      (arbitrator-info (unwrap! (map-get? arbitrators { arbitrator: arbitrator }) ERR_ARBITRATOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

    (map-set arbitrators
      { arbitrator: arbitrator }
      (merge arbitrator-info { active: false })
    )

    (ok true)
  )
)
