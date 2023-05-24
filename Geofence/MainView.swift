//
//  MainView.swift
//  Geofence
//
//  Created by I MADE DWI MAHARDIKA on 22/05/23.
//

import SwiftUI
import MapKit
import CoreLocation
import Firebase
import CoreData
import UserNotifications

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate  {
    private let locationManager = CLLocationManager()
    @Published var region = MKCoordinateRegion()
    private var firestore: Firestore!
    private var timer: Timer?
//    private var context: NSManagedObjectContext
    private var coreDataManager: CoreDataManager
    @Published var annotations = [MKPointAnnotation]()
    override init() {
        coreDataManager = CoreDataManager.shared
        super.init()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        let settings = FirestoreSettings()
        Firestore.firestore().settings = settings
        firestore = Firestore.firestore()
        
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.saveUserLocation()
            self?.retrieveGeofenceData()
        }
        
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let userLocation = locations.last {
            region = MKCoordinateRegion(center: userLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
            locationManager.stopUpdatingLocation()
            
            saveUserLocation()
        }
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
            if region is CLCircularRegion {
                print("Entered geofence: \(region.identifier)")
//                showNotification(title: "Geofence Alert", body: "You are inside the geofence.")
                // Perform actions when entering a geofence
                sendNotification(withTitle: "geofence", andBody: "123")
            }
        }
        
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
            if region is CLCircularRegion {
                print("Exited geofence: \(region.identifier)")
//                showNotification(title: "Geofence Alert", body: "You have exited the geofence.")
                // Perform actions when exiting a geofence
                sendNotification(withTitle: "out", andBody: "321")
            }
    }
    
    func sendNotification(withTitle title: String, andBody body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: "geofence", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
//    func showNotification(title: String, body: String) {
//            let content = UNMutableNotificationContent()
//            content.title = title
//            content.body = body
//            content.sound = UNNotificationSound.default
//
//            let request = UNNotificationRequest(identifier: "geofence", content: content, trigger: nil)
//
//            UNUserNotificationCenter.current().add(request) { error in
//                if let error = error {
//                    print("Error showing notification: \(error.localizedDescription)")
//                }
//            }
//        print("masuk")
//        }
    
    func saveUserLocation() {
        guard let userLocation = locationManager.location,
              let userId = Auth.auth().currentUser?.uid else {
            return // User ID or location is not available
        }
        
        let locationData: [String: Any] = [
            "latitude": userLocation.coordinate.latitude,
            "longitude": userLocation.coordinate.longitude,
            "timestamp": Timestamp(date: Date())
        ]
        
        let userLocationsCollection = firestore.collection("userLocation")
        let query = userLocationsCollection.whereField("userId", isEqualTo: userId)
        
        query.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error querying user locations: \(error)")
                return
            }
            
            if let snapshot = snapshot {
                if snapshot.isEmpty {
                    // No existing document for the user, create a new one
                    userLocationsCollection.addDocument(data: locationData) { error in
                        if let error = error {
                            print("Error saving user location: \(error)")
                        } else {
                            print("User location saved successfully")
                        }
                    }
                } else {
                    // Existing document found, update it
                    let document = snapshot.documents[0]
                    document.reference.updateData(locationData) { error in
                        if let error = error {
                            print("Error updating user location: \(error)")
                        } else {
                            print("User location updated successfully")
                        }
                    }
                }
            }
        }
    }
    
    
    func startGeofencing() {
        if let userLocation = locationManager.location {
            let geofenceRegion = CLCircularRegion(center: userLocation.coordinate, radius: 50, identifier: "Geofence")
            geofenceRegion.notifyOnEntry = true
            geofenceRegion.notifyOnExit = true
            locationManager.startMonitoring(for: geofenceRegion)
            
            // Save geofence data to Firebase Firestore
            let userId = Auth.auth().currentUser?.uid// Get the user's ID from the user session
            let geofenceData: [String: Any] = [
                "userId": userId,
                "latitude": userLocation.coordinate.latitude,
                "longitude": userLocation.coordinate.longitude,
                "radius": 50
            ]
            print(userLocation.coordinate.latitude)
            print(userLocation.coordinate.longitude)
            firestore.collection("geofences").addDocument(data: geofenceData) { error in
                if let error = error {
                    print("Error saving geofence data: \(error)")
                } else {
                    print("Geofence data saved successfully")
                }
            }
        }
    }
    
    func retrieveGeofenceData() {
        firestore.collection("geofences").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error retrieving geofence data: \(error)")
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            for document in snapshot.documents {
                let data = document.data()
                
                // Extract relevant data from the Firestore document
                guard let userId = data["userId"] as? String,
                      let latitude = data["latitude"] as? Double,
                      let longitude = data["longitude"] as? Double,
                      let radius = data["radius"] as? Double else {
                    continue
                }
                
                // Check if an existing object with the same userId already exists in Core Data
                let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                
                do {
                    let existingGeofences = try coreDataManager.context.fetch(fetchRequest)
                    
                    if let existingGeofence = existingGeofences.first {
                        // Update the existing object instead of creating a new one
                        existingGeofence.latitude = latitude
                        existingGeofence.longitude = longitude
                        existingGeofence.radius = radius
                    } else {
                        // Create a new Core Data object
                        let newGeofence = Geofence(context: coreDataManager.context)
                        newGeofence.userId = userId
                        newGeofence.latitude = latitude
                        newGeofence.longitude = longitude
                        newGeofence.radius = radius
                    }
                    
                    // Save the Core Data context
                    try coreDataManager.context.save()
                    print("Geofence data saved successfully")
                } catch {
                    print("Error saving Core Data context: \(error)")
                }
            }
        }
    }

    func fetchData() {
        let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
        var userGeofences = [Geofence]()

        do {
            let geofences = try coreDataManager.context.fetch(fetchRequest)
            userGeofences = geofences

            var fetchedAnnotations = [MKPointAnnotation]() // Temporary array to store fetched annotations

            for geofence in userGeofences {
                let lat: CLLocationDegrees = geofence.latitude
                let long: CLLocationDegrees = geofence.longitude
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)

                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = geofence.userId

                fetchedAnnotations.append(annotation)

                let region = CLCircularRegion(center: coordinate, radius: geofence.radius, identifier: geofence.userId!)
                region.notifyOnEntry = true
                region.notifyOnExit = true
                locationManager.startMonitoring(for: region)
                print(geofence.latitude)
                print(geofence.longitude)
            }

            annotations = fetchedAnnotations // Update the published property

            print("Successfully fetched geofences")
        } catch {
            print("Failed to fetch geofences: \(error)")
        }
    }

    func deleteData() {
            let fetchRequest: NSFetchRequest<Geofence> = Geofence.fetchRequest()
            
            do {
                let geofences = try coreDataManager.context.fetch(fetchRequest)
                
                for geofence in geofences {
                    coreDataManager.context.delete(geofence)
                }
                
                try coreDataManager.context.save()
                print("Geofences deleted successfully")
            } catch {
                print("Failed to delete geofences: \(error)")
            }
        }
    
}



struct AnnotationItem: Identifiable {
    let id = UUID()
    let annotation: MKPointAnnotation
}

struct MainView: View {
    @EnvironmentObject private var authModel: AuthViewModel
    @StateObject private var locationManager = LocationManager()
    @State private var annotationItems = [AnnotationItem]()

    var body: some View {
        VStack {
            Text("\(authModel.user?.email ?? "")")
                        Button(action: {
                            locationManager.startGeofencing()
                        }) {
                            Text("Start Geofencing")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
            Button(action: {
                locationManager.fetchData()
//                locationManager.showNotification(title: "Geofence Alert", body: "You have exited the geofence.")
//                locationManager.sendNotification(withTitle: "geofence", andBody: "aaaaa")
            }) {
                Text("Fetch")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            Map(coordinateRegion: $locationManager.region,
                interactionModes: .all,
                showsUserLocation: true,
                annotationItems: annotationItems) { item in
                    MapAnnotation(coordinate: item.annotation.coordinate) {
                        Text(item.annotation.title ?? "")
                    }
                }
                .edgesIgnoringSafeArea(.all)
        }.toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) { Button(
                action: { authModel.signOut()
                }, label: {
                    Text("Sign Out") .bold()
                })
            }
        }
        .onAppear(perform: locationManager.retrieveGeofenceData)
        .onReceive(locationManager.objectWillChange, perform: { _ in
            // Update the annotationItems when the location manager's objectWillChange publisher emits a value
            annotationItems = locationManager.annotations.map { AnnotationItem(annotation: $0) }
        })
    }
}


struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
