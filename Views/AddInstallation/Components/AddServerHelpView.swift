//
//  AddServerHelpView.swift
//  ScrutinyMonitor
//
//  Created by Christopher Webb on 2026-05-27.
//

import SwiftUI
public struct AddServerHelpView: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Server Details")
                .font(.headline)

            HelpRow(
                title: "Name",
                text: "Any label that helps you recognize the NAS, such as Basement NAS or DS923+."
            )

            HelpRow(
                title: "URL",
                text: "Use the Scrutiny web address you open in a browser, for example http://nas.local:8080 or a reverse-proxy path like https://home.example.com/scrutiny."
            )

            HelpRow(
                title: "API token",
                text: "Stock Scrutiny installs usually do not need one. Only enter a token if your reverse proxy or authentication layer requires requests to send one."
            )
        }
        .padding(18)
        .frame(width: 360)
    }
}

