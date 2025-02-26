;; Supply Chain Verification Contract 

(define-data-var shipment-counter uint u0)
(define-map shipment-contracts
    { id: uint }
    {
        manufacturer: principal,
        retailer: principal,
        value: uint,
        is-active: bool,
        manufacturer-verified: bool,
        retailer-verified: bool,
        delivery-deadline: uint
    }
)

(define-public (create-shipment (manufacturer principal) (retailer principal) (value uint) (deadline uint))
    (begin
        ;; Validate basic inputs
        (if (or (is-eq manufacturer retailer) 
                (is-eq value u0) 
                (<= deadline block-height))
            (err "Invalid input: Manufacturer and retailer must be different, value must be greater than zero, and deadline must be in the future.")
            
            ;; Validate tx-sender
            (if (not (is-eq manufacturer tx-sender))
                (err "Only the manufacturer can initiate the shipment.")
                
                ;; Create the shipment contract
                (begin
                    (map-set shipment-contracts 
                        { id: (var-get shipment-counter) }
                        { manufacturer: manufacturer, 
                          retailer: retailer, 
                          value: value, 
                          is-active: true, 
                          manufacturer-verified: false, 
                          retailer-verified: false, 
                          delivery-deadline: deadline })
                    (var-set shipment-counter (+ (var-get shipment-counter) u1))
                    (ok (- (var-get shipment-counter) u1))
                )
            )
        )
    )
)

(define-public (verify-shipment (shipment-id uint))
    (if (>= shipment-id (var-get shipment-counter))
        (err "Invalid shipment ID.")
        (let
            (
                (shipment (map-get? shipment-contracts { id: shipment-id }))
            )
            (match shipment
                shipment-data
                (let
                    (
                        (manufacturer (get manufacturer shipment-data))
                        (retailer (get retailer shipment-data))
                    )
                    (if (is-eq tx-sender manufacturer)
                        (begin
                            (map-set shipment-contracts { id: shipment-id }
                                     (merge shipment-data { manufacturer-verified: true }))
                            (ok "Manufacturer has verified the shipment.")
                        )
                        (if (is-eq tx-sender retailer)
                            (begin
                                (map-set shipment-contracts { id: shipment-id }
                                         (merge shipment-data { retailer-verified: true }))
                                (ok "Retailer has verified the shipment.")
                            )
                            (err "Only the manufacturer or retailer can verify the shipment.")
                        )
                    )
                )
                (err "Shipment contract not found.")
            )
        )
    )
)

(define-public (complete-transaction (shipment-id uint))
    (if (>= shipment-id (var-get shipment-counter))
        (err "Invalid shipment ID.")
        (let
            (
                (shipment (map-get? shipment-contracts { id: shipment-id }))
            )
            (match shipment
                shipment-data
                (if (and (is-eq (get manufacturer-verified shipment-data) true)
                         (is-eq (get retailer-verified shipment-data) true)
                         (is-eq (get is-active shipment-data) true))
                    (let
                        (
                            (value (get value shipment-data))
                            (retailer (get retailer shipment-data))
                        )
                        (if (is-ok (stx-transfer? value tx-sender retailer))
                            (begin
                                (map-set shipment-contracts { id: shipment-id }
                                         (merge shipment-data { is-active: false }))
                                (ok "Transaction successfully completed.")
                            )
                            (err "STX transfer failed.")
                        )
                    )
                    (err "Both parties must verify before completing transaction.")
                )
                (err "Shipment contract not found.")
            )
        )
    )
)

(define-public (deadline-release (shipment-id uint))
    (if (>= shipment-id (var-get shipment-counter))
        (err "Invalid shipment ID.")
        (let
            (
                (shipment (map-get? shipment-contracts { id: shipment-id }))
            )
            (match shipment
                shipment-data
                (if (and (is-eq (get is-active shipment-data) true)
                         (>= block-height (get delivery-deadline shipment-data)))
                    (let
                        (
                            (value (get value shipment-data))
                            (retailer (get retailer shipment-data))
                        )
                        (if (is-ok (stx-transfer? value tx-sender retailer))
                            (begin
                                (map-set shipment-contracts { id: shipment-id }
                                         (merge shipment-data { is-active: false }))
                                (ok "Payment released to retailer after deadline expiration.")
                            )
                            (err "STX transfer failed.")
                        )
                    )
                    (err "Deadline not expired or shipment inactive.")
                )
                (err "Shipment contract not found.")
            )
        )
    )
)

(define-public (cancel-shipment (shipment-id uint))
    (if (>= shipment-id (var-get shipment-counter))
        (err "Invalid shipment ID.")
        (let
            (
                (shipment (map-get? shipment-contracts { id: shipment-id }))
            )
            (match shipment
                shipment-data
                (let
                    (
                        (manufacturer (get manufacturer shipment-data))
                        (is-active (get is-active shipment-data))
                    )
                    (if (and (is-eq tx-sender manufacturer) (is-eq is-active true))
                        (begin
                            (map-set shipment-contracts { id: shipment-id }
                                     (merge shipment-data { is-active: false }))
                            (ok "Shipment successfully cancelled.")
                        )
                        (err "Only the manufacturer can cancel an active shipment.")
                    )
                )
                (err "Shipment contract not found.")
            )
        )
    )
)