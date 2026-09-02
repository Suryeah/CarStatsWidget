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
    
    private var rxBuffer = ""
    private(set) var soc: Int?
    
    override init() {
        super.init()
        
        centralManager = CBCentralManager(
            delegate: self,
            queue: nil
        )
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
        
        guard let peripheral = connectedPeripheral else {
            return
        }
        
        centralManager.cancelPeripheralConnection(peripheral)
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
        
        // Tata Nexon EV:
        // UDS ReadDataByIdentifier
        // DID = 0x3424
        // Request = 22 34 24
        let command = "223424\r"
        
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
        
        connectedPeripheral = nil
        services.removeAll()
        characteristics.removeAll()
        
        txCharacteristic = nil
        rxCharacteristic = nil
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
        
        guard let discoveredCharacteristics =
                service.characteristics
        else {
            return
        }
        
        characteristics.append(
            contentsOf: discoveredCharacteristics
        )
        
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
                
                requestSOC()
            }
        }
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

        guard let data = characteristic.value else {
            print("RX: empty")
            return
        }

        guard let text = String(
            data: data,
            encoding: .ascii
        ) else {
            print("RX: Failed to decode ASCII")
            return
        }

        print("RX ASCII:", text.debugDescription)

        rxBuffer += text

        // ELM327 sends ">" when the response is complete.
        guard rxBuffer.contains(">") else {
            return
        }

        print("ELM RESPONSE:", rxBuffer.debugDescription)

        let response = rxBuffer
            .components(separatedBy: ">")
            .first?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        rxBuffer = ""

        print("OBD RESPONSE:", response)

        // Expected response:
        // 7EB0462342451
        //
        // 7EB = CAN ID
        // 04  = payload length
        // 62 34 24 51 = UDS response
        //             ^^
        //             SOC = 0x51 = 81%

        let cleanResponse = response
            .replacingOccurrences(of: " ", with: "")

        guard cleanResponse.hasPrefix("7EB0") else {
            print(
                "SOC: Unexpected response:",
                cleanResponse
            )
            return
        }

        guard cleanResponse.count >= 12 else {
            print("SOC: Response too short")
            return
        }

        // Skip:
        // 7EB0
        //
        // Remaining:
        // 62342451

        let payloadStart = cleanResponse.index(
            cleanResponse.startIndex,
            offsetBy: 4
        )

        let payload = String(
            cleanResponse[payloadStart...]
        )

        guard payload.count >= 8 else {
            print("SOC: Payload too short")
            return
        }

        // Payload:
        // 62 34 24 51
        //
        // SOC is the final byte: 51

        let socHexStart = payload.index(
            payload.startIndex,
            offsetBy: 6
        )

        let socHexEnd = payload.index(
            socHexStart,
            offsetBy: 2
        )

        let socHex = String(
            payload[socHexStart..<socHexEnd]
        )

        guard let socValue = Int(
            socHex,
            radix: 16
        ) else {
            print(
                "SOC: Failed to parse:",
                socHex
            )
            return
        }

        soc = socValue

        print("===== SOC ===== \(socValue) %")
    }
}
