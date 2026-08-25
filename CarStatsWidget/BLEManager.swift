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
        }
    }
}
