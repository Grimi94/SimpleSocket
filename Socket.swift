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
    var delegate:SocketStreamDelegate?
    var _host:String?
    var _port:Int?

    let bufferSize = 1024

    private var inputStream: NSInputStream?
    private var outputStream: NSOutputStream?


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
            println("[SKT]: Failed Getting Streams")
        }
    }

    /**
    NSStream Delegate Method

    :param: incomingStream <#incomingStream description#>
    :param: eventCode      <#eventCode description#>
    */
    final func stream(stream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch eventCode {
            case NSStreamEvent.ErrorOccurred:
                println("[SKT] ErrorOccurred: \(stream.streamError?.description)")
            case NSStreamEvent.OpenCompleted:
                break;
            case NSStreamEvent.HasBytesAvailable:
                handleIncommingStream(stream)
            case NSStreamEvent.HasSpaceAvailable:
                break;
            default:
                break;
        }
    }

    /**
    Reads bytes asynchronously from incomming stream and calls delegate method socketDidReceiveMessage

    :param: stream An NSInputStream
    */
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
