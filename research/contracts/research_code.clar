;; Citizen Science Research Platform Smart Contract
;; Improved with scientific discoveries and contribution points

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INVALID-RESEARCHER (err u2))
(define-constant ERR-PROJECT-NOT-FOUND (err u3))
(define-constant ERR-DISCOVERY-EXISTS (err u4))
(define-constant ERR-DISCOVERY-NOT-FOUND (err u5))
(define-constant ERR-INVALID-INPUT (err u6))

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

(define-private (is-valid-researcher-id (researcher-id (string-ascii 50)))
  (and 
    (> (len researcher-id) u2)
    (<= (len researcher-id) u50)
  ))

;; Helper function to check if discovery exists
(define-private (discovery-exists? (researcher principal) (discovery-id uint))
  (is-some (map-get? scientific-discoveries { researcher: researcher, discovery-id: discovery-id })))

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
      ERR-INVALID-RESEARCHER)))
    
    (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
    (asserts! (is-valid-tier current-tier) ERR-INVALID-INPUT)
    (asserts! (is-valid-completion-rate completion-rate) ERR-INVALID-INPUT)
    
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
    
    (ok true)))

(define-public (admin-revoke-researcher-access (researcher principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! 
      (is-some (map-get? researcher-profiles researcher)) 
      ERR-INVALID-RESEARCHER)
    
    (map-delete researcher-profiles researcher)
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
    )))