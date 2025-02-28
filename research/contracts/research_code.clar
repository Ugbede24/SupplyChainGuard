;; Citizen Science Research Platform Smart Contract 
;; Complete implementation with research credits and expanded functionality

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INVALID-RESEARCHER (err u2))
(define-constant ERR-INSUFFICIENT-CREDITS (err u3))
(define-constant ERR-PROJECT-NOT-FOUND (err u4))
(define-constant ERR-DISCOVERY-EXISTS (err u5))
(define-constant ERR-DISCOVERY-NOT-FOUND (err u6))
(define-constant ERR-INVALID-INPUT (err u7))

;; Helper functions for input validation
(define-private (is-valid-project-id (id uint))
  (< id u1000000))

(define-private (is-valid-tier (tier uint))
  (and (> tier u0) (< tier u100)))

(define-private (is-valid-completion-rate (rate uint))
  (<= rate u100))

(define-private (is-valid-discovery-title (title (string-ascii 100)))
  (and (> (len title) u0) (<= (len title) u100)))

(define-private (is-valid-abstract (abstract (string-ascii 255)))
  (and (> (len abstract) u0) (<= (len abstract) u255)))

;; Simplified researcher-id validation
(define-private (is-valid-researcher-id (researcher-id (string-ascii 50)))
  (and 
    (> (len researcher-id) u2)  ;; Minimum 3 characters
    (<= (len researcher-id) u50)  ;; Maximum 50 characters
  ))

;; Data Maps
(define-map researcher-profiles 
  principal 
  {
    researcher-id: (string-ascii 50),
    contribution-points: uint,
    expertise-level: uint,
    projects-contributed: uint
  })

(define-map project-contributions 
  { researcher: principal, project-id: uint }
  {
    current-tier: uint,
    completion-rate: uint,
    finalized: bool
  })

(define-map scientific-discoveries 
  { researcher: principal, discovery-id: uint }
  {
    title: (string-ascii 100),
    abstract: (string-ascii 255),
    impact-factor: uint,
    published-at: uint
  })

(define-map research-credits 
  principal 
  uint)

(define-map project-collaborations
  { project-id: uint }
  {
    collaborator-count: uint,
    total-contributions: uint,
    is-active: bool
  })

;; Helper function to check if discovery exists
(define-private (discovery-exists? (researcher principal) (discovery-id uint))
  (is-some (map-get? scientific-discoveries { researcher: researcher, discovery-id: discovery-id })))

;; Public functions
(define-public (register-researcher (researcher-id (string-ascii 50)))
  (begin
    (asserts! (is-valid-researcher-id researcher-id) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? researcher-profiles tx-sender)) ERR-INVALID-RESEARCHER)
    
    (map-set researcher-profiles 
      tx-sender 
      {
        researcher-id: researcher-id,
        contribution-points: u0,
        expertise-level: u1,
        projects-contributed: u0
      })
    (ok true)))

(define-public (update-project-contribution 
  (project-id uint) 
  (current-tier uint) 
  (completion-rate uint))
  (let 
    ((researcher-profile (unwrap! 
      (map-get? researcher-profiles tx-sender) 
      ERR-INVALID-RESEARCHER))
     (project (default-to 
       { collaborator-count: u0, total-contributions: u0, is-active: true }
       (map-get? project-collaborations { project-id: project-id }))))
    
    (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-tier current-tier) ERR-INVALID-INPUT)
    (asserts! (is-valid-completion-rate completion-rate) ERR-INVALID-INPUT)
    (asserts! (get is-active project) ERR-PROJECT-NOT-FOUND)
    
    (map-set project-contributions 
      { researcher: tx-sender, project-id: project-id }
      {
        current-tier: current-tier,
        completion-rate: completion-rate,
        finalized: (is-eq completion-rate u100)
      })
    
    (map-set researcher-profiles 
      tx-sender 
      (merge researcher-profile { 
        projects-contributed: (+ (get projects-contributed researcher-profile) u1) 
      }))
    
    (map-set project-collaborations
      { project-id: project-id }
      {
        collaborator-count: (+ (get collaborator-count project) u1),
        total-contributions: (+ (get total-contributions project) u1),
        is-active: true
      })
    
    (ok true)))

(define-public (publish-discovery 
  (discovery-id uint) 
  (title (string-ascii 100)) 
  (abstract (string-ascii 255)) 
  (impact-factor uint))
  (let 
    ((researcher-profile (unwrap! 
      (map-get? researcher-profiles tx-sender) 
      ERR-INVALID-RESEARCHER)))
    
    (asserts! (is-valid-discovery-title title) ERR-INVALID-INPUT)
    (asserts! (is-valid-abstract abstract) ERR-INVALID-INPUT)
    (asserts! (> impact-factor u0) ERR-INVALID-INPUT)
    (asserts! 
      (not (discovery-exists? tx-sender discovery-id)) 
      ERR-DISCOVERY-EXISTS)
    
    (map-set scientific-discoveries 
      { researcher: tx-sender, discovery-id: discovery-id }
      {
        title: title,
        abstract: abstract,
        impact-factor: impact-factor,
        published-at: block-height
      })
    
    (map-set researcher-profiles 
      tx-sender 
      (merge researcher-profile { 
        contribution-points: (+ (get contribution-points researcher-profile) impact-factor) 
      }))
    
    ;; Award research credits based on impact factor
    (let ((current-credits (default-to u0 (map-get? research-credits tx-sender))))
      (map-set research-credits 
        tx-sender 
        (+ current-credits impact-factor)))
    
    (ok true)))

(define-public (create-project (project-id uint))
  (begin
    (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? researcher-profiles tx-sender)) ERR-INVALID-RESEARCHER)
    
    (map-set project-collaborations
      { project-id: project-id }
      {
        collaborator-count: u0,
        total-contributions: u0,
        is-active: true
      })
    
    (ok true)))

(define-public (spend-research-credits (amount uint) (project-id uint))
  (let 
    ((current-credits (default-to u0 (map-get? research-credits tx-sender))))
    
    (asserts! (>= current-credits amount) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    
    ;; Spend credits
    (map-set research-credits
      tx-sender
      (- current-credits amount))
    
    ;; Increase expertise level based on credits spent
    (let ((researcher-profile (unwrap! (map-get? researcher-profiles tx-sender) ERR-INVALID-RESEARCHER)))
      (map-set researcher-profiles
        tx-sender
        (merge researcher-profile {
          expertise-level: (+ (get expertise-level researcher-profile) u1)
        })))
    
    (ok true)))

(define-public (admin-revoke-researcher-access (researcher principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! 
      (is-some (map-get? researcher-profiles researcher)) 
      ERR-INVALID-RESEARCHER)
    
    (map-delete researcher-profiles researcher)
    (ok true)))

(define-public (admin-deactivate-project (project-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
    
    (let ((project (unwrap! (map-get? project-collaborations { project-id: project-id }) ERR-PROJECT-NOT-FOUND)))
      (map-set project-collaborations
        { project-id: project-id }
        (merge project { is-active: false })))
    
    (ok true)))

(define-public (allocate-research-credits (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    
    (let 
      ((current-balance (default-to u0 (map-get? research-credits tx-sender))))
      (map-set research-credits 
        tx-sender 
        (+ current-balance amount))
      (ok true))))

(define-public (transfer-credits (recipient principal) (amount uint))
  (let 
    ((sender-balance (default-to u0 (map-get? research-credits tx-sender)))
     (recipient-balance (default-to u0 (map-get? research-credits recipient))))
    
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (is-some (map-get? researcher-profiles recipient)) ERR-INVALID-RESEARCHER)
    
    (map-set research-credits
      tx-sender
      (- sender-balance amount))
    
    (map-set research-credits
      recipient
      (+ recipient-balance amount))
    
    (ok true)))

;; Read-only functions
(define-read-only (get-researcher-profile (researcher principal))
  (map-get? researcher-profiles researcher))

(define-read-only (get-project-contribution (researcher principal) (project-id uint))
  (map-get? project-contributions { researcher: researcher, project-id: project-id }))

(define-read-only (get-researcher-discoveries (researcher principal))
  (begin
    (list 
      (map-get? scientific-discoveries { researcher: researcher, discovery-id: u1 })
      (map-get? scientific-discoveries { researcher: researcher, discovery-id: u2 })
      (map-get? scientific-discoveries { researcher: researcher, discovery-id: u3 })
      (map-get? scientific-discoveries { researcher: researcher, discovery-id: u4 })
      (map-get? scientific-discoveries { researcher: researcher, discovery-id: u5 }))))

(define-read-only (get-research-credit-balance (researcher principal))
  (default-to u0 (map-get? research-credits researcher)))

(define-read-only (get-project-details (project-id uint))
  (map-get? project-collaborations { project-id: project-id }))

(define-read-only (check-expertise-level (researcher principal))
  (let ((profile (map-get? researcher-profiles researcher)))
    (default-to u0 (get expertise-level profile))))