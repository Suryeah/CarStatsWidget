import SwiftUI
import CoreBluetooth

struct ContentView: View {
    
    @State private var vehicleManager = VehicleManager()
    @State private var bleManager = BLEManager()
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Header
                    
                    VStack(spacing: 4) {
                        Text("CarSOC")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Tata Nexon EV")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)
                    
                    
                    // MARK: - SOC Card
                    
                    VStack(spacing: 12) {
                        
                        Text("Battery State")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("\(vehicleManager.state.soc)%")
                            .font(.system(
                                size: 72,
                                weight: .bold,
                                design: .rounded
                            ))
                            .contentTransition(.numericText())
                        
                        HStack(spacing: 6) {
                            Circle()
                                .frame(width: 8, height: 8)
                            
                            Text(
                                vehicleManager.state.isConnected
                                ? "MODAXE Connected"
                                : "MODAXE Disconnected"
                            )
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                        .foregroundStyle(
                            vehicleManager.state.isConnected ? .green : .red
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(.background)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 24)
                    )
                    .shadow(
                        color: .black.opacity(0.08),
                        radius: 10,
                        y: 5
                    )
                    
                    
                    // MARK: - Last Updated
                    
                    InfoCard(
                        title: "Last Updated",
                        value: vehicleManager.state.lastUpdated.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    
                    
                    // MARK: - Bluetooth

                    BluetoothCard(bleManager: bleManager)
                    
                    
                    // MARK: - Vehicle
                    
                    SettingsCard(
                        title: "Vehicle",
                        value: "Tata Nexon EV"
                    )
                    
                    
                    // MARK: - Polling
                    
                    SettingsCard(
                        title: "Polling Interval",
                        value: "5 seconds"
                    )
                    
                    
                    // MARK: - Simulation
                    
                    Button {
                        vehicleManager.simulateSOCChange()
                    } label: {
                        Label(
                            "Simulate SOC Change",
                            systemImage: "bolt.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
    
    // MARK: - Simulation
}


// MARK: - Info Card

struct InfoCard: View {
    
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}


// MARK: - Settings Card

struct SettingsCard: View {
    
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }
}

// MARK: - Bluetooth Card

struct BluetoothCard: View {
    
    var bleManager: BLEManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)
                
                Text("Bluetooth")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(
                        bleManager.isBluetoothReady
                        ? Color.green
                        : Color.red
                    )
                    .frame(width: 8, height: 8)
                
                Text(
                    bleManager.isBluetoothReady
                    ? "Ready"
                    : "Unavailable"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            
            // Scan button
            
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
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!bleManager.isBluetoothReady)
            
            
            // Discovered devices
            
            if !bleManager.discoveredDevices.isEmpty {
                
                VStack(alignment: .leading, spacing: 8) {
                    
                    Text("Discovered Devices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(
                        bleManager.discoveredDevices,
                        id: \.identifier
                    ) { peripheral in
                        
                        Button {
                            bleManager.connect(to: peripheral)
                        } label: {
                            
                            HStack {
                                
                                Image(
                                    systemName: "dot.radiowaves.left.and.right"
                                )
                                
                                VStack(
                                    alignment: .leading,
                                    spacing: 3
                                ) {
                                    
                                    Text(
                                        peripheral.name
                                        ?? "Unnamed Device"
                                    )
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    
                                    Text(
                                        peripheral.identifier
                                            .uuidString
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if bleManager.connectedPeripheral?
                                    .identifier == peripheral.identifier {
                                    
                                    Image(
                                        systemName: "checkmark.circle.fill"
                                    )
                                    .foregroundStyle(.green)
                                    
                                } else {
                                    
                                    Image(
                                        systemName: "chevron.right"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            
            // Connection status
            
            Divider()
            
            HStack {
                Text("Connection")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let peripheral =
                    bleManager.connectedPeripheral {
                    
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)
                        
                        Text(
                            peripheral.name
                            ?? "Connected"
                        )
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    
                } else {
                    
                    Text("Not connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
    }
}


    // MARK: - Preview
    #Preview {
        ContentView()
    }
