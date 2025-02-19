//
//  ScanPartHandling.swift
//  SampleApp-UIKit
//
//  Copyright © 2022 Jumio Corporation. All rights reserved.
//

import Jumio
import UIKit

protocol ScanPartHandlingDelegate: AnyObject {
    func scanPartShowLoadingView()
    func scanPartShowHelpView()
    func scanPartShowScanView()
    func scanPartShowImageTaken()
    func scanPartShowProcessing()
    func scanPartShowConfirmationView()
    func scanPartShowRejectView()
    func scanPartShowRetryView(with reason: Jumio.Retry.Reason)
    func scanPartDidFallback()
    func scanPartShowLegalHint(with message: String)
    func scanPartFinished()
}

class ScanPartHandling {
    typealias Delegate = ScanPartHandlingDelegate
    
    weak var delegate: Delegate?
    var hasFallback: Bool? { scanPart?.hasFallback }
    var scanMode: Jumio.Scan.Mode? { scanPart?.scanMode }
    
    fileprivate(set) var credentialPart: Jumio.Credential.Part?
    fileprivate var scanPart: Jumio.Scan.Part?
    
    func start(credentialPart: Jumio.Credential.Part, of credential: Jumio.Credential?) {
        self.credentialPart = credentialPart
        // to initialize a scan part, you will need the credential, a credential part and Jumio.Scan.Part.Delegate
        scanPart = credential?.initScanPart(credentialPart, scanPartDelegate: self)
        scanPart?.start()
    }
    
    func start(addon: Jumio.Scan.Part) {
        scanPart = addon
        scanPart?.start()
        
        if scanPart?.scanMode == .nfc {
            // For the addon nfc there is no scan step .scanView. Therefore, a view should be shown immediately.
            delegate?.scanPartShowHelpView()
        }
    }
    
    func fallback() {
        scanPart?.fallback()
    }
    
    func cancel() {
        scanPart?.cancel()
    }
    
    func attach(scanView: Jumio.Scan.View) {
        guard let scanPart = scanPart else { return }
        scanView.attach(scanPart: scanPart)
    }
    
    func attach(confirmationView: Jumio.Confirmation.View) {
        guard let scanPart = scanPart else { return }
        confirmationView.attach(scanPart: scanPart)
    }
    
    func attach(rejectView: Jumio.Reject.View) {
        guard let scanPart = scanPart else { return }
        rejectView.attach(scanPart: scanPart)
    }
    
    func retry(reason: Jumio.Retry.Reason) {
        scanPart?.retry(reason: reason)
    }
    
    func helpView() -> UIView? {
        // This returns a help view for the current scan part. This is available for NFC and iProov.
        return scanPart?.getHelpAnimation()
    }
    
    func clean() {
        scanPart = nil
        credentialPart = nil
    }
}

// MARK: - Jumio.Scan.Part.Delegate
extension ScanPartHandling: Jumio.Scan.Part.Delegate {
    func jumio(scanPart: Jumio.Scan.Part, step: Jumio.Scan.Step, data: Any?) {
        switch step {
        // Prepare: every time we are doing something asynchronously which might need longer time (for example network calls)
        case .prepare:
            delegate?.scanPartShowLoadingView()
        // Started: a scanner is being started
        case .started:
            print("scan started")
        // ScanView: you will need to attach a Jumio.Scan.View to this Jumio.Scan.Part
        case .scanView:
            delegate?.scanPartShowScanView()
        // ImageTaken: an image has been taken / captured
        case .imageTaken:
            delegate?.scanPartShowImageTaken()
        // Processing: captured image is being processed (timeframe differs)
        case .processing:
            delegate?.scanPartShowProcessing()
        // ConfirmationView: you will need to attach a Jumio.Confirmation.View to this Jumio.Scan.Part
        case .confirmationView:
            delegate?.scanPartShowConfirmationView()
        // RejectView: you will need to attach a Jumio.Confirmation.View to this Jumio.Scan.Part
        case .rejectView:
            delegate?.scanPartShowRejectView()
            guard let reason = data as? Jumio.RejectReason else { return }
            print("reject reason", reason.rawValue)
        // Retry: something went wrong and needs to be retried. Jumio.Retry.Reason contains more information
        case .retry:
            guard let reason = data as? Jumio.Retry.Reason else { return }
            delegate?.scanPartShowRetryView(with: reason)
            print("retry reason", reason.code, reason.message)
        // CanFinish: Jumio.Scan.Part is finished and waits for .finish()
        case .canFinish:
            self.scanPart?.finish()
            delegate?.scanPartFinished()
        // AddonScanPart: Jumio.Scan.Part contains an additional Addon, which can be executed. Show necessary UI for this.
        case .addonScanPart:
            print("Addon is available")
        @unknown default:
            print("got unknown scan step", step)
        }
    }
    
    func jumio(scanPart: Jumio.Scan.Part, updates update: Jumio.Scan.Update, data: Any?) {
        switch update {
        // Fallback: is being called after Jumio.Scan.Part.fallback() has been executed
        case .fallback:
            delegate?.scanPartDidFallback()
        // LegalHint: legal hint should be shown to the user. data contains a String with a message, which can be shown to the user
        case .legalHint:
            guard let message = data as? String else { return }
            delegate?.scanPartShowLegalHint(with: message)
        // NFC Updates: You can show updates in the UI in the background, when NFC progresses
        case .nfcExtractionStarted, .nfcExtractionProgress, .nfcExtractionFinished:
            break
        @unknown default:
            print("got unknown scan update", update)
        }
    }
}
