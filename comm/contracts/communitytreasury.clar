;; Community Treasury Management DAO
;; Enables community governance over treasury funds and resource allocation

;; Constants
(define-constant contract-admin tx-sender)
(define-constant err-admin-only (err u100))
(define-constant err-treasury-not-found (err u101))
(define-constant err-access-denied (err u102))
(define-constant err-invalid-parameter (err u103))
(define-constant err-allocation-expired (err u104))
(define-constant err-duplicate-participation (err u105))
(define-constant err-insufficient-governance-tokens (err u106))
(define-constant err-malformed-input (err u107))
(define-constant err-allocation-active (err u108))

;; Configuration Variables
(define-data-var allocation-counter uint u0)
(define-data-var minimum-governance-tokens uint u2500)
(define-data-var decision-window uint u2016) ;; ~14 days in blocks
(define-data-var quorum-threshold uint u10000) ;; Minimum total votes needed

;; Input Validation
(define-private (validate-allocation-title (title (string-ascii 120)))
  (and (> (len title) u5) (<= (len title) u120)))

(define-private (validate-allocation-details (details (string-ascii 600)))
  (and (> (len details) u10) (<= (len details) u600)))

(define-private (validate-positive-amount (amount uint))
  (> amount u0))

(define-private (validate-recipient (recipient principal))
  (and (not (is-eq recipient contract-admin)) (not (is-eq recipient (as-contract tx-sender)))))

;; Data Structures
(define-map treasury-allocations
  { allocation-id: uint }
  {
    proposer: principal,
    title: (string-ascii 120),
    details: (string-ascii 600),
    requested-amount: uint,
    recipient: principal,
    approve-votes: uint,
    reject-votes: uint,
    proposal-block: uint,
    deadline-block: uint,
    current-status: (string-ascii 25),
    finalized: bool
  })

(define-map community-votes
  { allocation-id: uint, participant: principal }
  {
    decision: bool,
    voting-power: uint,
    timestamp-block: uint
  })

(define-map governance-holdings
  { member: principal }
  { token-amount: uint })

(define-map vote-delegations
  { delegator: principal }
  { chosen-delegate: principal })

;; Administrative Functions
(define-public (distribute-governance-tokens (member principal) (token-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-admin) err-admin-only)
    (asserts! (validate-recipient member) err-malformed-input)
    (asserts! (validate-positive-amount token-amount) err-invalid-parameter)
    
    (match (map-get? governance-holdings { member: member })
      existing-holding (map-set governance-holdings
        { member: member }
        { token-amount: (+ (get token-amount existing-holding) token-amount) })
      (map-set governance-holdings
        { member: member }
        { token-amount: token-amount }))
    (ok true)))

;; Core Governance Functions
(define-public (submit-treasury-allocation 
  (title (string-ascii 120)) 
  (details (string-ascii 600))
  (requested-amount uint)
  (recipient principal))
  (let
    ((allocation-id (+ (var-get allocation-counter) u1))
     (member-tokens (default-to u0 (get token-amount (map-get? governance-holdings { member: tx-sender })))))
    
    (asserts! (validate-allocation-title title) err-malformed-input)
    (asserts! (validate-allocation-details details) err-malformed-input)
    (asserts! (validate-positive-amount requested-amount) err-invalid-parameter)
    (asserts! (validate-recipient recipient) err-malformed-input)
    (asserts! (>= member-tokens (var-get minimum-governance-tokens)) err-insufficient-governance-tokens)
    
    (map-set treasury-allocations
      { allocation-id: allocation-id }
      {
        proposer: tx-sender,
        title: title,
        details: details,
        requested-amount: requested-amount,
        recipient: recipient,
        approve-votes: u0,
        reject-votes: u0,
        proposal-block: stacks-block-height,
        deadline-block: (+ stacks-block-height (var-get decision-window)),
        current-status: "under-review",
        finalized: false
      })
    
    (var-set allocation-counter allocation-id)
    (ok allocation-id)))

(define-public (cast-allocation-vote (allocation-id uint) (approve bool))
  (let
    ((allocation-data (unwrap! (map-get? treasury-allocations { allocation-id: allocation-id }) err-treasury-not-found))
     (member-tokens (default-to u0 (get token-amount (map-get? governance-holdings { member: tx-sender })))))
    
    (asserts! (validate-positive-amount allocation-id) err-malformed-input)
    (asserts! (is-eq (get current-status allocation-data) "under-review") err-allocation-expired)
    (asserts! (<= stacks-block-height (get deadline-block allocation-data)) err-allocation-expired)
    (asserts! (validate-positive-amount member-tokens) err-insufficient-governance-tokens)
    (asserts! (is-none (map-get? community-votes { allocation-id: allocation-id, participant: tx-sender })) err-duplicate-participation)
    
    ;; Record vote
    (map-set community-votes
      { allocation-id: allocation-id, participant: tx-sender }
      {
        decision: approve,
        voting-power: member-tokens,
        timestamp-block: stacks-block-height
      })
    
    ;; Update allocation vote tallies
    (map-set treasury-allocations
      { allocation-id: allocation-id }
      (merge allocation-data {
        approve-votes: (if approve (+ (get approve-votes allocation-data) member-tokens) (get approve-votes allocation-data)),
        reject-votes: (if approve (get reject-votes allocation-data) (+ (get reject-votes allocation-data) member-tokens))
      }))
    
    (ok true)))

(define-public (finalize-allocation (allocation-id uint))
  (let
    ((allocation-data (unwrap! (map-get? treasury-allocations { allocation-id: allocation-id }) err-treasury-not-found))
     (total-participation (+ (get approve-votes allocation-data) (get reject-votes allocation-data))))
    
    (asserts! (validate-positive-amount allocation-id) err-malformed-input)
    (asserts! (> stacks-block-height (get deadline-block allocation-data)) err-allocation-active)
    (asserts! (not (get finalized allocation-data)) err-allocation-expired)
    (asserts! (>= total-participation (var-get quorum-threshold)) err-insufficient-governance-tokens)
    
    (let ((final-status (if (> (get approve-votes allocation-data) (get reject-votes allocation-data)) "approved" "rejected")))
      (map-set treasury-allocations
        { allocation-id: allocation-id }
        (merge allocation-data {
          current-status: final-status,
          finalized: true
        }))
      (ok final-status))))

(define-public (assign-vote-delegate (chosen-delegate principal))
  (begin
    (asserts! (validate-recipient chosen-delegate) err-malformed-input)
    (asserts! (not (is-eq chosen-delegate tx-sender)) err-malformed-input)
    
    (map-set vote-delegations
      { delegator: tx-sender }
      { chosen-delegate: chosen-delegate })
    (ok true)))

;; Query Functions
(define-read-only (get-allocation-details (allocation-id uint))
  (map-get? treasury-allocations { allocation-id: allocation-id }))

(define-read-only (get-member-vote (allocation-id uint) (participant principal))
  (map-get? community-votes { allocation-id: allocation-id, participant: participant }))

(define-read-only (get-governance-balance (member principal))
  (default-to u0 (get token-amount (map-get? governance-holdings { member: member }))))

(define-read-only (get-total-allocations)
  (var-get allocation-counter))

(define-read-only (get-vote-delegate (delegator principal))
  (map-get? vote-delegations { delegator: delegator }))
