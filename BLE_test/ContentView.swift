import SwiftUI
import CoreBluetooth

struct ContentView: View {
    
    @ObservedObject var controller = BLEController.shared
    
    var body: some View {
        VStack(spacing: 20) {
            VStack {
                Button {
                    BLEController.shared.didTapSendButton()
                } label: {
                    Text(controller.isAdvertising ? "アドバタイズ停止" : "ペリフェラル起動")
                        .padding()
                        .background(controller.isAdvertising ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                HStack{
                    Text("Bluetooth状態:")
                    Circle()
                        .fill(controller.isPeripheralOn ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(controller.isPeripheralOn ? "ON" : "OFF")
                }
                .padding()
                
                HStack{
                    Text("アドバタイズ状態:")
                    Circle()
                        .fill(controller.isAdvertising ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(controller.isAdvertising ? "ON" : "OFF")
                }
            }
            
            Divider()
            
            VStack {
                Text("受信データ")
                    .font(.headline)
                
                ScrollView {
                    Text(controller.receivedText)
                        .padding()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

class BLEController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    static let shared = BLEController()
    
    var centralManager: CBCentralManager!
    var peripheralManager: CBPeripheralManager!
    
    @Published var receivedText = "受信データなし\n\n待機中..."
    @Published var isPeripheralOn = false
    @Published var isAdvertising = false
    
    // 固定のUUID（アプリ識別用）
    private let appServiceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    
    // 検出したデバイスの重複チェック用
    private var discoveredDevices: Set<String> = []
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func didTapSendButton() {
        // Bluetoothの状態確認を追加
        guard peripheralManager.state == .poweredOn else {
            print("Bluetooth is not powered on. Current state: \(peripheralManager.state.rawValue)")
            updateReceivedText("エラー: Bluetoothが有効ではありません")
            return
        }
        
        if peripheralManager.isAdvertising {
            peripheralManager.stopAdvertising()
            print("Advertising stopped.")
            updateReceivedText("アドバタイズを停止しました")
            return
        }
        
        let appUUIDString = "test11_8i"
        let userID = "ajfi321"
        
        // LocalNameを使用する方法
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "\(appUUIDString)_\(userID)",
            CBAdvertisementDataServiceUUIDsKey: [appServiceUUID]
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        print("Advertising started with combined data.")
        updateReceivedText("アドバタイズを開始しました\nアプリUUID: \(appUUIDString)\nユーザーID: \(userID)")
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        DispatchQueue.main.async {
            switch peripheral.state {
            case .poweredOn:
                print("Peripheral Manager: Bluetooth is on.")
                self.isPeripheralOn = true
                self.updateReceivedText("Bluetooth権限: 許可済み")
            case .poweredOff:
                print("Peripheral Manager: Bluetooth is off.")
                self.isPeripheralOn = false
                self.isAdvertising = false
                self.updateReceivedText("Bluetooth: オフ状態です")
            case .unauthorized:
                print("Peripheral Manager: Bluetooth access denied.")
                self.isPeripheralOn = false
                self.updateReceivedText("⚠️ Bluetooth使用が拒否されています。設定アプリで許可してください。")
            case .unsupported:
                print("Peripheral Manager: Bluetooth not supported.")
                self.isPeripheralOn = false
                self.updateReceivedText("エラー: このデバイスはBluetoothをサポートしていません")
            case .unknown:
                print("Peripheral Manager: Unknown state")
                self.updateReceivedText("Bluetooth状態: 不明")
            case .resetting:
                print("Peripheral Manager: Resetting")
                self.updateReceivedText("Bluetooth: リセット中...")
            @unknown default:
                print("Peripheral Manager State: \(peripheral.state.rawValue)")
                self.isPeripheralOn = false
                self.updateReceivedText("Bluetooth状態: 不明(\(peripheral.state.rawValue))")
            }
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("Advertising failed: \(error.localizedDescription)")
                self.isAdvertising = false
                self.updateReceivedText("アドバタイズ開始エラー: \(error.localizedDescription)")
            } else {
                print("Advertising started successfully")
                self.isAdvertising = true
            }
        }
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Central Manager: Bluetooth is on. Starting scan...")
            // 特定のサービスUUIDでスキャンするか、nilで全てをスキャン
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            updateReceivedText("スキャン開始中...")
        case .poweredOff:
            print("Central Manager: Bluetooth is off.")
            updateReceivedText("Bluetoothがオフになっています")
        case .unauthorized:
            print("Central Manager: Bluetooth access denied.")
            updateReceivedText("Bluetoothの使用が許可されていません")
        case .unsupported:
            print("Central Manager: Bluetooth not supported.")
            updateReceivedText("このデバイスはBluetoothをサポートしていません")
        default:
            print("Central Manager State: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // LocalNameから情報を取得
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            // 自分のアプリからのアドバタイズかチェック
            if localName.contains("test11_8i") {
                // 重複チェック
                let deviceKey = "\(peripheral.identifier.uuidString)_\(localName)"
                if discoveredDevices.contains(deviceKey) {
                    return // 既に発見済み
                }
                discoveredDevices.insert(deviceKey)
                
                let components = localName.components(separatedBy: "_")
                if components.count >= 2 {
                    let appUUID = components[0]
                    let userID = components[1]
                    
                    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    
                    let displayText = """
                    [\(timestamp)] デバイス発見！
                    --------------------------------
                    デバイス名: \(peripheral.name ?? "Unknown")
                    RSSI: \(RSSI) dBm
                    Local Name: \(localName)
                    App UUID: \(appUUID)
                    User ID: \(userID)
                    デバイスID: \(peripheral.identifier.uuidString)
                    --------------------------------
                    
                    """
                    
                    print(displayText)
                    updateReceivedText(displayText)
                }
            }
        }
        
        // その他のアドバタイズメントデータもログ出力（デバッグ用）
        if !advertisementData.isEmpty {
            print("Advertisement Data from \(peripheral.name ?? "Unknown"): \(advertisementData)")
        }
    }
    
    private func updateReceivedText(_ newText: String) {
        DispatchQueue.main.async {
            if self.receivedText.contains("受信データなし") || self.receivedText.contains("待機中") {
                self.receivedText = newText
            } else {
                self.receivedText = newText + "\n" + self.receivedText
            }
        }
    }
}
