//
//  AppError.swift
//  RentalApp (Purrperty)
//
//  Core — Unified error type. Services throw these; ViewModels map
//  them to user-facing copy. Never surface a raw system error in UI.
//

import Foundation

enum AppError: LocalizedError, Equatable {
    case network
    case unauthorized
    case invalidCredentials
    case validation(String)
    case notFound(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .network:
            "We couldn't reach the network. Check your connection and try again."
        case .unauthorized:
            "Your session expired. Please sign in again."
        case .invalidCredentials:
            "That email and password combination didn't match."
        case .validation(let message):
            message
        case .notFound(let subject):
            "\(subject) couldn't be found."
        case .unknown:
            "Something went wrong. Please try again."
        }
    }
}
