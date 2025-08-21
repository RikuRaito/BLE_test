//
//  ContentView.swift
//  BLE_test
//
//  Created by 斉藤吏功 on 2025/08/21.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @State var tadashi = 12
    var body: some View {
        VStack {
            Button {
                BLEController.shared.didTapSendButton()
            } label: {
                Text("ペリフェラル起動")
                    .padding()
            }
            
            Text(BLEController.shared.receivedText)
                .padding()
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ContentView()
}

class BLEController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    static let shared = BLEController()
    
    var centralManager: CBCentralManager!
    var peripheralManager: CBPeripheralManager!
    
    @Published var receivedText = "受信データなし"
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func didTapSendButton() {
        if peripheralManager.isAdvertising {
            peripheralManager.stopAdvertising()
            print("Advertising stopped.")
            return
        }
        
        let appUUIDString = "bc407cce-aac9-5be2-07a5-e3b89f3055b5"
        let userID = "ajfi321"
        
        guard let appUUID = UUID(uuidString: appUUIDString) else { return }
        let uuidData = withUnsafeBytes(of: appUUID.uuid) { Data($0) }
        guard let userIdData = userID.data(using: .utf8) else { return }
        
        var combinedData = Data()
        combinedData.append(uuidData)
        combinedData.append(userIdData)
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataManufacturerDataKey: combinedData,
            CBAdvertisementDataLocalNameKey: "StreetpassApp"
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        print("Advertising started with combined data.")
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral Manager: Bluetooth is on.")
        default:
            print("Peripheral Manager State: \(peripheral.state.rawValue)")
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Central Manager: Bluetooth is on. Starting scan...")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            guard manufacturerData.count >= 16 else {
                print("Received data is too short.")
                return
            }
            
            let uuidData = manufacturerData.subdata(in: 0..<16)
            let userIdData = manufacturerData.subdata(in: 16..<manufacturerData.count)
            
            let uuid = NSUUID(uuidBytes: [UInt8](uuidData))
            let uuidString = uuid.uuidString
            let receivedUserID = String(data: userIdData, encoding: .utf8) ?? "Decoding failed"
            
            let displayText = """
            --- Discovered Device ---
            Name: \(peripheral.name ?? "Unknown Device")
            RSSI: \(RSSI) dBm
            Received App UUID: \(uuidString)
            Received User ID: \(receivedUserID)
            """
            
            print(displayText)
            DispatchQueue.main.async {
                self.receivedText = displayText
            }
        }
    }
}
