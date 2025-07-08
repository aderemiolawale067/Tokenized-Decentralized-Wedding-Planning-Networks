;; Budget Allocation Contract
;; Manages expense distribution across wedding categories

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_BUDGET_NOT_FOUND (err u201))
(define-constant ERR_BUDGET_ALREADY_EXISTS (err u202))
(define-constant ERR_INSUFFICIENT_FUNDS (err u203))
(define-constant ERR_CATEGORY_NOT_FOUND (err u204))
(define-constant ERR_INVALID_AMOUNT (err u205))
(define-constant ERR_EXPENSE_NOT_FOUND (err u206))

;; Data Variables
(define-data-var next-budget-id uint u1)
(define-data-var next-expense-id uint u1)

;; Data Maps
(define-map wedding-budgets
  { budget-id: uint }
  {
    couple: principal,
    total-budget: uint,
    allocated-amount: uint,
    spent-amount: uint,
    active: bool,
    created-at: uint
  }
)

(define-map budget-categories
  { budget-id: uint, category: (string-ascii 50) }
  {
    allocated-amount: uint,
    spent-amount: uint,
    description: (string-ascii 200)
  }
)

(define-map expenses
  { expense-id: uint }
  {
    budget-id: uint,
    category: (string-ascii 50),
    vendor: principal,
    amount: uint,
    description: (string-ascii 200),
    status: (string-ascii 20),
    created-at: uint,
    paid-at: uint
  }
)

(define-map couple-budget-lookup
  { couple: principal }
  { budget-id: uint }
)

;; Read-only functions
(define-read-only (get-budget (budget-id uint))
  (map-get? wedding-budgets { budget-id: budget-id })
)

(define-read-only (get-budget-category (budget-id uint) (category (string-ascii 50)))
  (map-get? budget-categories { budget-id: budget-id, category: category })
)

(define-read-only (get-expense (expense-id uint))
  (map-get? expenses { expense-id: expense-id })
)

(define-read-only (get-couple-budget (couple principal))
  (map-get? couple-budget-lookup { couple: couple })
)

(define-read-only (get-next-budget-id)
  (var-get next-budget-id)
)

(define-read-only (get-next-expense-id)
  (var-get next-expense-id)
)

(define-read-only (calculate-remaining-budget (budget-id uint))
  (match (map-get? wedding-budgets { budget-id: budget-id })
    budget (ok (- (get total-budget budget) (get spent-amount budget)))
    ERR_BUDGET_NOT_FOUND
  )
)

;; Public functions
(define-public (create-budget (total-budget uint))
  (let
    (
      (budget-id (var-get next-budget-id))
      (current-block stacks-block-height)
    )
    (asserts! (> total-budget u0) ERR_INVALID_AMOUNT)
    (asserts! (is-none (map-get? couple-budget-lookup { couple: tx-sender })) ERR_BUDGET_ALREADY_EXISTS)

    ;; Create budget
    (map-set wedding-budgets
      { budget-id: budget-id }
      {
        couple: tx-sender,
        total-budget: total-budget,
        allocated-amount: u0,
        spent-amount: u0,
        active: true,
        created-at: current-block
      }
    )

    ;; Create couple lookup
    (map-set couple-budget-lookup
      { couple: tx-sender }
      { budget-id: budget-id }
    )

    ;; Increment budget ID
    (var-set next-budget-id (+ budget-id u1))

    (ok budget-id)
  )
)

(define-public (allocate-category-budget
  (budget-id uint)
  (category (string-ascii 50))
  (amount uint)
  (description (string-ascii 200)))
  (let
    (
      (budget (unwrap! (map-get? wedding-budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (current-allocated (get allocated-amount budget))
      (new-allocated (+ current-allocated amount))
    )
    (asserts! (is-eq tx-sender (get couple budget)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= new-allocated (get total-budget budget)) ERR_INSUFFICIENT_FUNDS)

    ;; Add category allocation
    (map-set budget-categories
      { budget-id: budget-id, category: category }
      {
        allocated-amount: amount,
        spent-amount: u0,
        description: description
      }
    )

    ;; Update total allocated amount
    (map-set wedding-budgets
      { budget-id: budget-id }
      (merge budget { allocated-amount: new-allocated })
    )

    (ok true)
  )
)

(define-public (create-expense
  (budget-id uint)
  (category (string-ascii 50))
  (vendor principal)
  (amount uint)
  (description (string-ascii 200)))
  (let
    (
      (budget (unwrap! (map-get? wedding-budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (category-budget (unwrap! (map-get? budget-categories { budget-id: budget-id, category: category }) ERR_CATEGORY_NOT_FOUND))
      (expense-id (var-get next-expense-id))
      (current-block stacks-block-height)
      (category-remaining (- (get allocated-amount category-budget) (get spent-amount category-budget)))
    )
    (asserts! (is-eq tx-sender (get couple budget)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= amount category-remaining) ERR_INSUFFICIENT_FUNDS)

    ;; Create expense
    (map-set expenses
      { expense-id: expense-id }
      {
        budget-id: budget-id,
        category: category,
        vendor: vendor,
        amount: amount,
        description: description,
        status: "pending",
        created-at: current-block,
        paid-at: u0
      }
    )

    ;; Increment expense ID
    (var-set next-expense-id (+ expense-id u1))

    (ok expense-id)
  )
)

(define-public (pay-expense (expense-id uint))
  (let
    (
      (expense (unwrap! (map-get? expenses { expense-id: expense-id }) ERR_EXPENSE_NOT_FOUND))
      (budget-id (get budget-id expense))
      (category (get category expense))
      (amount (get amount expense))
      (budget (unwrap! (map-get? wedding-budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (category-budget (unwrap! (map-get? budget-categories { budget-id: budget-id, category: category }) ERR_CATEGORY_NOT_FOUND))
      (current-block stacks-block-height)
      (new-category-spent (+ (get spent-amount category-budget) amount))
      (new-total-spent (+ (get spent-amount budget) amount))
    )
    (asserts! (is-eq tx-sender (get couple budget)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status expense) "pending") ERR_UNAUTHORIZED)

    ;; Update expense status
    (map-set expenses
      { expense-id: expense-id }
      (merge expense {
        status: "paid",
        paid-at: current-block
      })
    )

    ;; Update category spent amount
    (map-set budget-categories
      { budget-id: budget-id, category: category }
      (merge category-budget { spent-amount: new-category-spent })
    )

    ;; Update total spent amount
    (map-set wedding-budgets
      { budget-id: budget-id }
      (merge budget { spent-amount: new-total-spent })
    )

    (ok true)
  )
)

(define-public (refund-expense (expense-id uint))
  (let
    (
      (expense (unwrap! (map-get? expenses { expense-id: expense-id }) ERR_EXPENSE_NOT_FOUND))
      (budget-id (get budget-id expense))
      (category (get category expense))
      (amount (get amount expense))
      (budget (unwrap! (map-get? wedding-budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (category-budget (unwrap! (map-get? budget-categories { budget-id: budget-id, category: category }) ERR_CATEGORY_NOT_FOUND))
      (new-category-spent (- (get spent-amount category-budget) amount))
      (new-total-spent (- (get spent-amount budget) amount))
    )
    (asserts! (is-eq tx-sender (get couple budget)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status expense) "paid") ERR_UNAUTHORIZED)

    ;; Update expense status
    (map-set expenses
      { expense-id: expense-id }
      (merge expense {
        status: "refunded",
        paid-at: u0
      })
    )

    ;; Update category spent amount
    (map-set budget-categories
      { budget-id: budget-id, category: category }
      (merge category-budget { spent-amount: new-category-spent })
    )

    ;; Update total spent amount
    (map-set wedding-budgets
      { budget-id: budget-id }
      (merge budget { spent-amount: new-total-spent })
    )

    (ok true)
  )
)

(define-public (update-budget-status
  (budget-id uint)
  (active bool))
  (let
    (
      (budget (unwrap! (map-get? wedding-budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get couple budget)) ERR_UNAUTHORIZED)

    (map-set wedding-budgets
      { budget-id: budget-id }
      (merge budget { active: active })
    )

    (ok true)
  )
)
