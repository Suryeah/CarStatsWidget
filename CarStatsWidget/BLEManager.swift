//
//  BLEManager.swift
//  CarStatsWidget
//
//  Created by Surya Vardhan on 26/08/26.
//

import Foundation
import CoreBluetooth
import Observation

@Observable
final class BLEManager: NSObject {
    
    private var centralManager: CBCentralManager!
    
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

    private(set) var soc: Int?
    
    init(vehicleManager: VehicleManager) {
        self.vehicleManager = vehicleManager
        
        super.init()
        
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil
        )
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
        requestSOC()

        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.requestSOC()
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - OBD-II SOC

    func requestSOC() {

        guard let peripheral = connectedPeripheral else {
            print("SOC: No connected peripheral")
            return
        }

        guard let characteristic = txCharacteristic else {
            print("SOC: TX characteristic not available")
            return
        }

        // Tata Nexon EV HV Battery SoC
        // UDS ReadDataByIdentifier
        // DID = 0x3421
        // Request = 22 34 21
        let command = "223421\r"

        print("SOC TX:", command.trimmingCharacters(in: .newlines))

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
            
            attemptAutoReconnect()
            
        case .poweredOff:
            isBluetoothReady = false
            print("Bluetooth: Powered Off")
            
        case .unauthorized:
            isBluetoothReady = false
            print("Bluetooth: Unauthorized")
            
        case .unsupported:
            isBluetoothReady = false
            print("Bluetooth: Unsupported")
            
        case .resetting:
            isBluetoothReady = false
            print("Bluetooth: Resetting")
            
        case .unknown:
            isBluetoothReady = false
            print("Bluetooth: Unknown")
            
        @unknown default:
            isBluetoothReady = false
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
        
        stopPolling()
        connectedPeripheral = nil
        services.removeAll()
        characteristics.removeAll()
        
        txCharacteristic = nil
        rxCharacteristic = nil
        
        rxBuffer = ""
        rxNotificationsReady = false
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
