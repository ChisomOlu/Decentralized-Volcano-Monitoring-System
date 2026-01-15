A blockchain-based real-time volcano monitoring system that provides tamper-proof seismic data and automated evacuation alerts.

## 🎯 Overview

This smart contract enables IoT seismic sensors to submit real-time volcanic activity data to the Stacks blockchain, creating an immutable record of seismic events and triggering automatic evacuation alerts when dangerous activity is detected.

## ✨ Features

- 📊 **Real-time Seismic Data**: Submit and store tamper-proof seismic readings
- 🚨 **Automated Alerts**: Automatic alert generation based on configurable thresholds
- 🏃‍♂️ **Evacuation Triggers**: Smart evacuation recommendations with calculated safety radius
- 🌍 **Global Access**: Decentralized data accessible to anyone, anywhere
- 🔒 **Immutable Logs**: All seismic data permanently recorded on blockchain
- ⚙️ **Configurable Thresholds**: Customizable alert levels per sensor
- 🔄 **Global Alert Reset**: Owner-controlled reset of global alert level for emergency recovery
- 🔧 **Maintenance Mode**: Sensor owners can toggle maintenance mode to prevent false alerts during servicing

## 🚀 Quick Start

### Deploying the Contract

```bash
clarinet deploy
```

### Registering a Sensor

```clarity
(contract-call? .volcano-monitoring register-sensor "Mount Vesuvius" 4088430 1426270)
```

### Submitting Seismic Reading

```clarity
(contract-call? .volcano-monitoring submit-reading u1 u450)
```

## 📋 Contract Functions

### Public Functions

#### `register-sensor`
Register a new seismic sensor (owner only)
- `location`: Sensor location name
- `latitude`: Latitude coordinates (scaled by 100000)
- `longitude`: Longitude coordinates (scaled by 100000)

#### `submit-reading`
Submit a seismic reading from a sensor
- `sensor-id`: ID of the sensor
- `magnitude`: Seismic magnitude (0-1000 scale)

#### `update-sensor-thresholds`
Update alert thresholds for a sensor (sensor owner only)
- `sensor-id`: ID of the sensor
- `normal`: Normal threshold
- `elevated`: Elevated alert threshold
- `high`: High alert threshold
- `critical`: Critical alert threshold

#### `activate-sensor` / `deactivate-sensor`
Enable or disable a sensor (sensor owner only)

#### `reset-global-alert-level`
Reset global alert level to normal (contract owner only)

#### `set-sensor-maintenance`
Toggle maintenance mode for a sensor (sensor owner only)
- `sensor-id`: ID of the sensor
- `maintenance-mode`: Boolean flag to enable/disable maintenance mode

### Read-Only Functions

#### `get-sensor-info`
Get detailed information about a sensor

#### `get-reading`
Get details of a specific seismic reading

#### `get-alert`
Get details of a specific alert

#### `get-global-alert-level`
Get the current global alert level

#### `is-evacuation-required`
Check if evacuation is recommended for a sensor area

#### `get-evacuation-radius`
Get the recommended evacuation radius in kilometers

#### `is-sensor-in-maintenance`
Check if a sensor is currently in maintenance mode

## 🚨 Alert Levels

| Level | Code | Description | Evacuation |
|-------|------|-------------|------------|
| Normal | 0 | No unusual activity | ❌ |
| Elevated | 1 | Increased activity | ❌ |
| High | 2 | Dangerous activity | ✅ (25km radius) |
| Critical | 3 | Imminent eruption | ✅ (50km radius) |

## 🏗️ Architecture

The system consists of:

1. **Sensor Registry**: Manages IoT sensor registrations and metadata
2. **Reading Storage**: Immutable storage of all seismic measurements
3. **Alert System**: Automated alert generation based on thresholds
4. **Evacuation Logic**: Smart evacuation recommendations with radius calculations

## 🔧 Configuration

Default thresholds (can be customized per sensor):
- Normal: 0-100
- Elevated: 100-300
- High: 300-500
- Critical: 500+

## 📊 Data Structure

### Sensor Data
- Location coordinates and metadata
- Activity status, ownership, and maintenance mode
- Last reading and timestamp

### Seismic Readings
- Magnitude measurements
- Timestamp and block height
- Verification status

### Alerts
- Alert level and associated sensor
- Evacuation status and radius
- Trigger magnitude and timing

## 🛡️ Security

- Only contract owner can register new sensors
- Sensor owners control their device settings and maintenance status
- All data is immutable once recorded
- Automatic verification of reading validity
- Maintenance mode prevents false alerts during sensor servicing

## 🌐 Global Access

All seismic data and alerts are publicly readable, enabling:
- Emergency response coordination
- Scientific research access
- Community awareness
- Government monitoring

## 📈 Scalability

The contract supports unlimited sensors and readings, with efficient data structures for real-time querying and historical analysis.

## 🛑 Global Pause Mechanism

- **Emergency Control**: Contract owner can pause all write operations during emergencies
- **Security Enhancement**: Prevents malicious or erroneous transactions when paused
- **Read Access Maintained**: Read-only functions remain available for monitoring
- **Owner Authority**: Exclusive pause/unpause controls for contract administrator

### Additional Public Functions

#### `pause-contract`
Pause all contract operations (contract owner only)

#### `unpause-contract`
Resume contract operations (contract owner only)

### Additional Read-Only Functions

#### `is-contract-paused`
Check if the contract is currently paused
