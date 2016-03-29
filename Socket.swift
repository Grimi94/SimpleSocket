//
//  SocketManager.swift
//
//
//  Created by Grimi on 6/21/15.
//
//

import UIKit

@objc protocol SocketStreamDelegate{
    func socketDidConnect(stream:NSStream)
    optional func socketDidDisconnet(stream:NSStream, message:String)
    optional func socketDidReceiveMessage(stream:NSStream, message:String)
    optional func socketDidEndConnection()
}

class Socket: NSObject, NSStreamDelegate {
    var delegate:SocketStreamDelegate?

    private let bufferSize = 1024
    private var _host:String?
    private var _port:Int?
    private var _messagesQueue:Array<String> = [String]()
    private var _streamHasSpace:Bool = false
    private var inputStream: NSInputStream?
    private var outputStream: NSOutputStream?
    private var token: dispatch_once_t = 0

    var host:String?{
        get{
            return self._host
        }
    }

    var port:Int?{
        get{
            return self._port
        }
    }

    deinit{
        if let inputStr = self.inputStream{
            inputStr.close()
            inputStr.removeFromRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        }
        if let outputStr = self.outputStream{
            outputStr.close()
            outputStr.removeFromRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        }
    }

    /**
    Opens streaming for both reading and writing, error will be thrown if you try to send a message and streaming hasn't been opened

    :param: host String with host portion
    :param: port Port
    */
    final func open(host:String!, port:Int!){
        self._host = host
        self._port = port

        if #available(iOS 8.0, *) {
            NSStream.getStreamsToHostWithName(self._host!, port: self._port!, inputStream: &inputStream, outputStream: &outputStream)
        } else {
            var inStreamUnmanaged:Unmanaged<CFReadStream>?
            var outStreamUnmanaged:Unmanaged<CFWriteStream>?
            CFStreamCreatePairWithSocketToHost(nil, host, UInt32(port), &inStreamUnmanaged, &outStreamUnmanaged)
            inputStream = inStreamUnmanaged?.takeRetainedValue()
            outputStream = outStreamUnmanaged?.takeRetainedValue()
        }

        if inputStream != nil && outputStream != nil {

            inputStream!.delegate = self
            outputStream!.delegate = self

            inputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
            outputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)

            print("[SCKT]: Open Stream")

            self._messagesQueue = Array()

            inputStream!.open()
            outputStream!.open()
        } else {
            print("[SCKT]: Failed Getting Streams")
        }
    }

    /**
    NSStream Delegate Method where we handle errors, read and write data from input and output streams

    :param: stream NStream that called delegate method
    :param: eventCode      Event Code
    */
    final func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
            case NSStreamEvent.EndEncountered:
                endEncountered(stream)

            case NSStreamEvent.ErrorOccurred:
                print("[SCKT]: ErrorOccurred: \(stream.streamError?.description)")

            case NSStreamEvent.OpenCompleted:
                openCompleted(stream)

            case NSStreamEvent.HasBytesAvailable:
                handleIncommingStream(stream)

            case NSStreamEvent.HasSpaceAvailable:
                print("space available")
                writeToStream()
                break;

            default:
                break;
        }
    }

    final func endEncountered(stream:NSStream){

    }

    final func openCompleted(stream:NSStream){
        if(self.inputStream?.streamStatus == .Open && self.outputStream?.streamStatus == .Open){

            dispatch_once(&token) {
                self.delegate?.socketDidConnect(stream)
            }
        }
    }

    /**
    Reads bytes asynchronously from incomming stream and calls delegate method socketDidReceiveMessage

    :param: stream An NSInputStream
    */
    final func handleIncommingStream(stream: NSStream){
        if let inputStream = stream as? NSInputStream {
            var buffer = Array<UInt8>(count: bufferSize, repeatedValue: 0)

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                let bytesRead = inputStream.read(&buffer, maxLength: 1024)

                if bytesRead >= 0 {
                    if let output = NSString(bytes: &buffer, length: bytesRead, encoding: NSUTF8StringEncoding){
                        self.delegate?.socketDidReceiveMessage!(stream, message: output as String)
                    }
                } else {
                    // Handle error
                }
                
            })
        } else {
            print("[SCKT]: \(#function) : Incorrect stream received")
        }

    }

    /**
    If messages exist in _messagesQueue it will remove and it and send it, if there is an error
    it will return the message to the queue
    */
    final func writeToStream(){
        if _messagesQueue.count > 0 && self.outputStream!.hasSpaceAvailable  {


            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                let message = self._messagesQueue.removeLast()
                let data: NSData = message.dataUsingEncoding(NSUTF8StringEncoding)!
                var buffer = [UInt8](count:data.length, repeatedValue:0)
                data.getBytes(&buffer, length:data.length * sizeof(UInt8))

                //An error ocurred when writing
                if self.outputStream!.write(&buffer, maxLength: data.length) == -1 {
                    self._messagesQueue.append(message)
                }
            })

        }
    }

    final func send(message:String){
        _messagesQueue.insert(message, atIndex: 0)

        writeToStream()
    }
}
