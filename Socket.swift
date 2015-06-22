//
//  SocketManager.swift
//
//
//  Created by Grimi on 6/21/15.
//
//

import UIKit

protocol SocketStreamDelegate{
    func socketDidConnect(stream:NSStream)
    func socketDidDisconnet(stream:NSStream, message:String)
    func socketDidReceiveMessage(stream:NSStream, message:String)
}

class Socket: NSObject, NSStreamDelegate {
    var _host:String?
    var _port:Int?
    let bufferSize = 1024
    private var inputStream: NSInputStream?
    private var outputStream: NSOutputStream?
    var delegate:SocketStreamDelegate?

    deinit{
        if let inputStr = self.inputStream{
            inputStr.close()
        }
        if let outputStr = self.outputStream{
            outputStr.close()
        }
    }

    final func open(host:String!, port:Int!){
        self._host = host
        self._port = port

        NSStream.getStreamsToHostWithName(self._host!, port: self._port!, inputStream: &inputStream, outputStream: &outputStream)

        if inputStream != nil && outputStream != nil {

            inputStream!.delegate = self
            outputStream!.delegate = self

            inputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
            outputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)

            println("Socket: Open Stream")

            inputStream!.open()
            outputStream!.open()
        } else {
            println("Socket: Failed Getting Streams")
        }
    }

    final func stream(incomingStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        if incomingStream.isKindOfClass(NSInputStream) {
            switch eventCode {
            case NSStreamEvent.ErrorOccurred:
                println("input: ErrorOccurred: \(incomingStream.streamError?.description)")
            case NSStreamEvent.OpenCompleted:
                println("input: OpenCompleted")
            case NSStreamEvent.HasBytesAvailable:
//                println("input: HasBytesAvailable")
                handleIncommingStream(incomingStream)

            default:
                break;
            }
        }
        else if incomingStream.isKindOfClass(NSOutputStream) {
            switch eventCode {
            case NSStreamEvent.ErrorOccurred:
                println("output: ErrorOccurred: \(incomingStream.streamError?.description)")
            case NSStreamEvent.OpenCompleted:
                println("output: OpenCompleted")
            case NSStreamEvent.HasSpaceAvailable:
                println("output: HasSpaceAvailable")

            default:
                break;
            }
        }
        
    }

    final func handleIncommingStream(stream: NSStream){
        var buffer = Array<UInt8>(count: bufferSize, repeatedValue: 0)

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
            let bytesRead = (stream as! NSInputStream).read(&buffer, maxLength: 1024)

            if bytesRead >= 0 {
                if let output = NSString(bytes: &buffer, length: bytesRead, encoding: NSUTF8StringEncoding){
                    self.delegate?.socketDidReceiveMessage(stream, message: output as String)
                }

            } else {
                // Handle error
            }

        })


    }
}
