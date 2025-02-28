;; Citizen Science Research Platform Smart Contract - V1
;; Basic implementation with core researcher registration and project tracking

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INVALID-RESEARCHER (err u2))
(define-constant ERR-PROJECT-NOT-FOUND (err u3))
(define-constant ERR-INVALID-INPUT (err u4))

;; Helper functions for input validation
(define-private (is-valid-project-id (id uint))
  (< id u1000000))

(define-private (is-valid-researcher-id (researcher-id (string-ascii 50)))
  (and 
    (> (len researcher-id) u2)
    (<= (len researcher-id) u50)
  ))

;; Data Maps
(define-map researcher-profiles 
  principal 
  {
    researcher-id: (string-ascii 50),
    expertise-level: uint,
    projects-contributed: uint
  })

(define-map project-contributions 
  { researcher: principal, project-id: uint }
  {
    contribution-date: uint,
    completed: bool
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
        expertise-level: u1,
        projects-contributed: u0
      })
    (ok true)))

(define-public (log-project-contribution (project-id uint))
  (let 
    ((researcher-profile (unwrap! 
      (map-get? researcher-profiles tx-sender) 
      ERR-INVALID-RESEARCHER)))
    
    (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
    
    (map-set project-contributions 
      { researcher: tx-sender, project-id: project-id }
      {
        contribution-date: block-height,
        completed: true
      })
    
    (map-set researcher-profiles 
      tx-sender 
      (merge researcher-profile { 
        projects-contributed: (+ (get projects-contributed researcher-profile) u1) 
      }))
    
    (ok true)))

(define-public (admin-remove-researcher (researcher principal))
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