//
//  FireStoreManager.swift
//  Geofence
//
//  Created by I MADE DWI MAHARDIKA on 22/05/23.
//

import Foundation
import Firebase
import FirebaseFirestore
import CoreData

class FirestoreManager {
    static let shared = FirestoreManager()

    private let firestore: Firestore
    private let coreDataManager: CoreDataManager

    private init() {
        firestore = Firestore.firestore()
        coreDataManager = CoreDataManager.shared
    }

    func fetchGeofences(completion: @escaping ([Geofence]?, Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(nil, nil)
            return
        }

        let geofencesCollection = firestore.collection("geofences")
        let query = geofencesCollection.whereField("userId", isEqualTo: userId)

        query.getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let documents = snapshot?.documents else {
                completion(nil, nil)
                return
            }

            var geofences: [Geofence] = []

            for document in documents {
                if let geofence = self.parseGeofence(from: document) {
                    geofences.append(geofence)
                }
            }

            completion(geofences, nil)
        }
    }

    private func parseGeofence(from document: QueryDocumentSnapshot) -> Geofence? {
        guard
            let userId = document.data()["userId"] as? String,
            let latitude = document.data()["latitude"] as? Double,
            let longitude = document.data()["longitude"] as? Double,
            let radius = document.data()["radius"] as? Double
        else {
            return nil
        }

        let context = coreDataManager.context
        let geofence = Geofence(context: context)
        geofence.userId = userId
        geofence.latitude = latitude
        geofence.longitude = longitude
        geofence.radius = radius

        return geofence
    }
}
