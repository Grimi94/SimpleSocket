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

    private let bufferSize = 1024
    private var _host:String?
    private var _port:Int?
    private var _messagesQueue:Array<String>?
    private var inputStream: NSInputStream?
    private var outputStream: NSOutputStream?

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

    
    final func open(host:String!, port:Int!){
        self._host = host
        self._port = port

        NSStream.getStreamsToHostWithName(self._host!, port: self._port!, inputStream: &inputStream, outputStream: &outputStream)

        if inputStream != nil && outputStream != nil {

            inputStream!.delegate = self
            outputStream!.delegate = self

            inputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)
            outputStream!.scheduleInRunLoop(.mainRunLoop(), forMode: NSDefaultRunLoopMode)

            println("[SKT]: Open Stream")

            self._messagesQueue = Array()

            inputStream!.open()
            outputStream!.open()
        } else {
            println("[SKT]: Failed Getting Streams")
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
                break;

            case NSStreamEvent.ErrorOccurred:
                println("[SKT]: ErrorOccurred: \(stream.streamError?.description)")

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
