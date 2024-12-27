//
//  ContentView.swift
//  SocketServer
//
//  Created by Jorge Mendoza on 12/19/24.
//

import SwiftUI
import Foundation
import Network
import SystemConfiguration


struct ContentView: View {
    @State private var ipText:String = ""
    @State var isListening:Bool = false
    @State var actionLog:String = ""
    @State var listener: NWListener?
    var body: some View {
        VStack(alignment: .leading) {
            Text("Fun Socket Server")
                .font(.title)
                .fontWeight(.semibold)
            HStack{
                Text("Current IP Address: **\(ipText)**")
                refreshIPButton
            }
            Button{
                if !isListening {
                    self.startListening(port: 8080)
                    isListening = true
                } else {
                    self.listener?.cancel()
                    isListening =  false
                }
            } label: {
                Label(isListening ? "Server Started" : "Start Server", systemImage: isListening ? "pause.circle" : "play.circle")
                    .fontWeight(.semibold)
                    .padding(4)
            }
            Divider()
            TextEditor(text: $actionLog).frame(height: 100)
            Spacer()
        }.frame(maxWidth: 400, alignment: .leading)
        .onAppear{
            ipText = self.getIPAddress() ?? "N/A"
        }
        .padding()
    }
    
    @ViewBuilder var refreshIPButton: some View {
        Button {
            ipText = self.getIPAddress() ?? "N/A"
        } label: {
            Label("Refresh IP", systemImage: "arrow.trianglehead.clockwise")
                .fontWeight(.semibold)
                .padding(4)
        }
    }
}

extension ContentView {
    func startListening(port: UInt16) {
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.newConnectionHandler = { connection in
                connection.start(queue: .main)
                self.receiveText(from: connection)
            }
            
            listener?.start(queue: .main)
            self.actionLog += self.addActionLog(with: "Server started on port \(port)")
        } catch {
            self.actionLog += self.addActionLog(with: "Failed to start listener: \(error)")
        }
    }
    
    private func receiveText(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { sizeData, _, _, error in
            if let error = error {
                self.actionLog += self.addActionLog(with: "Error receiving size data: \(error.localizedDescription)")
                connection.cancel()
                return
            }
            
            guard let sizeData = sizeData, sizeData.count == 4 else {
                self.actionLog += self.addActionLog(with: "Failed to receive data size")
                connection.cancel()
                return
            }
            
            let dataSize = sizeData.withUnsafeBytes { UInt32(bigEndian: $0.load(as: UInt32.self)) }
            
            connection.receive(minimumIncompleteLength: Int(dataSize), maximumLength: Int(dataSize)) { textData, _, isComplete, error in
                if let error = error {
                    self.actionLog += self.addActionLog(with: "Error receiving text data: \(error.localizedDescription)")
                    connection.cancel()
                    return
                }
                
                guard let textData = textData, textData.count == dataSize else {
                    self.actionLog += self.addActionLog(with: "Failed to receive complete data")
                    connection.cancel()
                    return
                }
                
                // Decode and print the incoming text
                if let incomingText = String(data: textData, encoding: .utf8) {
                    self.actionLog += self.addActionLog(with: "Received text: \(incomingText)")
                } else {
                    self.actionLog += self.addActionLog(with: "Failed to decode text data")
                }
                self.actionLog += self.addActionLog(with: "Data size: \(dataSize)")
                
                if isComplete {
                    self.actionLog += self.addActionLog(with: "Connection completed")
                    connection.cancel()
                }
            }
        }
    }
}

extension View {
    func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        
        if getifaddrs(&ifaddr) == 0 {
            var pointer = ifaddr
            while pointer != nil {
                defer { pointer = pointer?.pointee.ifa_next }
                
                let interface = pointer!.pointee
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(
                            interface.ifa_addr,
                            socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        ) == 0 {
                            address = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    func addActionLog(with detail:String) -> String {
        let now = Date()
        return "\(now.formatted(date: .abbreviated, time: .complete)): \(detail) \n"
    }
}

#Preview {
    ContentView()
}
