//
//  ViewController.swift
//  MotionXSwift
//
//  Created by Liu Yong on 15/5/2.
//  Copyright (c) 2015年 Liu Yong. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreLocation

import AVFoundation

let SENSOR_TYPE_KEY:UInt8 = (0x01<<0)
let SENSOR_TYPE_MPU6050_ACC:UInt8 = (0x01<<1)
let SENSOR_TYPE_MPU6050_ENERGY:UInt8 = (0x01<<2)
let SENSOR_TYPE_MPU6050_GROY:UInt8 = (0x01<<3)
let SENSOR_TYPE_MPU6050_TEMP:UInt8 = (0x01<<4)
let SENSOR_TYPE_BMP180_TEMP:UInt8 = (0x01<<5)
let SENSOR_TYPE_BMP180_PRESS:UInt8 = (0x01<<6)


class ViewController: UIViewController ,CBCentralManagerDelegate,CBPeripheralDelegate, ChartDelegate{
    
    var cbCM:CBCentralManager!
    //var nServices:NSMutableArray!
    //var nCharacteristics: NSMutableArray!
    
    var cbPerpheral: CBPeripheral!
    var MotionX_Service: CBService!
    var DATA_Chara:CBCharacteristic!
    var Notify_Chara:CBCharacteristic!
    
    var beaconRegion : CLBeaconRegion!
    
    var synthesizer:AVSpeechSynthesizer!
    
    //@IBOutlet
    //@IBOutlet weak var dbgText: UITextView!
    var dbgText: UITextView?
    var dbgCount:Int32=0
    var startStopButton: UIButton? //启动/停止按钮
    var inputText:UITextField?
    var cmdButtons: [UIButton]? //设置时间的按钮数组
    
    let timeButtonInfos = [("时间同步", "T"), ("读数据", "M0"), ("温度气压", "P"), ("BTAdd", "N")]
    
    var chart:Chart!
    var chartColor = [UIColor]()
    
    var xcount = 0
    var beaconKV = [Int:Int]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        cbCM = CBCentralManager (delegate: self, queue: nil);
        
        synthesizer = AVSpeechSynthesizer();
        
        addAppCompomentAndLayout()
        
    }
    
    func addAppCompomentAndLayout(){
        
        //Create dbgText TextView
        dbgText = UITextView()
        dbgText!.backgroundColor = UIColor(red: 205/255.0, green: 252/255.0, blue: 234/255.0, alpha: 1.0)
        dbgText!.frame = CGRectMake(0, self.view.bounds.height-110, self.view.bounds.width, 100)
        self.view.addSubview(dbgText!)
        
        //create start/stop button
        startStopButton = UIButton()
        startStopButton!.backgroundColor = UIColor.lightGrayColor()
        startStopButton!.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
        startStopButton!.setTitleColor(UIColor.blackColor(), forState: UIControlState.Highlighted)
        startStopButton!.setTitle("启动/停止", forState: UIControlState.Normal)
        startStopButton!.addTarget(self, action: "startStopButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        startStopButton!.frame = CGRectMake(self.view.bounds.width*5/8, 30,self.view.bounds.width/4 , 30)
        self.view.addSubview(startStopButton!)
        
        //Create inputText TextField
        inputText = UITextField()
        inputText!.frame = CGRectMake(10, 30,self.view.bounds.width/2 , 30)
        inputText!.backgroundColor = UIColor(red: 246/255.0, green: 205/255.0, blue: 229/255.0, alpha: 1.0)
        inputText!.borderStyle = UITextBorderStyle.RoundedRect
        inputText!.returnKeyType = UIReturnKeyType.Done
        inputText!.text = "T"
        inputText!.addTarget(self, action: "editFinish:", forControlEvents: UIControlEvents.EditingDidEndOnExit)
        self.view.addSubview(inputText!)
        
        //cmd button
        var buttons: [UIButton] = []
        for (index, (title, _)) in enumerate(timeButtonInfos) {
            let button: UIButton = UIButton()
            button.tag = index //保存按钮的index
            button.setTitle("\(title)", forState: UIControlState.Normal)
            button.backgroundColor = UIColor(red: 246/255.0, green: 205/255.0, blue: 229/255.0, alpha: 1.0)
            
            button.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
            button.setTitleColor(UIColor.blackColor(), forState: UIControlState.Highlighted)
            button.addTarget(self, action: "timeButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
            var m = self.view.bounds.width/CGFloat(8)/CGFloat(timeButtonInfos.count)
            button.frame = CGRectMake((CGFloat(index)*8+1)*m, 70.0, 7*m, 30.0)
            //buttons += button
            buttons.append(button);
            self.view.addSubview(button)
        }
        cmdButtons = buttons
        
        chart = Chart()
        chart!.frame = CGRectMake(0, 100, self.view.frame.width, self.view.bounds.height-220)
        chart!.delegate = self
        
        chartColor.append(ChartColors.redColor())
        chartColor.append(ChartColors.yellowColor())
        chartColor.append(ChartColors.purpleColor())
        chartColor.append(ChartColors.greenColor())
        chartColor.append(ChartColors.blueColor())
        chartColor.append(ChartColors.cyanColor())
        
        chart.addSeries([])
        
        
        self.view.addSubview(chart)
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        inputText!.frame = CGRectMake(10, 30,size.width/2 , 30)
        startStopButton!.frame = CGRectMake(size.width*5/8, 30,size.width/4 , 30)
        
        for (index, (title, _)) in enumerate(timeButtonInfos) {
            var button = cmdButtons![index]
            var m = size.width/CGFloat(8)/CGFloat(timeButtonInfos.count)
            button.frame = CGRectMake((CGFloat(index)*8+1)*m, 70.0, 7*m, 30.0)
        }
        
        chart!.frame = CGRectMake(0, 100, size.width, size.height-220)
        dbgText!.frame = CGRectMake(0, size.height-110, size.width, 100)
        // Redraw chart on rotation
        chart.setNeedsDisplay()
        
    }
    
    // Chart delegate
    
    func didTouchChart(chart: Chart, indexes: Array<Int?>, x: Float, left: CGFloat) {
        for (seriesIndex, dataIndex) in enumerate(indexes) {
            if let value = chart.valueForSeries(seriesIndex, atIndex: dataIndex) {
                println("Touched series: \(seriesIndex): data index: \(dataIndex!); series value: \(value); x-axis value: \(x) (from left: \(left))")
            }
        }
    }
    
    func didFinishTouchingChart(chart: Chart) {
        
    }
    
    func timeButtonTapped(sender: UIButton) {
        let (_, cmdStr) = timeButtonInfos[sender.tag]
        //remainingSeconds += seconds
        inputText!.text = cmdStr
        updateLog("btn=\(cmdStr)")
        if "N" == cmdStr {
            dbgText!.text = " "
            chart.removeSeries()
            xcount = 0
            beaconKV.removeAll(keepCapacity: false)
            chart.setNeedsDisplay()
        }
        if "T" == cmdStr {

        }
    }
    
    func editFinish(sender:UITextField){
        self.startStopButton! .becomeFirstResponder()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func Say(someText:String)
    {
        //var myString:String = someText;
        
        var utterance:AVSpeechUtterance  = AVSpeechUtterance(string: someText) //(string:myString)
        
        //[AVSpeechUtterance speechUtteranceWithString,:someText];
        //设置语言类别（不能被识别，返回值为nil）
        var voiceType=AVSpeechSynthesisVoice(language: "zh-CN");
        //AVSpeechSynthesisVoice *voiceType = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
        
        utterance.voice = voiceType;
        //设置语速快慢
        utterance.rate *= 0.75;
        //语音合成器会生成音频
        synthesizer.speakUtterance(utterance);
    }
    func updateLog(log : String)
    {
        println(log);
        dbgText!.text = "[\(dbgCount++)]\(log)\r\n" + dbgText!.text
        if(dbgCount == 2000) {
            dbgText!.text = " "
        }
        //Say(log)
    }
    
    //delegate of CBCentralManager
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        //updateLog(central.description)
        switch(central.state)
        {
            //case .Resetting:
        case .PoweredOn:
            [cbCM .scanForPeripheralsWithServices(nil, options: nil)];
        default:
            println(central.state);
        }
    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        updateLog("Discover peripheral:\(peripheral.name)\r\n")
        Say("\(peripheral.name)")
        if peripheral.name != nil {
            if(peripheral.name == "MotionX")
            {
                cbPerpheral = peripheral
                cbCM .connectPeripheral(peripheral, options: nil)
                cbCM .stopScan()
            }
        }
    }
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        updateLog("Disconnect peripheral:\(peripheral.name) !!!\r\n")
        startStopButton!.backgroundColor = UIColor.grayColor()
        cbCM .scanForPeripheralsWithServices(nil, options: nil)
    }
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        updateLog("\(peripheral.name) Connected!")
        Say("Connected \(peripheral.name)")
        peripheral.delegate = self
        cbPerpheral .discoverServices(nil)
    }
    
    //delegate of CBPeripheral
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        //updateLog("CBPeripheralDelegate didDiscoverServices")
        for  service in peripheral.services {
            updateLog("Find Service: \(service.UUID)")
            if(service.UUID == CBUUID(string: "AAA0")){
                updateLog("MotionX_Service found!")
                MotionX_Service = (service as! CBService)
                peripheral.discoverCharacteristics(nil , forService: MotionX_Service)
            }
            /*else if(service.UUID == CBUUID(string: "1803")){
            updateLog("Link_Loss_Service")
            var linkLossAlertService = (service as! CBService)
            peripheral.discoverCharacteristics(nil , forService: linkLossAlertService)
            }*/
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        updateLog("Find Char in service: (\(service.UUID))")
        for c in service.characteristics
        {
            if(c.UUID == CBUUID(string: "AAA1"))
            {
                Notify_Chara = (c as! CBCharacteristic)
                cbPerpheral .setNotifyValue(true, forCharacteristic:Notify_Chara)
                startStopButton!.backgroundColor = UIColor.greenColor()
                Say("Foud Motion X Service")
            }
            if(c.UUID == CBUUID(string: "AAA2"))
            {
                DATA_Chara = (c as! CBCharacteristic)
            }
            
            
        }
    }
    
    //define state machine
    var last_addr:UInt16 = 0
    var sm_x  = "R" //R->C->T->L->V-> C->T->L->V-> C->T->L->V->
    var sm_R:Int32 = 0
    var sm_C:Int32 = 0
    var sm_T:UInt8 = 0
    var sm_L = 0
    var sm_V = [UInt8]()
    var sm_V_LEN = 0
    //
    
    func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if(error != nil){
            updateLog("Error Reading characteristic value: \(error.localizedDescription)")
        }else{
            var data = characteristic.value
            //updateLog("Update value is \(data)")
            //把NSData的值存到byteArray中
            var byteArray:[UInt8] = [UInt8]()
            for i in 0..<data.length {
                var temp:UInt8 = 0
                data.getBytes(&temp, range: NSRange(location: i,length:1 ))
                byteArray.append(temp)
            }
            //updateLog("Byte Array:\(byteArray)")
            switch(byteArray[0])
            {
            case 88://X
                switch (byteArray[8])
                {
                case SENSOR_TYPE_BMP180_TEMP|SENSOR_TYPE_BMP180_PRESS:
                    var temp:UInt16 = (((UInt16)(byteArray[10+0]))<<8) + (UInt16)(byteArray[10+1]);
                    var press:UInt32 = (((UInt32)(byteArray[10+2]))<<24)+(((UInt32)(byteArray[10+3]))<<16)+(((UInt32)(byteArray[10+4]))<<8)+(UInt32)(byteArray[10+5]);
                    var alt:Float = 44330.0 * (1.0 - powf((Float(press) / 101325.0), 1 / 5.255))
                    updateLog("temp=\(temp),press=\(press),Alt=\(alt)" )
                    /*
                    xcount++
                    if chart.series.count == 0 {
                    let series = ChartSeries([Float(alt)])
                    series.color = chartColor[0]
                    chart.addSeries(series)
                    }else{
                    chart.valueINSeries(0, insertX:  Float( xcount), insertY:Float(alt))
                    }
                    chart.setNeedsDisplay()
                    */
                    break;
                case (SENSOR_TYPE_MPU6050_ACC + SENSOR_TYPE_MPU6050_ENERGY):
                    var energy:UInt16 = ((UInt16)(byteArray[10+0])<<8)+(UInt16)(byteArray[10+1]);
                    var count:UInt32 = ((UInt32)(0x00000001)) << ((UInt32)( byteArray[10+2]));
                    //[3]x,[4]y,[5]z
                    updateLog("Energy=\(energy),count=\(count),X=\((Int16)(byteArray[10+3])),y=\((Int16)(byteArray[10+4])),z=\((Int16)(byteArray[10+5]))")
                    break;
                case SENSOR_TYPE_KEY:
                    //[1] key  [2~5]period
                    var period = (((UInt32)(byteArray[10+2]))<<24)+(((UInt32)(byteArray[10+3]))<<16)+(((UInt32)(byteArray[10+4]))<<8)+(UInt32)(byteArray[10+5])
                    updateLog("%@ key=\(byteArray[10+1]),period=\(period)")
                    Say("按键\(byteArray[10+1]) \(period)毫秒")
                    break;
                default:
                    updateLog("!!!!Uknow Type:\(byteArray[8])")
                    break;
                }//switch (sm_T) Type
                break
            case 0x54 ://T Time
                let time = "2000-01-01 00:00:00 +000"
                var dateForm = NSDateFormatter()
                dateForm.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
                let da = dateForm.dateFromString(time)
                updateLog("da:\(da)")
                //let x = Int32( 0 - da!.timeIntervalSinceNow)
                let rtcOffsetOld = (((Int32)(byteArray[2]))<<24)+(((Int32)(byteArray[3]))<<16)+(((Int32)(byteArray[4]))<<8)+(Int32)(byteArray[5])
                let rtcOffsetNew = (((Int32)(byteArray[6]))<<24)+(((Int32)(byteArray[7]))<<16)+(((Int32)(byteArray[8]))<<8)+(Int32)(byteArray[9])
                let rtcClockBle  = (((Int32)(byteArray[10]))<<24)+(((Int32)(byteArray[11]))<<16)+(((Int32)(byteArray[12]))<<8)+(Int32)(byteArray[13])
                let oldday = NSDate(timeInterval: NSTimeInterval( rtcOffsetOld + rtcClockBle), sinceDate: da!)
                let newday = NSDate(timeInterval: NSTimeInterval(rtcOffsetNew + rtcClockBle), sinceDate: da!)
                updateLog("OldTime: \(rtcOffsetOld),\(oldday) NewTime:\(rtcOffsetNew),\(newday) \r\n TimeDiff=\(rtcOffsetOld - rtcOffsetNew) !")
                if(rtcOffsetOld > rtcOffsetNew){
                    updateLog("蓝牙设备时钟快了\(rtcOffsetOld - rtcOffsetNew)秒！")
                }else {
                    updateLog("蓝牙设备时钟慢了\(rtcOffsetNew - rtcOffsetOld)秒！")
                }
                break
            case 0x4D : // "M"
                updateLog("M Address Read Byte Array:\(byteArray)")
                let Addr = (UInt16(byteArray[2]) << 8) + (UInt16(byteArray[3]) )
                if((Addr & 0x1FF) == 0 ){
                    sm_x = "R"
                    sm_R = 0
                    sm_C = 0
                    last_addr = Addr
                }else
                {
                    if( Addr - last_addr == 4)
                    {
                        last_addr = Addr
                    }else
                    {
                        break;
                    }
                }
                var read_index = 4
                do {
                    switch (sm_x){
                    case "R":  //(((Int32)(byteArray[2]))<<24)
                        sm_R =  ((Int32)(byteArray[read_index]))<<24  + (((Int32)(byteArray[read_index + 1]))<<16)
                            + (((Int32)(byteArray[read_index + 2]))<<8) + (Int32)(byteArray[read_index + 3])
                        if(0 > sm_R) {
                            last_addr = (last_addr & 0xFE00) + 0x0200 - 4
                            updateLog("Page Empty\(Addr)\r\n")
                            sm_x = "R"
                            break
                        }
                        read_index += 4
                        sm_x = "C"
                        break
                    case "C":
                        sm_C = (((Int32)(byteArray[read_index]))<<24)+(((Int32)(byteArray[read_index + 1]))<<16) +
                            (((Int32)(byteArray[read_index + 2]))<<8)+(Int32)(byteArray[read_index + 3])
                        read_index += 4
                        if(0 > sm_C) {
                            last_addr = (last_addr & 0xFE00) + 0x0200 - 4
                            updateLog("Page data end \(Addr)\r\n")
                            sm_x = "R"
                            break
                        }
                        sm_x = "T"
                        break
                    case "T":
                        sm_T = byteArray[read_index++]
                        //if(1 != sm_T)
                        if((1 != sm_T)  && (6 != sm_T) && (0x60 != sm_T))
                        {
                            read_index = 20
                            break
                        }
                        sm_x = "L"
                        break
                    case "L":
                        sm_L = Int( byteArray[read_index++] - 2)
                        sm_x = "V";
                        break
                    case "V":
                        if(0 == sm_V_LEN)
                        {
                            if( read_index + Int32(sm_L)  <=  20)
                            {
                                //可以解析了[read_index,sm_L]
                                for x in 0..<sm_L
                                {
                                    sm_V.append(byteArray[read_index++])
                                }
                                sm_x = "C";
                            }else
                            {
                                //拷贝到BUFFER
                                sm_V_LEN = 20 - read_index
                                for x in 0..<sm_V_LEN
                                {
                                    sm_V.append(byteArray[read_index++])
                                }
                                read_index = 20
                                break;
                            }
                        }else
                        {
                            //拷贝剩下的到BUFFER，然后解析
                            for x in 0..<(sm_L - sm_V_LEN)
                            {
                                sm_V.append(byteArray[read_index++])
                            }
                            sm_V_LEN = 0
                            sm_x = "C"
                        }
                        //解析
                        let time = "2000-01-01 00:00:00 +000"
                        var dateForm = NSDateFormatter()
                        dateForm.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
                        let da = dateForm.dateFromString(time)
                        //updateLog("da:\(da)")
                        let rtcx = NSDate(timeInterval: NSTimeInterval(sm_R + sm_C), sinceDate: da!)
                        updateLog("Paser: array=\(sm_V),t=\(sm_T),l=\(sm_L)")
                        switch (sm_T){
                        case 0x60: //
                            //let press = (((UInt32)(byteArray[10+2]))<<24)+(((UInt32)(byteArray[10+3]))<<16)+(((UInt32)(byteArray[10+4]))<<8)+(UInt32)(byteArray[10+5])
                            let press = (((UInt32)(sm_V[2]))<<24)+(((UInt32)(sm_V[3]))<<16)+(((UInt32)(sm_V[4]))<<8)+(UInt32)(sm_V[5]);
                            var alt:Float = 44330.0 * (1.0 - powf((Float(press) / 101325.0), 1 / 5.255))
                            updateLog("DATA: \(rtcx): \(press)  Pa: \(alt)m @ \(sm_R + sm_C)")
                            //
                            xcount++
                            if chart.series.count == 0 {
                                let series = ChartSeries([Float(alt)])
                                series.color = chartColor[0]
                                chart.addSeries(series)
                            }else{
                                chart.valueINSeries(0, insertX:  Float( xcount), insertY:Float(alt))
                            }
                            chart.setNeedsDisplay()
                            //
                            break
                        default :
                            break
                        }
                        sm_V.removeAll(keepCapacity: false)
                        break //case v
                    default:
                        
                        break
                    }
                }while((read_index<20) && (last_addr == Addr))
                if(byteArray[0] == 0x4D ) //"M")
                {
                    if(Addr < 0x9000 + 0x200 * 50){
                    //if((Addr & 0x01FF) + 4 < 0x01FF ){
                        var NextPageCmd =  [UInt8](count: 20, repeatedValue: 0)
                        NextPageCmd[0] = 0x4D
                        NextPageCmd[1] = 0x4D
                        NextPageCmd[2] = (UInt8)((last_addr + 4) >> 8) & 0xFF
                        NextPageCmd[3] = (UInt8)((last_addr + 4) & 0xFF)
                        cbPerpheral .writeValue(NSData(bytes: NextPageCmd, length: 20) ,
                            forCharacteristic: DATA_Chara,
                            type: CBCharacteristicWriteType.WithResponse)
                    }
                }
                //add before
                break
            default:
                updateLog("Unknown Byte Array:\(byteArray)")
            }
        }
        
    }
    
    func startStopButtonTapped(sender: UIButton) {
        if(inputText!.text.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)==0)
        {
            updateLog(inputText!.text)
            return
        }
        if(cbPerpheral != nil)
        {
            if(cbPerpheral.state != CBPeripheralState.Connected)
            {
                updateLog("Connect Again!")
                [cbCM .scanForPeripheralsWithServices(nil, options: nil)]
            }
        }
        
        var cmdValues =  [UInt8](count: 20, repeatedValue: 0)
        var cmdString = inputText!.text
        switch (cmdString[cmdString.startIndex])
        {
        case "M":
            var addr:UInt16 = 0x9000;
            var addrStr = (cmdString as NSString).substringFromIndex(1)
            let addrx = (addrStr.toInt()! * 0x200) + Int(addr)
            updateLog("Read Page address =\(addrx)")
            cmdValues[0] = 0x4D //M
            cmdValues[1] =  0x4D
            cmdValues[2] = UInt8((addrx>>8)&0xFF)
            cmdValues[3] = UInt8(addrx&0xFF)
            
            cbPerpheral .writeValue(NSData(bytes: cmdValues, length: 20) ,
                forCharacteristic: DATA_Chara,
                type: CBCharacteristicWriteType.WithResponse)
            
            break;
        case "N":
            cmdValues[0] = 0x4E //UInt8 (s: cmdString[cmdString.startIndex])
            cbPerpheral .writeValue(NSData(bytes: cmdValues, length: 20) ,
                forCharacteristic: DATA_Chara,
                type: CBCharacteristicWriteType.WithResponse)
            break
        case "P":
            cmdValues[0] = 0x50
            cbPerpheral .writeValue(NSData(bytes: cmdValues, length: 20) ,
                forCharacteristic: DATA_Chara,
                type: CBCharacteristicWriteType.WithResponse)
            break
        case "E": //erase
                cmdValues[0] = 0x45
                cbPerpheral .writeValue(NSData(bytes: cmdValues, length: 20) ,
                    forCharacteristic: DATA_Chara,
                    type: CBCharacteristicWriteType.WithResponse)
            break
            case "T":
            cmdValues[0] = 0x54
            cmdValues[1] = 0
            let time = "2000-01-01 00:00:00 +000"
            var dateForm = NSDateFormatter()
            dateForm.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
            let da = dateForm.dateFromString(time)
            updateLog("da:\(da)")
            let x = Int32( 0 - da!.timeIntervalSinceNow)
            cmdValues[2] = UInt8(( x >> 24) & 0xFF)
            cmdValues[3] = UInt8(( x >> 16) & 0xFF)
            cmdValues[4] = UInt8(( x >> 8) & 0xFF)
            cmdValues[5] = UInt8(( x >> 0) & 0xFF)
            cbPerpheral .writeValue(NSData(bytes: cmdValues, length: 20) ,
                forCharacteristic: DATA_Chara,
                type: CBCharacteristicWriteType.WithResponse)
            break

            
            
            
        default:
            println("\(cmdString[cmdString.startIndex]) !!!")
        }
        
        
    }
    
    
}

