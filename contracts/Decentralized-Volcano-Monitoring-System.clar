(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_SENSOR (err u101))
(define-constant ERR_SENSOR_EXISTS (err u102))
(define-constant ERR_INVALID_READING (err u103))
(define-constant ERR_SENSOR_NOT_FOUND (err u104))
(define-constant ERR_INVALID_THRESHOLD (err u105))

(define-constant ALERT_LEVEL_NORMAL u0)
(define-constant ALERT_LEVEL_ELEVATED u1)
(define-constant ALERT_LEVEL_HIGH u2)
(define-constant ALERT_LEVEL_CRITICAL u3)

(define-data-var next-sensor-id uint u1)
(define-data-var global-alert-level uint ALERT_LEVEL_NORMAL)

(define-map sensors
  { sensor-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    latitude: int,
    longitude: int,
    active: bool,
    last-reading: uint,
    last-timestamp: uint
  }
)

(define-map seismic-readings
  { reading-id: uint }
  {
    sensor-id: uint,
    magnitude: uint,
    timestamp: uint,
    block-height: uint,
    verified: bool
  }
)

(define-map sensor-thresholds
  { sensor-id: uint }
  {
    normal-threshold: uint,
    elevated-threshold: uint,
    high-threshold: uint,
    critical-threshold: uint
  }
)

(define-map alerts
  { alert-id: uint }
  {
    sensor-id: uint,
    alert-level: uint,
    magnitude: uint,
    timestamp: uint,
    evacuate: bool,
    radius-km: uint
  }
)

(define-data-var next-reading-id uint u1)
(define-data-var next-alert-id uint u1)

(define-public (register-sensor (location (string-ascii 100)) (latitude int) (longitude int))
  (let ((sensor-id (var-get next-sensor-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? sensors { sensor-id: sensor-id })) ERR_SENSOR_EXISTS)
    (map-set sensors
      { sensor-id: sensor-id }
      {
        owner: tx-sender,
        location: location,
        latitude: latitude,
        longitude: longitude,
        active: true,
        last-reading: u0,
        last-timestamp: u0
      }
    )
    (map-set sensor-thresholds
      { sensor-id: sensor-id }
      {
        normal-threshold: u100,
        elevated-threshold: u300,
        high-threshold: u500,
        critical-threshold: u700
      }
    )
    (var-set next-sensor-id (+ sensor-id u1))
    (ok sensor-id)
  )
)

(define-public (submit-reading (sensor-id uint) (magnitude uint))
  (let 
    (
      (sensor-info (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
      (reading-id (var-get next-reading-id))
      (current-timestamp (unwrap-panic (get-stacks-block-info? time stacks-block-height)))
    )
    (asserts! (get active sensor-info) ERR_INVALID_SENSOR)
    (asserts! (> magnitude u0) ERR_INVALID_READING)
    (asserts! (< magnitude u1000) ERR_INVALID_READING)
    
    (map-set seismic-readings
      { reading-id: reading-id }
      {
        sensor-id: sensor-id,
        magnitude: magnitude,
        timestamp: current-timestamp,
        block-height: stacks-block-height,
        verified: true
      }
    )
    
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor-info {
        last-reading: magnitude,
        last-timestamp: current-timestamp
      })
    )
    
    (var-set next-reading-id (+ reading-id u1))
    (try! (check-and-create-alert sensor-id magnitude current-timestamp))
    (ok reading-id)
  )
)

(define-private (check-and-create-alert (sensor-id uint) (magnitude uint) (timestamp uint))
  (let 
    (
      (thresholds (unwrap! (map-get? sensor-thresholds { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
      (alert-level (calculate-alert-level magnitude thresholds))
      (alert-id (var-get next-alert-id))
    )
    (if (> alert-level ALERT_LEVEL_NORMAL)
      (begin
        (map-set alerts
          { alert-id: alert-id }
          {
            sensor-id: sensor-id,
            alert-level: alert-level,
            magnitude: magnitude,
            timestamp: timestamp,
            evacuate: (>= alert-level ALERT_LEVEL_HIGH),
            radius-km: (calculate-evacuation-radius alert-level)
          }
        )
        (var-set next-alert-id (+ alert-id u1))
        (unwrap-panic (update-global-alert-level alert-level))
        (ok alert-id)
      )
      (ok u0)
    )
  )
)

(define-private (calculate-alert-level (magnitude uint) (thresholds { normal-threshold: uint, elevated-threshold: uint, high-threshold: uint, critical-threshold: uint }))
  (if (>= magnitude (get critical-threshold thresholds))
    ALERT_LEVEL_CRITICAL
    (if (>= magnitude (get high-threshold thresholds))
      ALERT_LEVEL_HIGH
      (if (>= magnitude (get elevated-threshold thresholds))
        ALERT_LEVEL_ELEVATED
        ALERT_LEVEL_NORMAL
      )
    )
  )
)

(define-private (calculate-evacuation-radius (alert-level uint))
  (if (is-eq alert-level ALERT_LEVEL_CRITICAL)
    u50
    (if (is-eq alert-level ALERT_LEVEL_HIGH)
      u25
      u10
    )
  )
)

(define-private (update-global-alert-level (new-level uint))
  (begin
    (if (> new-level (var-get global-alert-level))
      (var-set global-alert-level new-level)
      true
    )
    (ok true)
  )
)

(define-public (update-sensor-thresholds (sensor-id uint) (normal uint) (elevated uint) (high uint) (critical uint))
  (let ((sensor-info (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner sensor-info)) ERR_UNAUTHORIZED)
    (asserts! (and (< normal elevated) (< elevated high) (< high critical)) ERR_INVALID_THRESHOLD)
    (map-set sensor-thresholds
      { sensor-id: sensor-id }
      {
        normal-threshold: normal,
        elevated-threshold: elevated,
        high-threshold: high,
        critical-threshold: critical
      }
    )
    (ok true)
  )
)

(define-public (deactivate-sensor (sensor-id uint))
  (let ((sensor-info (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner sensor-info)) ERR_UNAUTHORIZED)
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor-info { active: false })
    )
    (ok true)
  )
)

(define-public (activate-sensor (sensor-id uint))
  (let ((sensor-info (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner sensor-info)) ERR_UNAUTHORIZED)
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor-info { active: true })
    )
    (ok true)
  )
)
(define-public (transfer-sensor-ownership (sensor-id uint) (new-owner principal))
  (let ((sensor-info (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner sensor-info)) ERR_UNAUTHORIZED)
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor-info { owner: new-owner })
    )
    (ok true)
  )
)

(define-read-only (get-sensor-info (sensor-id uint))
  (map-get? sensors { sensor-id: sensor-id })
)

(define-read-only (get-reading (reading-id uint))
  (map-get? seismic-readings { reading-id: reading-id })
)

(define-read-only (get-alert (alert-id uint))
  (map-get? alerts { alert-id: alert-id })
)

(define-read-only (get-sensor-thresholds (sensor-id uint))
  (map-get? sensor-thresholds { sensor-id: sensor-id })
)

(define-read-only (get-global-alert-level)
  (var-get global-alert-level)
)

(define-read-only (get-sensor-count)
  (- (var-get next-sensor-id) u1)
)

(define-read-only (get-reading-count)
  (- (var-get next-reading-id) u1)
)

(define-read-only (get-alert-count)
  (- (var-get next-alert-id) u1)
)

(define-read-only (is-evacuation-required (sensor-id uint))
  (match (map-get? sensors { sensor-id: sensor-id })
    sensor-info (match (map-get? sensor-thresholds { sensor-id: sensor-id })
      thresholds (>= (get last-reading sensor-info) (get high-threshold thresholds))
      false
    )
    false
  )
)

(define-read-only (get-evacuation-radius (sensor-id uint))
  (match (map-get? sensors { sensor-id: sensor-id })
    sensor-info (match (map-get? sensor-thresholds { sensor-id: sensor-id })
      thresholds (let 
        (
          (last-magnitude (get last-reading sensor-info))
          (alert-level (calculate-alert-level last-magnitude thresholds))
        )
        (calculate-evacuation-radius alert-level)
      )
      u0
    )
    u0
  )
)

(define-read-only (get-recent-readings (sensor-id uint) (count uint))
  (let 
    (
      (total-readings (var-get next-reading-id))
      (start-id (if (> total-readings count) (- total-readings count) u1))
    )
    (ok (map get-reading-if-sensor (list start-id (+ start-id u1) (+ start-id u2) (+ start-id u3) (+ start-id u4))))
  )
)

(define-private (get-reading-if-sensor (reading-id uint))
  (map-get? seismic-readings { reading-id: reading-id })
)
