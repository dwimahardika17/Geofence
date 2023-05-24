//
//  ContentView.swift
//  Geofence
//
//  Created by I MADE DWI MAHARDIKA on 21/05/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authModel: AuthViewModel
    var body: some View {
        VStack {
            Group {
            if authModel.user != nil {
            MainView()
            } else {
            SignUpView()
            }
            }.onAppear {
            authModel.listenToAuthState()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
