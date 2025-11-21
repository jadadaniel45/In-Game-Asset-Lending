
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_AMOUNT (err u400))
(define-constant ERR_ALREADY_BORROWED (err u409))
(define-constant ERR_NOT_BORROWED (err u410))
(define-constant ERR_EXPIRED (err u411))
(define-constant ERR_NOT_EXPIRED (err u412))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u413))
(define-constant ERR_INVALID_DURATION (err u414))
(define-constant ERR_ASSET_NOT_AVAILABLE (err u415))
(define-constant ERR_ALREADY_RATED (err u416))
(define-constant ERR_INVALID_RATING (err u417))
(define-constant ERR_CANNOT_RATE (err u418))
(define-constant ERR_DISPUTE_EXISTS (err u419))
(define-constant ERR_NO_DISPUTE (err u420))
(define-constant ERR_DISPUTE_RESOLVED (err u421))
(define-constant ERR_PENALTY_PAID (err u422))

(define-data-var contract-fee-rate uint u500)
(define-data-var min-lending-duration uint u144)
(define-data-var max-lending-duration uint u52560)
(define-data-var next-loan-id uint u1)
(define-data-var penalty-rate uint u2000)
(define-data-var dispute-window uint u1008)

(define-map asset-listings
  uint
  {
    owner: principal,
    asset-contract: principal,
    asset-id: uint,
    daily-rate: uint,
    min-duration: uint,
    max-duration: uint,
    available: bool
  }
)

(define-map active-loans
  uint
  {
    listing-id: uint,
    borrower: principal,
    start-block: uint,
    end-block: uint,
    total-cost: uint,
    daily-rate: uint,
    returned: bool
  }
)

(define-map user-asset-listings
  { user: principal, asset-contract: principal, asset-id: uint }
  uint
)

(define-map user-active-loans
  principal
  (list 10 uint)
)

(define-map listing-counter principal uint)

(define-map user-reputation
  principal
  {
    total-rating: uint,
    rating-count: uint,
    completed-loans: uint
  }
)

(define-map loan-ratings
  uint
  {
    lender-rated: bool,
    borrower-rated: bool,
    lender-rating: uint,
    borrower-rating: uint
  }
)

(define-map loan-disputes
  uint
  {
    initiated-by: principal,
    reason: (string-ascii 256),
    dispute-block: uint,
    resolved: bool,
    resolution: (string-ascii 256),
    penalty-amount: uint,
    penalty-paid: bool
  }
)

(define-read-only (get-contract-fee-rate)
  (var-get contract-fee-rate)
)

(define-read-only (get-min-lending-duration)
  (var-get min-lending-duration)
)

(define-read-only (get-max-lending-duration)
  (var-get max-lending-duration)
)

(define-read-only (get-asset-listing (listing-id uint))
  (map-get? asset-listings listing-id)
)

(define-read-only (get-active-loan (loan-id uint))
  (map-get? active-loans loan-id)
)

(define-read-only (get-user-listing (user principal) (asset-contract principal) (asset-id uint))
  (map-get? user-asset-listings { user: user, asset-contract: asset-contract, asset-id: asset-id })
)

(define-read-only (get-user-loans (user principal))
  (default-to (list) (map-get? user-active-loans user))
)

(define-read-only (get-user-reputation (user principal))
  (default-to { total-rating: u0, rating-count: u0, completed-loans: u0 } (map-get? user-reputation user))
)

(define-read-only (get-loan-rating (loan-id uint))
  (map-get? loan-ratings loan-id)
)

(define-read-only (get-loan-dispute (loan-id uint))
  (map-get? loan-disputes loan-id)
)

(define-read-only (get-penalty-rate)
  (var-get penalty-rate)
)

(define-read-only (get-dispute-window)
  (var-get dispute-window)
)

(define-read-only (calculate-penalty (loan-cost uint))
  (let
    (
      (penalty (* loan-cost (var-get penalty-rate)))
    )
    (/ penalty u10000)
  )
)

(define-read-only (get-average-rating (user principal))
  (let
    (
      (reputation (get-user-reputation user))
      (total (get total-rating reputation))
      (count (get rating-count reputation))
    )
    (if (> count u0)
      (some (/ (* total u100) count))
      none
    )
  )
)

(define-read-only (calculate-loan-cost (daily-rate uint) (duration uint))
  (let
    (
      (base-cost (* daily-rate duration))
      (fee (* base-cost (var-get contract-fee-rate)))
      (total-fee (/ fee u10000))
    )
    (+ base-cost total-fee)
  )
)

(define-read-only (is-loan-expired (loan-id uint))
  (match (map-get? active-loans loan-id)
    loan-data (>= stacks-block-height (get end-block loan-data))
    false
  )
)

(define-public (set-contract-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate u1000) ERR_INVALID_AMOUNT)
    (ok (var-set contract-fee-rate new-rate))
  )
)

(define-public (set-lending-duration-limits (min-duration uint) (max-duration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (< min-duration max-duration) ERR_INVALID_DURATION)
    (var-set min-lending-duration min-duration)
    (ok (var-set max-lending-duration max-duration))
  )
)

(define-public (set-penalty-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-rate u5000) ERR_INVALID_AMOUNT)
    (ok (var-set penalty-rate new-rate))
  )
)

(define-public (set-dispute-window (new-window uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (var-set dispute-window new-window))
  )
)

(define-public (list-asset (asset-contract principal) (asset-id uint) (daily-rate uint) (min-duration uint) (max-duration uint))
  (let
    (
      (listing-id (var-get next-loan-id))
      (current-count (default-to u0 (map-get? listing-counter tx-sender)))
    )
    (asserts! (> daily-rate u0) ERR_INVALID_AMOUNT)
    (asserts! (>= min-duration (var-get min-lending-duration)) ERR_INVALID_DURATION)
    (asserts! (<= max-duration (var-get max-lending-duration)) ERR_INVALID_DURATION)
    (asserts! (< min-duration max-duration) ERR_INVALID_DURATION)
    (asserts! (is-none (map-get? user-asset-listings { user: tx-sender, asset-contract: asset-contract, asset-id: asset-id })) ERR_ALREADY_BORROWED)
    
    (map-set asset-listings listing-id
      {
        owner: tx-sender,
        asset-contract: asset-contract,
        asset-id: asset-id,
        daily-rate: daily-rate,
        min-duration: min-duration,
        max-duration: max-duration,
        available: true
      }
    )
    
    (map-set user-asset-listings 
      { user: tx-sender, asset-contract: asset-contract, asset-id: asset-id }
      listing-id
    )
    
    (map-set listing-counter tx-sender (+ current-count u1))
    (var-set next-loan-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (update-listing (listing-id uint) (daily-rate uint) (min-duration uint) (max-duration uint))
  (match (map-get? asset-listings listing-id)
    listing-data
    (begin
      (asserts! (is-eq tx-sender (get owner listing-data)) ERR_UNAUTHORIZED)
      (asserts! (get available listing-data) ERR_ASSET_NOT_AVAILABLE)
      (asserts! (> daily-rate u0) ERR_INVALID_AMOUNT)
      (asserts! (>= min-duration (var-get min-lending-duration)) ERR_INVALID_DURATION)
      (asserts! (<= max-duration (var-get max-lending-duration)) ERR_INVALID_DURATION)
      (asserts! (< min-duration max-duration) ERR_INVALID_DURATION)
      
      (map-set asset-listings listing-id
        (merge listing-data
          {
            daily-rate: daily-rate,
            min-duration: min-duration,
            max-duration: max-duration
          }
        )
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (delist-asset (listing-id uint))
  (match (map-get? asset-listings listing-id)
    listing-data
    (begin
      (asserts! (is-eq tx-sender (get owner listing-data)) ERR_UNAUTHORIZED)
      (asserts! (get available listing-data) ERR_ASSET_NOT_AVAILABLE)
      
      (map-set asset-listings listing-id
        (merge listing-data { available: false })
      )
      
      (map-delete user-asset-listings 
        { 
          user: (get owner listing-data), 
          asset-contract: (get asset-contract listing-data), 
          asset-id: (get asset-id listing-data) 
        }
      )
      (ok true)
    )
    ERR_NOT_FOUND
  )
)

(define-public (borrow-asset (listing-id uint) (duration uint))
  (let
    (
      (loan-id (var-get next-loan-id))
      (current-loans (get-user-loans tx-sender))
    )
    (match (map-get? asset-listings listing-id)
      listing-data
      (let
        (
          (total-cost (calculate-loan-cost (get daily-rate listing-data) duration))
          (end-block (+ stacks-block-height duration))
        )
        (asserts! (get available listing-data) ERR_ASSET_NOT_AVAILABLE)
        (asserts! (not (is-eq tx-sender (get owner listing-data))) ERR_UNAUTHORIZED)
        (asserts! (>= duration (get min-duration listing-data)) ERR_INVALID_DURATION)
        (asserts! (<= duration (get max-duration listing-data)) ERR_INVALID_DURATION)
        (asserts! (< (len current-loans) u10) ERR_INVALID_AMOUNT)
        
        (try! (stx-transfer? total-cost tx-sender (get owner listing-data)))
        
        (map-set active-loans loan-id
          {
            listing-id: listing-id,
            borrower: tx-sender,
            start-block: stacks-block-height,
            end-block: end-block,
            total-cost: total-cost,
            daily-rate: (get daily-rate listing-data),
            returned: false
          }
        )
        
        (map-set asset-listings listing-id
          (merge listing-data { available: false })
        )
        
        (map-set user-active-loans tx-sender
          (unwrap! (as-max-len? (append current-loans loan-id) u10) ERR_INVALID_AMOUNT)
        )
        
        (var-set next-loan-id (+ loan-id u1))
        (ok loan-id)
      )
      ERR_NOT_FOUND
    )
  )
)

(define-public (return-asset (loan-id uint))
  (match (map-get? active-loans loan-id)
    loan-data
    (match (map-get? asset-listings (get listing-id loan-data))
      listing-data
      (begin
        (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
        (asserts! (not (get returned loan-data)) ERR_NOT_BORROWED)
        
        (map-set active-loans loan-id
          (merge loan-data { returned: true })
        )
        
        (map-set asset-listings (get listing-id loan-data)
          (merge listing-data { available: true })
        )
        
        (map-set loan-ratings loan-id
          {
            lender-rated: false,
            borrower-rated: false,
            lender-rating: u0,
            borrower-rating: u0
          }
        )
        
        (ok true)
      )
      ERR_NOT_FOUND
    )
    ERR_NOT_FOUND
  )
)

(define-public (claim-expired-asset (loan-id uint))
  (match (map-get? active-loans loan-id)
    loan-data
    (match (map-get? asset-listings (get listing-id loan-data))
      listing-data
      (begin
        (asserts! (is-eq tx-sender (get owner listing-data)) ERR_UNAUTHORIZED)
        (asserts! (>= stacks-block-height (get end-block loan-data)) ERR_NOT_EXPIRED)
        (asserts! (not (get returned loan-data)) ERR_ALREADY_BORROWED)
        
        (map-set active-loans loan-id
          (merge loan-data { returned: true })
        )
        
        (map-set asset-listings (get listing-id loan-data)
          (merge listing-data { available: true })
        )
        
        (ok true)
      )
      ERR_NOT_FOUND
    )
    ERR_NOT_FOUND
  )
)

(define-public (extend-loan (loan-id uint) (additional-duration uint))
  (match (map-get? active-loans loan-id)
    loan-data
    (match (map-get? asset-listings (get listing-id loan-data))
      listing-data
      (let
        (
          (additional-cost (calculate-loan-cost (get daily-rate loan-data) additional-duration))
          (new-end-block (+ (get end-block loan-data) additional-duration))
        )
        (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
        (asserts! (not (get returned loan-data)) ERR_NOT_BORROWED)
        (asserts! (< stacks-block-height (get end-block loan-data)) ERR_EXPIRED)
        (asserts! (<= (- new-end-block (get start-block loan-data)) (get max-duration listing-data)) ERR_INVALID_DURATION)
        
        (try! (stx-transfer? additional-cost tx-sender (get owner listing-data)))
        
        (map-set active-loans loan-id
          (merge loan-data 
            { 
              end-block: new-end-block,
              total-cost: (+ (get total-cost loan-data) additional-cost)
            }
          )
        )
        
        (ok true)
      )
      ERR_NOT_FOUND
    )
    ERR_NOT_FOUND
  )
)

(define-public (rate-borrower (loan-id uint) (rating uint))
  (match (map-get? active-loans loan-id)
    loan-data
    (match (map-get? asset-listings (get listing-id loan-data))
      listing-data
      (match (map-get? loan-ratings loan-id)
        rating-data
        (let
          (
            (borrower (get borrower loan-data))
            (borrower-rep (get-user-reputation borrower))
          )
          (asserts! (is-eq tx-sender (get owner listing-data)) ERR_UNAUTHORIZED)
          (asserts! (get returned loan-data) ERR_CANNOT_RATE)
          (asserts! (not (get lender-rated rating-data)) ERR_ALREADY_RATED)
          (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
          
          (map-set loan-ratings loan-id
            (merge rating-data { lender-rated: true, borrower-rating: rating })
          )
          
          (map-set user-reputation borrower
            {
              total-rating: (+ (get total-rating borrower-rep) rating),
              rating-count: (+ (get rating-count borrower-rep) u1),
              completed-loans: (+ (get completed-loans borrower-rep) u1)
            }
          )
          
          (ok true)
        )
        ERR_CANNOT_RATE
      )
      ERR_NOT_FOUND
    )
    ERR_NOT_FOUND
  )
)

(define-public (rate-lender (loan-id uint) (rating uint))
  (match (map-get? active-loans loan-id)
    loan-data
    (match (map-get? asset-listings (get listing-id loan-data))
      listing-data
      (match (map-get? loan-ratings loan-id)
        rating-data
        (let
          (
            (lender (get owner listing-data))
            (lender-rep (get-user-reputation lender))
          )
          (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
          (asserts! (get returned loan-data) ERR_CANNOT_RATE)
          (asserts! (not (get borrower-rated rating-data)) ERR_ALREADY_RATED)
          (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
          
          (map-set loan-ratings loan-id
            (merge rating-data { borrower-rated: true, lender-rating: rating })
          )
          
          (map-set user-reputation lender
            {
              total-rating: (+ (get total-rating lender-rep) rating),
              rating-count: (+ (get rating-count lender-rep) u1),
              completed-loans: (+ (get completed-loans lender-rep) u1)
            }
          )
          
          (ok true)
        )
        ERR_CANNOT_RATE
      )
      ERR_NOT_FOUND
    )
    ERR_NOT_FOUND
  )
)

(define-public (initiate-dispute (loan-id uint) (reason (string-ascii 256)))
  (match (map-get? active-loans loan-id)
    loan-data
    (match (map-get? asset-listings (get listing-id loan-data))
      listing-data
      (let
        (
          (penalty (calculate-penalty (get total-cost loan-data)))
          (is-lender (is-eq tx-sender (get owner listing-data)))
          (is-borrower (is-eq tx-sender (get borrower loan-data)))
        )
        (asserts! (or is-lender is-borrower) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? loan-disputes loan-id)) ERR_DISPUTE_EXISTS)
        (asserts! (< stacks-block-height (+ (get end-block loan-data) (var-get dispute-window))) ERR_EXPIRED)
        
        (map-set loan-disputes loan-id
          {
            initiated-by: tx-sender,
            reason: reason,
            dispute-block: stacks-block-height,
            resolved: false,
            resolution: "",
            penalty-amount: penalty,
            penalty-paid: false
          }
        )
        
        (ok true)
      )
      ERR_NOT_FOUND
    )
    ERR_NOT_FOUND
  )
)

(define-public (resolve-dispute (loan-id uint) (resolution (string-ascii 256)) (penalize-borrower bool))
  (match (map-get? loan-disputes loan-id)
    dispute-data
    (match (map-get? active-loans loan-id)
      loan-data
      (match (map-get? asset-listings (get listing-id loan-data))
        listing-data
        (begin
          (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
          (asserts! (not (get resolved dispute-data)) ERR_DISPUTE_RESOLVED)
          
          (map-set loan-disputes loan-id
            (merge dispute-data { resolved: true, resolution: resolution })
          )
          
          (ok penalize-borrower)
        )
        ERR_NOT_FOUND
      )
      ERR_NOT_FOUND
    )
    ERR_NO_DISPUTE
  )
)

(define-public (pay-dispute-penalty (loan-id uint))
  (match (map-get? loan-disputes loan-id)
    dispute-data
    (match (map-get? active-loans loan-id)
      loan-data
      (match (map-get? asset-listings (get listing-id loan-data))
        listing-data
        (begin
          (asserts! (is-eq tx-sender (get borrower loan-data)) ERR_UNAUTHORIZED)
          (asserts! (get resolved dispute-data) ERR_NO_DISPUTE)
          (asserts! (not (get penalty-paid dispute-data)) ERR_PENALTY_PAID)
          
          (try! (stx-transfer? (get penalty-amount dispute-data) tx-sender (get owner listing-data)))
          
          (map-set loan-disputes loan-id
            (merge dispute-data { penalty-paid: true })
          )
          
          (ok true)
        )
        ERR_NOT_FOUND
      )
      ERR_NOT_FOUND
    )
    ERR_NO_DISPUTE
  )
)

