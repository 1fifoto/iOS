/*

Copyright (c) 2015 Fernando Reynoso
Copyright (c) 2015 Brian Watt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

import Foundation
import CoreBluetooth

protocol BLEDelegate {
    func bleDidConnect()
    func bleDidDisconnect()
    func bleDidUpdateRSSI()
    func bleDidReceiveData(data: NSData?)
}

class BLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let RBL_SERVICE_UUID = "713D0000-503E-4C75-BA94-3148F18D941E"
    let RBL_CHAR_TX_UUID = "713D0002-503E-4C75-BA94-3148F18D941E"
    let RBL_CHAR_RX_UUID = "713D0003-503E-4C75-BA94-3148F18D941E"
    
    let RBL_BLE_FRAMEWORK_VER: UInt16 = 0x0200
    
    var delegate: BLEDelegate? = nil
    var peripherals = [CBPeripheral]()
    var peripheralsRssi = [NSNumber]()
    var CM: CBCentralManager? = nil
    var activePeripheral: CBPeripheral? = nil

    private var isConnectedBool: Bool = false
    private var rssi: Int = 0
    
    private var characteristics = [String : CBCharacteristic]()
    private var RSSICompletionHandler: ((NSNumber?, NSError?) -> ())? = nil
    
    override init() {
#if BLE_DEBUG
        print("In BLE.init")
#endif
        super.init()
        controlSetup()
    }
    
    func readRSSI(completion: (RSSI: NSNumber?, error: NSError?) -> ()) {
#if BLE_DEBUG
        print("In BLE.readRSSI")
#endif
        self.RSSICompletionHandler = completion
        self.activePeripheral?.readRSSI()
    }
    
    func isConnected() -> Bool {
#if BLE_DEBUG
        print("In BLE.isConnected")
#endif
        return isConnectedBool
    }
    
    func read() {
#if BLE_DEBUG
        print("In BLE.read")
        printKnownPeripherals()
#endif
        let uuid_service = CBUUID(string:RBL_SERVICE_UUID)
        let uuid_char = CBUUID(string:RBL_CHAR_TX_UUID)
#if BLE_DEBUG
        print("uuid_service=\(uuid_service) uuid_char=\(uuid_char)")
#endif
        readValue(uuid_service, characteristicUUID: uuid_char, p: activePeripheral)
    }
    
    func write(d d: NSData) {
#if BLE_DEBUG
        print("In BLE.write d=\(d)")
        printKnownPeripherals()
#endif
        let uuid_service = CBUUID(string:RBL_SERVICE_UUID)
        let uuid_char = CBUUID(string:RBL_CHAR_RX_UUID)
#if BLE_DEBUG
        print("uuid_service=\(uuid_service) uuid_char=\(uuid_char)")
#endif
        writeValue(uuid_service, characteristicUUID: uuid_char, p: activePeripheral, data: d)
    }
    
    func enableReadNotifications(p: CBPeripheral?) {
#if BLE_DEBUG
        print("In BLE.enableReadNotifications")
        printKnownPeripherals()
#endif
        let uuid_service = CBUUID(string:RBL_SERVICE_UUID)
        let uuid_char = CBUUID(string:RBL_CHAR_TX_UUID)
#if BLE_DEBUG
        print("uuid_service=\(uuid_service) uuid_char=\(uuid_char)")
#endif
        notification(uuid_service, characteristicUUID: uuid_char, p: p, on: true)
    }
    
    func notification(serviceUUID: CBUUID, characteristicUUID: CBUUID, p: CBPeripheral?, on: Bool) {
#if BLE_DEBUG
        print("In BLE.notification")
#endif
        let service: CBService? = findServiceFromUUID(serviceUUID, p: p!)
        
        if service == nil {
            print("[ERROR] Could not find service with UUID \(serviceUUID) on peripheral with UUID \(p)")
            return
        }
        
        let characteristic: CBCharacteristic? = findCharacteristicFromUUID(characteristicUUID, service: service!)
        
        if characteristic == nil {
            print("[ERROR] Could not find characteristic with UUID \(characteristicUUID) on service with UUID \(serviceUUID) on peripheral with UUID \(p)")
            return
        }
        
        p?.setNotifyValue(on, forCharacteristic: characteristic!)
    }
    
    func frameworkVersion() -> UInt16 {
#if BLE_DEBUG
        print("In BLE.frameworkVersion")
#endif
        return RBL_BLE_FRAMEWORK_VER
    }
    
    func readValue(serviceUUID: CBUUID, characteristicUUID: CBUUID, p: CBPeripheral?) {
#if BLE_DEBUG
        print("In BLE.readValue serviceUUID=\(serviceUUID) characteristicUUID=\(characteristicUUID) p=\(p)")
#endif
        let service: CBService? = findServiceFromUUID(serviceUUID, p: p!)
        
        if service == nil {
            print("[ERROR] Could not find service with UUID \(serviceUUID) on peripheral with UUID \(p)")
            return
        }
        
        let characteristic: CBCharacteristic? = findCharacteristicFromUUID(characteristicUUID, service: service!)
        
        if characteristic == nil {
            print("[ERROR] Could not find characteristic with UUID \(characteristicUUID) on service with UUID \(serviceUUID) on peripheral with UUID \(p)")
            return
        }
        
        p?.readValueForCharacteristic(characteristic!)
    }
    
    func writeValue(serviceUUID: CBUUID, characteristicUUID: CBUUID, p: CBPeripheral?, data: NSData?) {
#if BLE_DEBUG
        print("In BLE.writeValue serviceUUID=\(serviceUUID) characteristicUUID=\(characteristicUUID) p=\(p) data=\(data)")
#endif
        let service: CBService? = findServiceFromUUID(serviceUUID, p: p!)
        
        if service == nil {
            print("[ERROR] Could not find service with UUID \(serviceUUID) on peripheral with UUID \(p)")
            return
        }
        
        let characteristic: CBCharacteristic? = findCharacteristicFromUUID(characteristicUUID, service: service!)
        
        if characteristic == nil {
            print("[ERROR] Could not find characteristic with UUID \(characteristicUUID) on service with UUID \(serviceUUID) on peripheral with UUID \(p)")
            return
        }
        
        p?.writeValue(data!, forCharacteristic: characteristic!, type: CBCharacteristicWriteType.WithoutResponse)
    }
    
    func controlSetup() {
#if BLE_DEBUG
        print("In BLE.controlSetup")
#endif
        self.CM = CBCentralManager(delegate: self, queue: nil)
    }
    
    func findBLEPeripherals(timeout: Double) -> Bool {
#if BLE_DEBUG
        print("In BLE.findBLEPeripherals")
        print("start finding")
#endif
        
        if self.CM!.state != .PoweredOn {
            print("[ERROR] CoreBluetooth not correctly initialized!")
            print("[ERROR] State = \(self.CM!.state) (\(centralManagerStateToString(self.CM!.state)))")
            return false
        }
        
        NSTimer.scheduledTimerWithTimeInterval(timeout, target: self, selector: "scanTimer", userInfo: nil, repeats: false)
        
        self.CM!.scanForPeripheralsWithServices([CBUUID(string: RBL_SERVICE_UUID)], options: nil)
        
#if BLE_DEBUG
        print("scanForPeripheralsWithServices")
#endif
    
        return true
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
#if BLE_DEBUG
        print("In BLE.centralManager didDisconnectPeripheral")
#endif
        if error != nil {
            print("Disconnected from peripheral: \(peripheral.identifier.UUIDString). Error: \(error!.description)")
        }
        
        self.delegate?.bleDidDisconnect()
        isConnectedBool = false
    }
    
    func connectPeripheral(peripheral: CBPeripheral) -> Bool {
#if BLE_DEBUG
        print("In BLE.connectPeripheral")
        print("Connecting to peripheral with UUID: \(peripheral.identifier.UUIDString)")
#endif
        
        self.activePeripheral = peripheral
        self.activePeripheral?.delegate = self
        self.CM!.connectPeripheral(self.activePeripheral!, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(bool: true)])
        
        return true
    }
    
    func centralManagerStateToString(state: CBCentralManagerState) -> String {
#if BLE_DEBUG
        print("In BLE.centralManagerStateToString")
#endif
        switch state {
        case CBCentralManagerState.Unknown:
            return "State unknown (CBCentralManagerState.Unknown)";
        case CBCentralManagerState.Resetting:
            return "State resetting (CBCentralManagerState.Resetting)";
        case CBCentralManagerState.Unsupported:
            return "State BLE unsupported (CBCentralManagerState.Unsupported)";
        case CBCentralManagerState.Unauthorized:
            return "State unauthorized (CBCentralManagerState.Unauthorized)";
        case CBCentralManagerState.PoweredOff:
            return "State BLE powered off (CBCentralManagerState.PoweredOff)";
        case CBCentralManagerState.PoweredOn:
            return "State powered up and ready (CBCentralManagerState.PoweredOn)";
        }
    }
    
    @objc private func scanTimer() {
#if BLE_DEBUG
        print("In BLE.scanTimer")
#endif
        self.CM!.stopScan()
#if BLE_DEBUG
        print("Scanning stopped")
        print("Known peripherals: count=\(peripherals.count)")
        printKnownPeripherals()
#endif
    }
    
#if BLE_DEBUG
    func printKnownPeripherals() {
        print("In BLE.printKnownPeripherals")
        print("List of \(peripherals.count) peripherals")
    
        for var i = 0; i < peripherals.count; i++ {
            let p: CBPeripheral = peripherals[i]
            print("\ti=\(i) UUID=\(p.identifier.UUIDString)")
            print("\t       name=\(p.name!)")
            printPeripheralInfo(p)
        }
    }
    
    func printPeripheralInfo(peripheral: CBPeripheral) {
        print("In BLE.printPeripheralInfo")
        print("\tList of \(peripheral.services?.count) services")
        
        for var j = 0; j < peripheral.services?.count; j++ {
            let s: CBService = peripheral.services![j]
            
            print("\t\tj=\(j) UUID=\(s.UUID)")
            print("\t\tList of \(s.characteristics?.count) characteristic")
            
            for var k = 0; k < s.characteristics?.count; k++ {
                let c: CBCharacteristic = s.characteristics![k]
                
                print("\t\t\tk=\(k) UUID=\(c.UUID)")
                
            }
        }
    }
#endif

    func getAllServicesFromPeripheral(p: CBPeripheral) {
#if BLE_DEBUG
        print("In BLE.getAllServicesFromPeripheral")
#endif
        p.discoverServices(nil) // Discover all services without filter
    }
    
    func getAllCharacteristicsFromPeripheral(p: CBPeripheral) {
#if BLE_DEBUG
        print("In BLE.getAllCharacteristicsFromPeripheral")
#endif
        for var i = 0; i < p.services!.count; i++ {
            let s: CBService = p.services![i]
#if BLE_DEBUG
            print("Fetching characteristics for service with UUID \(s.UUID.UUIDString)")
#endif
            p.discoverCharacteristics(nil, forService: s)
        }
    }
    
    func findServiceFromUUID(UUID: CBUUID, p: CBPeripheral) -> CBService? {
#if BLE_DEBUG
        print("In BLE.findServiceFromUUID")
#endif
        for var i = 0; i < p.services!.count; i++ {
            let s: CBService = p.services![i]
            if s.UUID == UUID {
                return s
            }
        }
        return nil // Service not found on this peripheral
    }
    
    func findCharacteristicFromUUID(UUID: CBUUID, service: CBService) -> CBCharacteristic? {
#if BLE_DEBUG
        print("In BLE.findCharacteristicFromUUID")
#endif
        for var i = 0; i < service.characteristics!.count; i++ {
            let c: CBCharacteristic = service.characteristics![i]
            if c.UUID == UUID {
                return c
            }
        }
        return nil // Chacteristic not found on this service
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
#if BLE_DEBUG
        print("In BLE.centralManagerDidUpdateState")
        print("Status of CoreBluetooth central manager changed: \(central.state) (\(centralManagerStateToString(central.state)))")
#endif
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
#if BLE_DEBUG
        print("In BLE.centralManager didDiscoverPeripheral")
#endif
        
        if self.peripherals.isEmpty {
            self.peripherals.append(peripheral)
            self.peripheralsRssi.append(RSSI)
        } else {
            for var i = 0; i < self.peripherals.count; i++ {
                let p: CBPeripheral = self.peripherals[i]
                if p.identifier.UUIDString == peripheral.identifier.UUIDString {
                    peripherals[i] = peripheral
                    peripheralsRssi[i] = RSSI
#if BLE_DEBUG
                    print("Duplicate UUID found, updating...")
#endif
                    return
                }
            }
            peripherals.append(peripheral)
            peripheralsRssi.append(RSSI)
#if BLE_DEBUG
            print("New UUID, adding...")
#endif
        }
        
#if BLE_DEBUG
        print("didDiscoverPeripheral")
#endif

    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
#if BLE_DEBUG
        print("In BLE.centralManager didConnectPeripheral")
        print("Connected to peripheral \(peripheral.identifier.UUIDString) successful")
#endif
        
        self.activePeripheral = peripheral
        self.activePeripheral!.discoverServices(nil)
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
#if BLE_DEBUG
        print("In BLE.centralManager didFailToConnectPeripheral")
#endif
        print("[ERROR] Could not connect to peripheral \(peripheral.identifier.UUIDString) error: \(error!.description)")
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
#if BLE_DEBUG
        print("In BLE.peripheral didDiscoverCharacteristicsForService")
#endif
        if error == nil {
#if BLE_DEBUG
            print("Characteristics of service with UUID : \(service.UUID.UUIDString) found")
#endif
            for var i = 0; i < service.characteristics!.count; i++ {
                let c: CBCharacteristic = service.characteristics![i]
#if BLE_DEBUG
                print("Found characteristic \(c.UUID.UUIDString)")
#endif
                let s: CBService = peripheral.services![peripheral.services!.count-1]
                if s.UUID.UUIDString == service.UUID.UUIDString {
                    enableReadNotifications(activePeripheral)
                    delegate?.bleDidConnect()
                    isConnectedBool = true
                    break
                }
            }
        } else {
            print("[ERROR] Characteristic discovery unsuccessful. Error: \(error!.description)")
            return
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
#if BLE_DEBUG
        print("In BLE.peripheral didDiscoverServices")
#endif
        if error == nil {
#if BLE_DEBUG
            print("Services of peripheral with UUID : \(peripheral.identifier.UUIDString) found")
#endif
            getAllCharacteristicsFromPeripheral(peripheral)
        } else {
            print("[ERROR] Service discover was unsuccessful. Error: \(error!.description)")
            return
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
#if BLE_DEBUG
        print("In BLE.peripheral didUpdateNotificationStateForCharacteristic")
#endif
        if error == nil {
#if BLE_DEBUG
            print("Updated notification state for characteristic with UUID \(characteristic.UUID.UUIDString) on service with UUID \(characteristic.service.UUID.UUIDString) on peripheral with UUID \(peripheral.identifier.UUIDString)")
#endif
        } else {
            print("[ERROR] Error in setting notification state for characteristic with UUID \(characteristic.UUID.UUIDString) on service with UUID \(characteristic.service.UUID.UUIDString) on peripheral with UUID \(peripheral.identifier.UUIDString)")
            print("[ERROR] Error code was: \(error!.description)")
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
#if BLE_DEBUG
        print("In BLE.peripheral didUpdateValueForCharacteristic")
#endif
        if error == nil {
            if characteristic.UUID.UUIDString == RBL_CHAR_TX_UUID {
#if BLE_DEBUG
                print("characteristic.value=\(characteristic.value)")
#endif
                self.delegate?.bleDidReceiveData(characteristic.value)
            }
        } else {
            print("[ERROR] Update Value For Characteristic failed!. Error: \(error!.description)")
        }
        
    }
    
    func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
#if BLE_DEBUG
        print("In BLE.peripheral didReadRSSI")
#endif
        self.RSSICompletionHandler?(RSSI, error)
        self.RSSICompletionHandler = nil
    }

}
