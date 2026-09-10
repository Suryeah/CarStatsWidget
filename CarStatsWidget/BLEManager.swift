//
//  BLEManager.swift
//  CarStatsWidget
//
//  Created by Surya Vardhan on 26/08/26.
//

import Foundation
import CoreBluetooth
import Observation
import OSLog

@Observable
final class BLEManager: NSObject {
    
    private var centralManager: CBCentralManager!
    private let logger = Logger(subsystem: "com.surya.CarStatsWidget", category: "BLE")
    
    private(set) var isBluetoothReady = false
    private(set) var isScanning = false
    private(set) var discoveredDevices: [CBPeripheral] = []
    
    private(set) var connectedPeripheral: CBPeripheral?
    
    private(set) var services: [CBService] = []
    private(set) var characteristics: [CBCharacteristic] = []
    
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?

    private let vehicleManager: VehicleManager

    private var rxBuffer = ""
    private var rxNotificationsReady = false
    private var pollingTimer: Timer?
    private var pollingInterval: TimeInterval = 5.0
    
    private let lastConnectedDeviceKey = "lastConnectedBLEDeviceUUID"

    private var autoReconnectUUID: UUID?
    private var autoReconnectScanTimer: Timer?
    private var didAttemptAutoReconnect = false

    // Core Bluetooth may restore peripherals before the central reaches .poweredOn.
    // Keep the restored peripheral here and finish restoration from
    // centralManagerDidUpdateState once Bluetooth is ready.
    private var restoredPeripheral: CBPeripheral?
    
    private var userRequestedDisconnect = false
    private let centralRestoreIdentifier = "com.surya.CarStatsWidget.bluetoothCentral"

    private(set) var soc: Int?
    
    init(vehicleManager: VehicleManager) {
        self.vehicleManager = vehicleManager
        
        super.init()
        
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey:
                    centralRestoreIdentifier
            ]
        )
logger.info("BLEManager initialized")
    }
    
    // MARK: - Automatic Reconnection

    private func attemptAutoReconnect() {

        guard !didAttemptAutoReconnect else {
            return
        }

        didAttemptAutoReconnect = true

        guard
            let uuidString = UserDefaults.standard.string(
                forKey: lastConnectedDeviceKey
            ),
            let uuid = UUID(uuidString: uuidString)
        else {
            print("AUTO RECONNECT: No saved BLE device")
            return
        }

        autoReconnectUUID = uuid

        print("AUTO RECONNECT: Looking for", uuid)

        // First try CoreBluetooth's known-peripheral cache.
        let peripherals = centralManager.retrievePeripherals(
            withIdentifiers: [uuid]
        )

        if let peripheral = peripherals.first {

            print(
                "AUTO RECONNECT: Found known device:",
                peripheral.name ?? "Unknown"
            )

            connect(to: peripheral)
            return
        }

        // Peripheral isn't currently in CoreBluetooth's cache.
        // Perform a short background scan and look specifically
        // for the saved UUID.
        print("AUTO RECONNECT: Starting background scan")

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ]
        )

        autoReconnectScanTimer?.invalidate()

        autoReconnectScanTimer = Timer.scheduledTimer(
            withTimeInterval: 10,
            repeats: false
        ) { [weak self] _ in

            guard let self else {
                return
            }

            print("AUTO RECONNECT: Device not found")

            self.centralManager.stopScan()
            self.autoReconnectUUID = nil
            self.autoReconnectScanTimer = nil
        }
    }
    
    
    // MARK: - Scanning
    
    func startScanning() {
        
        guard isBluetoothReady else {
            print("Bluetooth is not ready")
            return
        }
        
        discoveredDevices.removeAll()
        isScanning = true
        
        print("Starting BLE scan...")
        
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ]
        )
    }
    
    
    func stopScanning() {
        
        centralManager.stopScan()
        isScanning = false
        
        print("BLE scan stopped")
    }
    
    
    // MARK: - Connection
    
    func connect(to peripheral: CBPeripheral) {
        guard isBluetoothReady else {
            logger.warning("Connect requested while Bluetooth is not powered on")
            return
        }

        
        userRequestedDisconnect = false

        stopScanning()

        autoReconnectScanTimer?.invalidate()
        autoReconnectScanTimer = nil
        autoReconnectUUID = nil

        print("Connecting to:")
        print(peripheral.name ?? "Unknown")

        connectedPeripheral = peripheral
        peripheral.delegate = self

        centralManager.connect(
            peripheral,
            options: nil
        )
    }
    
    
    func disconnect() {
        userRequestedDisconnect = true
        stopPolling()

        guard let peripheral = connectedPeripheral else {
            return
        }

        centralManager.cancelPeripheralConnection(peripheral)
    }

    // MARK: - Polling

    func setPollingInterval(_ interval: TimeInterval) {
        guard interval > 0 else {
            return
        }

        pollingInterval = interval

        // Apply a changed interval immediately when the vehicle is ready.
        if connectedPeripheral != nil && rxNotificationsReady && txCharacteristic != nil {
            startPolling()
        }
    }

    private func startPolling() {
        stopPolling()

        // Request once immediately, then continue at the selected interval.
        logger.info(
            "SOC polling started: interval=\(self.pollingInterval, privacy: .public)s"
        )

        requestSOC()

        let interval = pollingInterval

        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.requestSOC()
        }
    }

    private func stopPolling() {
        if pollingTimer != nil {
            logger.info("SOC polling stopped")
        }
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - OBD-II SOC

    func requestSOC() {

        guard let peripheral = connectedPeripheral else {
            print("SOC: No connected peripheral")
            logger.warning("SOC request skipped: no connected peripheral")
            return
        }

        guard let characteristic = txCharacteristic else {
            print("SOC: TX characteristic not available")
            logger.warning("SOC request skipped: TX characteristic unavailable")
            return
        }

        // Tata Nexon EV HV Battery SoC
        // UDS ReadDataByIdentifier
        // DID = 0x3421
        // Request = 22 34 21
        let command = "223421\r"

        print("SOC TX:", command.trimmingCharacters(in: .newlines))
        logger.debug("SOC request transmitted")

        if let data = command.data(using: .ascii) {
            peripheral.writeValue(
                data,
                for: characteristic,
                type: .withResponse
            )
        }
    }
    
    func sendCommand(_ command: String) {
        
        guard let peripheral = connectedPeripheral else {
            print("Cannot send command: not connected")
            return
        }
        
        guard let characteristic = txCharacteristic else {
            print("Cannot send command: FFF2 not found")
            return
        }
        
        let commandToSend = command + "\r"
        
        guard let data = commandToSend.data(using: .ascii) else {
            print("Failed to encode command")
            return
        }
        
        print("TX:", commandToSend.debugDescription)
        
        peripheral.writeValue(
            data,
            for: characteristic,
            type: .withResponse
        )
    }
}


// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        switch central.state {
        case .poweredOn:
            isBluetoothReady = true
            print("Bluetooth: Powered On")
            logger.info("Bluetooth powered ON")

            if let restoredPeripheral {
                self.restoredPeripheral = nil
                self.connectedPeripheral = restoredPeripheral
                restoredPeripheral.delegate = self

                if restoredPeripheral.state == .connected {
                    print("BLE: Completing restoration for connected peripheral")
                    logger.info("Completing restoration for connected peripheral")
                    restoredPeripheral.discoverServices(nil)
                    didAttemptAutoReconnect = true
                    return
                }

                print("BLE: Restored peripheral is not connected")
                logger.info(
                    "Restored peripheral is not connected; continuing auto reconnect"
                )
            }

            attemptAutoReconnect()

        case .poweredOff:
            isBluetoothReady = false
            logger.warning("Bluetooth powered OFF")
        case .unauthorized:
            isBluetoothReady = false
            logger.error("Bluetooth unauthorized")
        case .unsupported:
            isBluetoothReady = false
            logger.error("Bluetooth unsupported")
        case .resetting:
            isBluetoothReady = false
            logger.warning("Bluetooth resetting")
        case .unknown:
            isBluetoothReady = false
            logger.warning("Bluetooth state unknown")
        @unknown default:
            isBluetoothReady = false
            logger.warning("Bluetooth state unknown/default")
        }
    }
    
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {

        if let targetUUID = autoReconnectUUID {

            guard peripheral.identifier == targetUUID else {
                return
            }

            print(
                "AUTO RECONNECT: Found target device:",
                peripheral.name ?? "Unknown"
            )

            autoReconnectScanTimer?.invalidate()
            autoReconnectScanTimer = nil

            centralManager.stopScan()

            autoReconnectUUID = nil

            connect(to: peripheral)

            return
        }

        // Existing manual-scan behaviour below this point

        let name = peripheral.name ?? "Unnamed BLE Device"

        print(
            "BLE Device:",
            name,
            "RSSI:",
            RSSI
        )

        guard !discoveredDevices.contains(
            where: { $0.identifier == peripheral.identifier }
        ) else {
            return
        }

        discoveredDevices.append(peripheral)
    }
    
    
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        
        print(
            "CONNECTED:",
            peripheral.name ?? "Unknown"
        )
        logger.info("Peripheral connected: \(peripheral.name ?? "Unknown", privacy: .public)")
        
        connectedPeripheral = peripheral
        
        UserDefaults.standard.set(
            peripheral.identifier.uuidString,
            forKey: lastConnectedDeviceKey
        )

        print(
            "AUTO RECONNECT: Saved device:",
            peripheral.identifier.uuidString
        )
        
        peripheral.discoverServices(nil)
    }
    
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        
        print(
            "FAILED TO CONNECT:",
            error?.localizedDescription ?? "Unknown error"
        )
        logger.error("Peripheral failed to connect: \(error?.localizedDescription ?? "Unknown error", privacy: .public)")
        
        connectedPeripheral = nil
    }
    
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        
        print(
            "DISCONNECTED:",
            peripheral.name ?? "Unknown"
        )
        logger.warning("Peripheral disconnected: \(peripheral.name ?? "Unknown", privacy: .public)")
        
        stopPolling()
        connectedPeripheral = nil
        services.removeAll()
        characteristics.removeAll()
        
        txCharacteristic = nil
        rxCharacteristic = nil
        
        rxBuffer = ""
        rxNotificationsReady = false

        guard !userRequestedDisconnect else {
            print("BLE: User requested disconnect")
            return
        }

        print("BLE: Unexpected disconnect")

        // Give Core Bluetooth a chance to reconnect.
        centralManager.connect(
            peripheral,
            options: [
                CBConnectPeripheralOptionEnableAutoReconnect: true
            ]
        )
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        timestamp: CFAbsoluteTime,
        isReconnecting: Bool,
        error: Error?
    ) {
        print(
            "BLE DISCONNECT:",
            peripheral.name ?? "Unknown",
            "reconnecting:",
            isReconnecting,
            "error:",
            error?.localizedDescription ?? "none"
        )

        logger.warning(
            "Disconnect callback. Reconnecting: \(isReconnecting), error: \(error?.localizedDescription ?? "none", privacy: .public)"
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String : Any]
    ) {
        print("BLE: Restoring Core Bluetooth state")
        logger.info("Core Bluetooth restoring state")

        guard
            let peripherals = dict[
                CBCentralManagerRestoredStatePeripheralsKey
            ] as? [CBPeripheral]
        else {
            logger.info("No restored peripherals")
            return
        }

        guard let peripheral = peripherals.first else {
            logger.info("Restored peripheral list is empty")
            return
        }

        print(
            "BLE: Restored peripheral:",
            peripheral.name ?? "Unknown",
            peripheral.identifier.uuidString
        )

        logger.info(
            "Restored peripheral: \(peripheral.name ?? "Unknown", privacy: .public)"
        )

        restoredPeripheral = peripheral
        connectedPeripheral = peripheral
        peripheral.delegate = self

        if peripheral.state == .connected {
            print("BLE: Restored peripheral is already connected")
            logger.info("Restored peripheral is already connected")
        } else {
            print("BLE: Restored peripheral state:", peripheral.state.rawValue)
            logger.info("Restored peripheral state: \(peripheral.state.rawValue)")
        }

        // Do not call discoverServices() or connect() here.
        // willRestoreState can occur before CBCentralManager reaches .poweredOn.
        // Restoration is completed from centralManagerDidUpdateState.
    }
}


// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        
        if let error {
            print(
                "Service discovery error:",
                error.localizedDescription
            )
            return
        }
        
        guard let discoveredServices = peripheral.services else {
            return
        }
        
        services = discoveredServices
        
        print("===== SERVICES =====")
        
        for service in discoveredServices {
            
            print(
                "Service:",
                service.uuid.uuidString
            )
            
            peripheral.discoverCharacteristics(
                nil,
                for: service
            )
        }
    }
    
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        
        if let error {
            print(
                "Characteristic discovery error:",
                error.localizedDescription
            )
            return
        }
        
        guard let discoveredCharacteristics = service.characteristics else {
            return
        }
        
        characteristics.append(contentsOf: discoveredCharacteristics)
        
        print(
            "===== CHARACTERISTICS FOR",
            service.uuid.uuidString,
            "====="
        )
        
        for characteristic in discoveredCharacteristics {
            
            print(
                "Characteristic:",
                characteristic.uuid.uuidString
            )
            
            print(
                "Properties:",
                characteristic.properties
            )
            
            // FFF1 = data coming FROM the OBD adapter
            
            if characteristic.uuid == CBUUID(string: "FFF1") {
                
                rxCharacteristic = characteristic
                
                peripheral.setNotifyValue(
                    true,
                    for: characteristic
                )
                
                rxNotificationsReady = true
                
                print(
                    "FFF1 configured for notifications"
                )
            }
            
            // FFF2 = commands going TO the OBD adapter
            
            if characteristic.uuid == CBUUID(string: "FFF2") {
                
                txCharacteristic = characteristic
                
                print(
                    "FFF2 configured for writing"
                )
            }
        }
        
        // Only send the command once both RX and TX are ready.
        requestSOCIfReady()
    }
    
    private func requestSOCIfReady() {
        
        guard rxNotificationsReady else {
            return
        }
        
        guard txCharacteristic != nil else {
            return
        }
        
        startPolling()
    }
    
    
    // MARK: - BLE RX
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        
        if let error {
            print(
                "RX error:",
                error.localizedDescription
            )
            return
        }
        
        guard characteristic.uuid == CBUUID(string: "FFF1") else {
            return
        }
        
        guard let data = characteristic.value else {
            print("RX: empty")
            return
        }
        
        print(
            "RX characteristic:",
            characteristic.uuid.uuidString
        )
        logger.debug("RX notification received")
        
        print(
            "RX raw data:",
            data as NSData
        )
        
        guard let response = String(
            data: data,
            encoding: .ascii
        ) else {
            print(
                "RX: Could not decode ASCII response"
            )
            return
        }
        
        print(
            "RX ASCII:",
            response.debugDescription
        )
        logger.debug("RX ASCII chunk received")
        
        // ---------------------------------------------------------
        // IMPORTANT:
        // BLE notifications are chunks, not complete ELM327 frames.
        // Append every chunk until the ELM327 prompt ">" arrives.
        // ---------------------------------------------------------
        
        rxBuffer += response
        
        print(
            "RX buffer:",
            rxBuffer.debugDescription
        )
        
        // ELM327 uses ">" to indicate that the complete response
        // to the command has been received.
        guard rxBuffer.contains(">") else {
            return
        }
        
        let completeResponse = rxBuffer
        
        // Clear buffer immediately so the next command starts clean.
        rxBuffer = ""
        
        print(
            "===== COMPLETE ELM RESPONSE ====="
        )
        logger.debug("Complete ELM327 response received")
        
        print(
            completeResponse.debugDescription
        )
        
        // ---------------------------------------------------------
        // Remove ELM327 prompt / line formatting.
        // ---------------------------------------------------------
        
        let cleaned = completeResponse
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        print(
            "RX cleaned:",
            cleaned
        )
        
        // ---------------------------------------------------------
        // Ignore the echoed command.
        //
        // Example:
        //
        // 22342162342103AD
        //
        // The actual response starts at 623421.
        // ---------------------------------------------------------
        
        guard let didRange = cleaned.range(
            of: "623421"
        ) else {
            print(
                "SOC: DID 3421 not found"
            )
            logger.warning("SOC DID 3421 not found in response")
            print(
                "=================================="
            )
            return
        }
        
        // ---------------------------------------------------------
        // DID 3421 response:
        //
        // 62 34 21 XX XX
        //
        // XX XX = raw HV Battery SoC
        // ---------------------------------------------------------
        
        let valueStart = didRange.upperBound
        
        guard cleaned.distance(
            from: valueStart,
            to: cleaned.endIndex
        ) >= 4 else {
            print(
                "SOC: Incomplete DID 3421 response"
            )
            logger.warning("Incomplete DID 3421 response")
            print(
                "=================================="
            )
            return
        }
        
        let valueEnd = cleaned.index(
            valueStart,
            offsetBy: 4
        )
        
        let rawString = String(
            cleaned[valueStart..<valueEnd]
        )
        
        guard let rawValue = UInt16(
            rawString,
            radix: 16
        ) else {
            print(
                "SOC: Invalid raw value:",
                rawString
            )
            print(
                "=================================="
            )
            return
        }
        
        // Tata Nexon EV:
        //
        // Raw value / 10 = HV Battery SoC %
        
        let soc = Double(rawValue) / 10.0
        
        print(
            "===== SOC DECODE ====="
        )
        logger.info("SOC decoded: \(String(format: "%.1f", soc), privacy: .public)%")
        
        print(
            "SOC raw:",
            rawString
        )
        
        print(
            "SOC raw decimal:",
            rawValue
        )
        
        print(
            "SOC:",
            String(format: "%.1f%%", soc)
        )
        
        vehicleManager.updateSOC(soc)
        
        print(
            "======================"
        )
    }
}
