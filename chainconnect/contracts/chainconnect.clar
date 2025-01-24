;; ChainConnect: Event Participation and Rewards Platform
;; Constants
(define-constant platform-admin tx-sender)
(define-constant err-admin-only (err u100))
(define-constant err-duplicate-participation (err u101))
(define-constant err-gathering-not-found (err u102))
(define-constant err-participation-blocked (err u103))

;; Data Maps
(define-map gatherings 
  { gathering-id: uint }
  { title: (string-ascii 50), timestamp: uint, capacity: uint, registered-count: uint }
)

(define-map attendance-records
  { gathering-id: uint, participant: principal }
  { confirmed: bool, entry-timestamp: uint }
)

(define-map participant-achievements
  { user: principal }
  { events-joined: uint, reward-points: uint }
)

;; NFT Definitions
(define-non-fungible-token chainconnect-badge uint)

;; Private Functions
(define-private (is-platform-admin)
  (is-eq tx-sender platform-admin)
)

;; Public Functions
(define-public (organize-gathering (gathering-id uint) (title (string-ascii 50)) (timestamp uint) (max-attendees uint))
  (begin
    (asserts! (is-platform-admin) err-admin-only)
    (map-set gatherings { gathering-id: gathering-id }
      { title: title, timestamp: timestamp, capacity: max-attendees, registered-count: u0 }
    )
    (ok true)
  )
)

(define-public (register-attendance (gathering-id uint))
  (let (
    (gathering (unwrap! (map-get? gatherings { gathering-id: gathering-id }) err-gathering-not-found))
    (current-registrations (get registered-count gathering))
    (gathering-capacity (get capacity gathering))
  )
    (asserts! (< current-registrations gathering-capacity) err-participation-blocked)
    (asserts! (is-none (map-get? attendance-records { gathering-id: gathering-id, participant: tx-sender })) err-duplicate-participation)
    
    (map-set attendance-records { gathering-id: gathering-id, participant: tx-sender }
      { confirmed: true, entry-timestamp: block-height }
    )
    (map-set gatherings { gathering-id: gathering-id }
      (merge gathering { registered-count: (+ current-registrations u1) })
    )
    (mint-participation-badge gathering-id tx-sender)
  )
)

(define-public (collect-achievement (gathering-id uint))
  (let (
    (attendance-entry (unwrap! (map-get? attendance-records { gathering-id: gathering-id, participant: tx-sender }) err-participation-blocked))
    (user-progress (default-to { events-joined: u0, reward-points: u0 } (map-get? participant-achievements { user: tx-sender })))
  )
    (asserts! (get confirmed attendance-entry) err-participation-blocked)
    (map-set participant-achievements { user: tx-sender }
      { events-joined: (+ (get events-joined user-progress) u1), reward-points: (+ (get reward-points user-progress) u10) }
    )
    (ok true)
  )
)

(define-private (mint-participation-badge (token-id uint) (recipient principal))
  (nft-mint? chainconnect-badge token-id recipient)
)

;; Read-only Functions
(define-read-only (get-gathering-details (gathering-id uint))
  (map-get? gatherings { gathering-id: gathering-id })
)

(define-read-only (get-participant-record (gathering-id uint) (participant principal))
  (map-get? attendance-records { gathering-id: gathering-id, participant: participant })
)

(define-read-only (get-participant-achievements (user principal))
  (default-to { events-joined: u0, reward-points: u0 } (map-get? participant-achievements { user: user }))
)