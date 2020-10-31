//
//  ScanNFCViewController.swift
//  FreeOTP
//
//  Created by Danko Miocevic on 2020-10-03.
//  Copyright © 2020 Fedora Project. All rights reserved.
//

import UIKit
import CoreNFC

class ScanNFCViewController: UIViewController, NFCNDEFReaderSessionDelegate {
    var session: NFCNDEFReaderSession?
    var urlc = URLComponents()
    var URI = URIParameters()
    var icon = TokenIcon()
  
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func beginScanning(_ sender: Any) {
        guard NFCNDEFReaderSession.readingAvailable else {
          let alertController = UIAlertController(
            title: "Scanning Not Supported",
            message: "This device doesn't support tag scanning.",
            preferredStyle: .alert
          )
          alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
          self.present(alertController, animated: true, completion: nil)
          return
        }
        
        session?.invalidate()
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your iPhone near the tag to read the OTP configuration."
        session?.begin()
    }
  
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
      showError(error.localizedDescription)
    }
  
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
      for message in messages {
          for record in message.records {
              var obj = String(data: record.payload, encoding: .ascii)
              if obj != nil {
                if obj!.hasPrefix("\0") {
                  obj!.remove(at: obj!.startIndex)
                }
                if let urlc = URLComponents(string: obj!) {
                    if URI.validateURI(uri: urlc) {
                        self.urlc = urlc
                      
                        if !pushNextViewController(urlc) {
                            TokenStore().add(urlc)
                            switch UIDevice.current.userInterfaceIdiom {
                            case .pad:
                                dismiss(animated: true, completion: nil)
                                popoverPresentationController?.delegate?.popoverPresentationControllerDidDismissPopover?(popoverPresentationController!)
                            default:
                                navigationController?.popToRootViewController(animated: true)
                            }
                        }
                    } else {
                        showError("Invalid URI!")
                    }
                } else {
                    showError("Invalid URI!")
                }

                break
            }
          }
      }
    }
  
    fileprivate func showError(_ err: String) {
        let alertController = UIAlertController(
          title: "Scanning Error",
          message: err,
          preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        DispatchQueue.main.async {
          self.present(alertController, animated: true, completion: nil)
        }
    }
  
    // Due to conditional navigation logic, we manage the navigation stack ourselves to avoid
    // a storyboard with too many segues
    func pushNextViewController(_ urlc: URLComponents) -> Bool {
        var issuer = ""

        if let label = URI.getLabel(from: urlc) {
            issuer = label.issuer
        }

        if URI.accountUnset(urlc) {
          DispatchQueue.main.async {
            if let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "URILabelViewController") as? URILabelViewController {
              viewController.inputUrlc = urlc
              if let navigator = self.navigationController {
                  navigator.pushViewController(viewController, animated: true)
              }
            }
          }
        } else if URI.paramUnset(urlc, "image", "") &&
              icon.getFontAwesomeIcon(issuer: issuer) == nil && icon.issuerBrandMapping[issuer] == nil {
          DispatchQueue.main.async {
            if let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "URIMainIconViewController") as? URIMainIconViewController {
                  viewController.inputUrlc = urlc
              if let navigator = self.navigationController {
                  navigator.pushViewController(viewController, animated: true)
              }
            }
          }
        } else if URI.paramUnset(urlc, "lock", false) {
          DispatchQueue.main.async {
            if let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "URILockViewController") as? URILockViewController {
              viewController.inputUrlc = urlc
              if let navigator = self.navigationController {
                  navigator.pushViewController(viewController, animated: true)
              }
            }
          }
        } else {
          return false
        }

        return true
    }
}
