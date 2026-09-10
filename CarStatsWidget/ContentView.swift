import SwiftUI
import CoreBluetooth

struct ContentView: View {
    
    @State private var vehicleManager = VehicleManager()
    @State private var bleManager: BLEManager
    @AppStorage("pollingInterval") private var pollingInterval: Double = 5.0
    
    init() {
        let vehicleManager = VehicleManager()
        
        _vehicleManager = State(initialValue: vehicleManager)
        _bleManager = State(
            initialValue: BLEManager(
                vehicleManager: vehicleManager
            )
        )
    }
    
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
                        
                        HStack(
                            alignment: .firstTextBaseline,
                            spacing: 3
                        ) {
                            Text(
                                String(
                                    format: "%.1f",
                                    vehicleManager.state.soc
                                )
                            )
                            .font(.system(
                                size: 72,
                                weight: .bold,
                                design: .rounded
                            ))
                            .contentTransition(.numericText())

                            Text("%")
                                .font(.system(
                                    size: 36,
                                    weight: .bold,
                                    design: .rounded
                                ))
                        }
                        
                        
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
                    
                    
                    // MARK: - Manual SOC Update

                    Button {
                        bleManager.requestSOC()
                    } label: {
                        Label(
                            "Update SOC",
                            systemImage: "arrow.clockwise"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !bleManager.isBluetoothReady ||
                        bleManager.connectedPeripheral == nil
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
                    
                    Menu {
                        ForEach([1.0, 5.0, 10.0, 30.0, 60.0], id: \.self) { interval in
                            Button {
                                pollingInterval = interval
                            } label: {
                                HStack {
                                    Text(pollingIntervalText(interval))
                                    if pollingInterval == interval {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        SettingsCard(
                            title: "Polling Interval",
                            value: pollingIntervalText(pollingInterval)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    
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
        .onAppear {
            bleManager.setPollingInterval(pollingInterval)
        }
        .onChange(of: pollingInterval) { _, newValue in
            bleManager.setPollingInterval(newValue)
        }
    }

    private func pollingIntervalText(_ interval: Double) -> String {
        if interval == 1 {
            return "1 second"
        }
        return "\(Int(interval)) seconds"
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

    @State private var showingDevicePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title3)

                Text("Bluetooth")
                    .font(.headline)

                Spacer()

                Circle()
                    .fill(bleManager.isBluetoothReady ? Color.green : Color.red)
                    .frame(width: 8, height: 8)

                Text(bleManager.isBluetoothReady ? "Ready" : "Unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                bleManager.startScanning()
                showingDevicePicker = true
            } label: {
                Label(
                    bleManager.connectedPeripheral == nil
                    ? "Scan for OBD Devices"
                    : "Change OBD Device",
                    systemImage: "dot.radiowaves.left.and.right"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!bleManager.isBluetoothReady)

            if let peripheral = bleManager.connectedPeripheral {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Device")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.title3)
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(peripheral.name ?? "Unnamed OBD Device")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Text(peripheral.identifier.uuidString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            } else {
                Text("No OBD device selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Connection")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let peripheral = bleManager.connectedPeripheral {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)
                            .frame(width: 7, height: 7)

                        Text(peripheral.name ?? "Connected")
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
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(isPresented: $showingDevicePicker) {
            DevicePickerSheet(bleManager: bleManager) {
                showingDevicePicker = false
            }
        }
    }
}


// MARK: - OBD Device Picker

struct DevicePickerSheet: View {

    var bleManager: BLEManager
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if bleManager.discoveredDevices.isEmpty {
                    VStack(spacing: 12) {
                        if bleManager.isScanning {
                            ProgressView()
                            Text("Searching for BLE devices...")
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.largeTitle)

                            Text("No BLE devices found")
                                .font(.headline)

                            Text("Start a scan to search for your OBD adapter.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    Section("Available BLE Devices") {
                        ForEach(
                            bleManager.discoveredDevices,
                            id: \.identifier
                        ) { peripheral in
                            Button {
                                bleManager.connect(to: peripheral)
                                onDismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(peripheral.name ?? "Unnamed BLE Device")
                                            .font(.body)
                                            .fontWeight(.medium)

                                        Text(peripheral.identifier.uuidString)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Select OBD Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        bleManager.stopScanning()
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}


    // MARK: - Preview
    #Preview {
        ContentView()
    }
