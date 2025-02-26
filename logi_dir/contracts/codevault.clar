;; Supply Chain Verification Contract - Version 3.0

(define-data-var shipment-counter uint u0)
(define-map shipment-contracts
    { id: uint }
    {
        manufacturer: principal,
        retailer: principal,
        value: uint,
        is-active: bool,
        is-shipped: bool,
        manufacturer-verified: bool,
        retailer-verified: bool,
        inspector-verified: bool,
        quality-dispute: bool,
        delivery-deadline: uint,
        product-signature: (optional (buff 32)),
        shipping-timestamp: (optional uint)
    }
)

;; Define quality inspector with proper principal format
(define-constant inspector 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)

(define-public (create-shipment (manufacturer principal) (retailer principal) (value uint) (deadline uint) (prod-sig (optional (buff 32))) (timestamp (optional uint)))
    (begin
        ;; Validate basic inputs
        (if (or (is-eq manufacturer retailer) 
                (is-eq value u0) 
                (<= deadline block-height))
            (err "Invalid input: Manufacturer and retailer must be different, value must be greater than zero, and deadline must be in the future.")
            
            ;; Validate tx-sender
            (if (not (is-eq manufacturer tx-sender))
                (err "Only the manufacturer can initiate the shipment.")
                
                ;; Validate product signature and timestamp
                (let (
                    (validated-timestamp (if (is-some timestamp)
                                        (if (> (unwrap-panic timestamp) block-height)
                                            timestamp
                                            none)
                                        none))
                    (validated-signature (if (is-some prod-sig)
                                    (if (is-eq (len (unwrap-panic prod-sig)) u32)
                                        prod-sig
                                        none)
                                    none))
                )
                    ;; Create the shipment contract
                    (begin
                        (map-set shipment-contracts 
                            { id: (var-get shipment-counter) }
                            { manufacturer: manufacturer, 
                              retailer: retailer, 
                              value: value, 
                              is-active: true, 
                              is-shipped: false, 
                              manufacturer-verified: false, 
                              retailer-verified: false, 
                              inspector-verified: false, 
                              quality-dispute: false, 
                              delivery-deadline: deadline, 
                              product-signature: validated-signature, 
                              shipping-timestamp: validated-timestamp })
                        (var-set shipment-counter (+ (var-get shipment-counter) u1))
                        (ok (- (var-get shipment-counter) u1))
                    )
                )
            )
        )
    )
)

(define-public (report-quality-issue (shipment-id uint))
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
                    (if (or (is-eq tx-sender manufacturer) (is-eq tx-sender retailer))
                        (begin
                            (map-set shipment-contracts { id: shipment-id }
                                     (merge shipment-data { quality-dispute: true }))
                            (ok "Quality issue has been reported.")
                        )
                        (err "Only the manufacturer or retailer can report quality issues.")
                    )
                )
                (err "Shipment contract not found.")
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
                            (if (is-eq tx-sender inspector)
                                (begin
                                    (map-set shipment-contracts { id: shipment-id }
                                             (merge shipment-data { inspector-verified: true }))
                                    (ok "Inspector has verified the shipment.")
                                )
                                (err "Only the manufacturer, retailer, or inspector can verify the shipment.")
                            )
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
                         (or (is-eq (get inspector-verified shipment-data) true)
                             (is-eq (get quality-dispute shipment-data) false))
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
                    (err "All parties must verify before completing transaction.")
                )
                (err "Shipment contract not found.")
            )
        )
    )
)

(define-public (resolve-quality-issue (shipment-id uint) (pay-retailer bool))
    (if (>= shipment-id (var-get shipment-counter))
        (err "Invalid shipment ID.")
        (if (is-eq tx-sender inspector)
            (let
                (
                    (shipment (map-get? shipment-contracts { id: shipment-id }))
                )
                (match shipment
                    shipment-data
                    (if (is-eq (get quality-dispute shipment-data) true)
                        (let
                            (
                                (manufacturer (get manufacturer shipment-data))
                                (retailer (get retailer shipment-data))
                                (value (get value shipment-data))
                            )
                            (if pay-retailer
                                (if (is-ok (stx-transfer? value tx-sender retailer))
                                    (begin
                                        (map-set shipment-contracts { id: shipment-id }
                                                 (merge shipment-data { is-active: false }))
                                        (ok "Payment released to retailer.")
                                    )
                                    (err "STX transfer to retailer failed.")
                                )
                                (if (is-ok (stx-transfer? value tx-sender manufacturer))
                                    (begin
                                        (map-set shipment-contracts { id: shipment-id }
                                                 (merge shipment-data { is-active: false }))
                                        (ok "Payment returned to manufacturer.")
                                    )
                                    (err "STX transfer to manufacturer failed.")
                                )
                            )
                        )
                        (err "No quality issue has been reported for this shipment.")
                    )
                    (err "Shipment contract not found.")
                )
            )
            (err "Only the inspector can resolve quality issues.")
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
                (if (and (is-eq (get quality-dispute shipment-data) false)
                         (is-eq (get is-active shipment-data) true)
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
                        (is-shipped (get is-shipped shipment-data))
                    )
                    (if (and (is-eq tx-sender manufacturer) (is-eq is-active true))
                        (begin
                            (if is-shipped
                                (let
                                    (
                                        (value (get value shipment-data))
                                    )
                                    (if (is-ok (stx-transfer? value tx-sender manufacturer))
                                        (begin
                                            (map-set shipment-contracts { id: shipment-id }
                                                     (merge shipment-data { is-active: false }))
                                            (ok "Shipment successfully cancelled, payment returned to manufacturer.")
                                        )
                                        (err "STX transfer failed.")
                                    )
                                )
                                (begin
                                    (map-set shipment-contracts { id: shipment-id }
                                             (merge shipment-data { is-active: false }))
                                    (ok "Shipment successfully cancelled.")
                                )
                            )
                        )
                        (err "Only the manufacturer can cancel an active shipment.")
                    )
                )
                (err "Shipment contract not found.")
            )
        )
    )
)

(define-public (verify-product (shipment-id uint) (prod-sig (buff 32)))
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
                        (stored-signature (get product-signature shipment-data))
                    )
                    (if (is-some stored-signature)
                        (if (is-eq (default-to 0x0000000000000000000000000000000000000000000000000000000000000000 stored-signature) prod-sig)
                            (ok "Product signature matches.")
                            (err "Product signature does not match.")
                        )
                        (err "No product signature stored for this shipment.")
                    )
                )
                (err "Shipment contract not found.")
            )
        )
    )
)

(define-public (add-product-signature (shipment-id uint) (prod-sig (buff 32)) (timestamp uint))
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
                    )
                    (if (is-eq tx-sender manufacturer)
                        (begin
                            (map-set shipment-contracts { id: shipment-id }
                                     (merge shipment-data { product-signature: (some prod-sig), shipping-timestamp: (some timestamp) }))
                            (ok "Product signature and timestamp added successfully.")
                        )
                        (err "Only the manufacturer can add a product signature.")
                    )
                )
                (err "Shipment contract not found.")
            )
        )
    )
)