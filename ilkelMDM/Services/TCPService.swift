//
//  TCPService.swift
//  ilkelMDM
//
//  TCP client: Apple Network framework ile Java TCP Server'a bağlanır.
//  Her JSON paketi sonuna newline (\n) eklenir (Java readLine() uyumluluğu).
//

import Foundation
import Network

final class TCPService {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.ilkelMDM.tcp")

    init() {
        connect()
    }

    private func connect() {
        let host = NWEndpoint.Host(TCPConfig.host)
        let port = NWEndpoint.Port(rawValue: TCPConfig.port)!
        connection = NWConnection(host: host, port: port, using: .tcp)
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[TCP] Bağlantı kuruldu: \(TCPConfig.host):\(TCPConfig.port)")
            case .failed(let error):
                print("[TCP] Bağlantı hatası: \(error.localizedDescription)")
            case .waiting(let error):
                print("[TCP] Beklemede (sunucu erişilemiyor olabilir): \(error.localizedDescription)")
            case .cancelled:
                print("[TCP] Bağlantı iptal edildi")
            default:
                break
            }
        }
        connection?.start(queue: queue)
    }

    /// JSON'ı encode edip sonuna newline (\n) ekleyerek gönderir (Java readLine() uyumlu).
    /// DeviceInventoryPayload ve TokenRegistrationPayload aynı metodu kullanır.
    func send<T: Encodable>(_ payload: T, completion: ((Bool) -> Void)? = nil) {
        guard let jsonData = try? JSONEncoder().encode(payload),
              var jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[TCP] JSON encode hatası")
            completion?(false)
            return
        }
        jsonString += "\n"

        guard let data = jsonString.data(using: .utf8) else {
            print("[TCP] UTF-8 encode hatası")
            completion?(false)
            return
        }

        guard connection != nil else {
            completion?(false)
            return
        }

        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[TCP] Gönderim hatası: \(error.localizedDescription)")
            }
            completion?(error == nil)
        })
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}
