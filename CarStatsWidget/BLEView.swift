//
//  BLEView.swift
//  CarStatsWidget
//
//  Created by Surya Vardhan on 26/08/26.
//

import SwiftUI
import CoreBluetooth

struct BLEView: View {
    
    @State private var bleManager = BLEManager()
    
    var body: some View {
        NavigationStack {
            List {
                
                // MARK: Bluetooth
                
                Section("Bluetooth") {
                    
                    HStack {
                        Text("Status")
                        
                        Spacer()
                        
                        Text(
                            bleManager.isBluetoothReady
                            ? "Powered On"
                            : "Unavailable"
                        )
                        .foregroundStyle(
                            bleManager.isBluetoothReady
                            ? .green
                            : .red
                        )
                    }
                }
                
                
                // MARK: Scan
                
                Section("Scanner") {
                    
                    Button {
                        if bleManager.isScanning {
                            bleManager.stopScanning()
                        } else {
                            bleManager.startScanning()
                        }
                    } label: {
                        Label(
                            bleManager.isScanning
                            ? "Stop Scanning"
                            : "Scan for OBD Devices",
                            systemImage:
                                bleManager.isScanning
                                ? "stop.circle"
                                : "dot.radiowaves.left.and.right"
                        )
                    }
                }
                
                
                // MARK: Devices
                
                Section("Discovered Devices") {
                    
                    if bleManager.discoveredDevices.isEmpty {
                        
                        Text("No devices discovered")
                            .foregroundStyle(.secondary)
                        
                    } else {
                        
                        ForEach(
                            bleManager.discoveredDevices,
                            id: \.identifier
                        ) { peripheral in
                            
                            Button {
                                bleManager.connect(
                                    to: peripheral
                                )
                            } label: {
                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {
                                    Text(
                                        peripheral.name
                                        ?? "Unnamed Device"
                                    )
                                    .font(.headline)
                                    
                                    Text(
                                        peripheral.identifier
                                            .uuidString
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                
                // MARK: Connection
                
                Section("Connection") {
                    
                    if let peripheral =
                        bleManager.connectedPeripheral {
                        
                        Text(
                            peripheral.name
                            ?? "Connected Device"
                        )
                        .foregroundStyle(.green)
                        
                    } else {
                        
                        Text("Not connected")
                            .foregroundStyle(.secondary)
                    }
                }
                
                
                // MARK: Services
                
                Section("Services") {
                    
                    ForEach(
                        bleManager.services,
                        id: \.uuid
                    ) { service in
                        
                        Text(
                            service.uuid.uuidString
                        )
                        .font(.system(
                            .body,
                            design: .monospaced
                        ))
                    }
                }
                
                
                // MARK: Characteristics
                
                Section("Characteristics") {
                    
                    ForEach(
                        bleManager.characteristics,
                        id: \.uuid
                    ) { characteristic in
                        
                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {
                            
                            Text(
                                characteristic.uuid.uuidString
                            )
                            .font(.system(
                                .body,
                                design: .monospaced
                            ))
                            
                            Text(
                                "\(characteristic.properties)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("OBD Bluetooth")
        }
    }
}


#Preview {
    BLEView()
}
