//
//  ARViewController.swift
//  UnicornVR
//
//  Created by Yveslym on 4/6/18.
//  Copyright © 2018 UnicornVR. All rights reserved.
//

import UIKit
import PusherSwift
import SceneKit
import CoreLocation
import ARKit
import Alamofire

class ARViewController: UIViewController {

    // - MARK: IBOUTLETS
     @IBOutlet var sceneView: ARSCNView!
    
    // - MARK: PROPERTIES
    
    var currentUser : User!
    let locationManager = CLLocationManager()
    var userLocation = CLLocation()
    var heading : Double! = 0.0
    var countLocation : Int = 0
    var users: [User] = []
    /// the distance between the prime user, and other users
    var distance : Float! = 0.0
    
    /// variable to store the root node of the Avatar model and the name of this node
     var modelNode:SCNNode!
    let rootNodeName = "ship"
    
    /// variable to store the first transformation of the node
    ///  to calculate the orientation (rotation) of the model in the best possible way
    var originalTransform:SCNMatrix4!
    
    /// store the Pusher object and channel to receive the updates
   
    
    
    lazy var options = PusherClientOptions(
        authMethod: AuthMethod.authRequestBuilder(authRequestBuilder: AuthRequestBuilder()),
        host: .cluster("us2")
    )
    
   
    
    var pusher : Pusher!
    
    var channel: PusherChannel!
    
    
    // - MARK: IBACTIONS
    
    
    // - MARK: VIEW CONTROLLER LYFE CYCLE
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pusher = Pusher(
            key: "74a8e978df474da72470",
            options: options
            
        )
        
        pusher.connection.delegate = self
        
       // self.connectToPusher()
       locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
    
        // Run the view's session
        sceneView.session.run(configuration)
    }

    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        super.viewWillDisappear(animated)
        
       
        sceneView.session.pause()
    }
   
}


// - MARK: CORE LOCATION LIFE CYCLE

extension ARViewController: CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Implementing this method is required
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
       // var userLocation:CLLocation = locations[0] as CLLocation
        
        // Call stopUpdatingLocation() to stop listening for location updates,
        // other wise this function will be called every time when user location changes.
//        print(countLocation)
//        if countLocation == 3{
//            countLocation = 0
//            self.userLocation = locations.last!
//             self.sendLocation(userlocation: userLocation)
//            return
//        }
//        countLocation += 1
//
        if let location = locations.last {
            self.userLocation = location

            var locations : [Location] = []
            
            let location1 = Location(longitude: -122.3917600, latitude: 37.7897400)
            // let location2 = Location(longitude: -122.40744014295, latitude:  37.7775022527561)
            
            locations.append(location1)
            // locations.append(location2)
            locations.forEach{
                self.updateLocation($0.latitude, $0.longitude)
            }
            
           // self.connectToPusher()
        }
//        print("user latitude = \(userLocation.coordinate.latitude)")
//        print("user longitude = \(userLocation.coordinate.longitude)")
    }
    
}

// - MARK: ARKIT LIFE CYCLE

extension ARViewController: ARSCNViewDelegate{
    
    /// In updateLocation, create a CLLocation object to calculate the distance between
    /// the user and the driver. the distance is calculated in meters
    func updateLocation(_ latitude : Double, _ longitude : Double) {
       print("updating location...")
        let location = CLLocation(latitude: latitude, longitude: longitude)
        self.distance = Float(location.distance(from: self.userLocation))
        
        // If this is the first update received, self.modelNode will be nil, so we have to instantiate the model.
        // Next, we need to move the pivot of the model to its center in the y-axis, so it can be rotated without
        // changing its position
        // Save the model’s transform to calculate future rotations, position it, and add it to the scene
        if self.modelNode == nil {
            
             print("create scene...")
            // Create a new scene
            let modelScene = SCNScene(named: "art.scnassets/ship.scn")!
            self.modelNode = modelScene.rootNode.childNode(withName: rootNodeName, recursively: true)!
            
            // Move model's pivot to its center in the Y axis
            let (minBox, maxBox) = self.modelNode.boundingBox
            self.modelNode.pivot = SCNMatrix4MakeTranslation(0, (maxBox.y - minBox.y)/2, 0)
            
            // Save original transform to calculate future rotations
            self.originalTransform = self.modelNode.transform
            
            // Position the model in the correct place
            positionModel(location)
            
            // Add the model to the scene
            sceneView.scene.rootNode.addChildNode(self.modelNode)
            
            // Create name label
           // let nameLabel = "yveslym"
            let image = UIImage(named:"yves")
          //nameLabel = //users.first?.userName
            
            let myimage = makeBillboardNode(image!)
             //Position it on top of the car
            myimage.position = SCNVector3Make(0, 1, 0)
             //Add it as a child of the car model
            self.modelNode.addChildNode(myimage)
        }
            // Now, if this is not the first update, you just need to position
            // the model, animating the movement so it looks nice:
        else {
            // Begin animation
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.0
            
            // Position the model in the correct place
            positionModel(location)
            
            // End animation
            SCNTransaction.commit()
        }
    }
    
    /// To position the model, we just need to rotate first, then translate it to the correct position and scale it
    func positionModel(_ location: CLLocation) {
        // Rotate node
        self.modelNode.transform = rotateNode(Float(-1 * (self.heading - 180).toRadians()), self.originalTransform)
        
        // Translate node
        self.modelNode.position = translateNode(location)
        
        // Scale node
        self.modelNode.scale = scaleNode(location)
    }
    
    /// rotation in the y-axis is counterclockwise (and handled in radians),
    /// so we need to subtract 180º and make the angle negative. This is the definition of
    /// the method rotateNode
    func rotateNode(_ angleInRadians: Float, _ transform: SCNMatrix4) -> SCNMatrix4 {
        let rotation = SCNMatrix4MakeRotation(angleInRadians, 0, 1, 0)
        return SCNMatrix4Mult(transform, rotation)
    }
    
    /// function to scale the node in proportion to the distance. They are inversely proportional
    /// the greater the distance, the less the scale. I just divide 1000 by the distance and don’t
    /// allow the value to be less than 1.5 or great than 3
    func scaleNode (_ location: CLLocation) -> SCNVector3 {
        let scale = min( max( Float(100/distance), 1.5 ), 3 )
        return SCNVector3(x: scale, y: scale, z: scale)
    }
    
    /// function to translate the node, you have to calculate the transformation matrix
    /// and get the position values from that matrix (from its fourth column, referenced by a zero-based index):
    func translateNode (_ location: CLLocation) -> SCNVector3 {
        let locationTransform = transformMatrix(matrix_identity_float4x4, userLocation, location)
        return positionFromTransform(locationTransform)
    }
    
    func positionFromTransform(_ transform: simd_float4x4) -> SCNVector3 {
        return SCNVector3Make(
            transform.columns.3.x, transform.columns.3.y, transform.columns.3.z
        )
    }
    
    func makeBillboardNode(_ image: UIImage) -> SCNNode {
        let plane = SCNPlane(width: 1, height: 1)
        plane.firstMaterial!.diffuse.contents = image
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        return node
    }
    
    /*
     To calculate the transformation matrix:
     
     We use an identity matrix (we don’t have to use the matrix of the camera or something like that, the position and orientation of the other users are independent of current user position and orientation.
     We have to calculate the bearing using the formula
     
     atan2 (
     
     x = sin(long2 - long1) * cos(long2),
     
     y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(long2 - long1)
     
     )
     Using an identity matrix, get a rotation matrix in the y-axis using that bearing.
     The distance is given by the z-axis, so create a four element vector with the distance
     in the z position to get a translation matrix.
     Multiply both matrices (the order is important) to combine them.
     Get the final transformation by multiplying the result of the previous step with the matrix passed as an argument.
     */
    func transformMatrix(_ matrix: simd_float4x4, _ originLocation: CLLocation, _ otherUserLocation: CLLocation) -> simd_float4x4 {
        let bearing = bearingBetweenLocations(userLocation, otherUserLocation)
        let rotationMatrix = rotateAroundY(matrix_identity_float4x4, Float(bearing))
        
        let position = vector_float4(0.0, 0.0, Float(-bearing), 0.0)
        let translationMatrix = getTranslationMatrix(matrix_identity_float4x4, position)
        
        let transformMatrix = simd_mul(rotationMatrix, translationMatrix)
        
        return simd_mul(matrix, transformMatrix)
    }
    
    func getTranslationMatrix(_ matrix: simd_float4x4, _ translation : vector_float4) -> simd_float4x4 {
        var matrix = matrix
        matrix.columns.3 = translation
        return matrix
    }
    
    func rotateAroundY(_ matrix: simd_float4x4, _ degrees: Float) -> simd_float4x4 {
        var matrix = matrix
        
        matrix.columns.0.x = cos(degrees)
        matrix.columns.0.z = -sin(degrees)
        
        matrix.columns.2.x = sin(degrees)
        matrix.columns.2.z = cos(degrees)
        return matrix.inverse
    }
    /// function that return the distace between 2 location
    func bearingBetweenLocations(_ originLocation: CLLocation, _ otherUserLocation: CLLocation) -> Double {
        let lat1 = originLocation.coordinate.latitude.toRadians()
        let lon1 = originLocation.coordinate.longitude.toRadians()
        
        let lat2 = otherUserLocation.coordinate.latitude.toRadians()
        let lon2 = otherUserLocation.coordinate.longitude.toRadians()
        
        let longitudeDiff = lon2 - lon1
        
        let y = sin(longitudeDiff) * cos(lat2);
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(longitudeDiff);
        
        return atan2(y, x)
    }
}

// - MARK: PUSHER LIFE CYCLE
extension ARViewController: PusherDelegate{
    
     /// In the method connectToPusher we subscribe to private-channel and, when a client-new-location event is received,
     /// extract the driver’s latitude, longitude, and heading and update the status and location of the 3D model
    /// with the method updateLocation
    func connectToPusher() {
        // subscribe to channel and bind to event
        let channel = pusher.subscribe("private-channel")

        let _ = channel.bind(eventName: "client-new-location", callback: { (data: Any?) -> Void in
            if let data = data as? Data {
                
                let users = try! JSONDecoder().decode([User].self, from: data)
                  self.users = users
                self.users.forEach{
                    self.heading = $0.heading
                self.updateLocation(($0.latitude), ($0.longitude))
            }
            }
        })
        pusher.connect()
    }
    
    func sendLocation(userlocation: CLLocation){
        let headers = [
            "x-User-Email":"yves@mail.com",
            "x-User-Token":"VZTWj_Lmqq9TGevp266",
            ]
        //let channel = pusher.subscribe("private-channel")
        let baseUrl = "http://0.0.0.0:3000/v1/sessions"
        let body: [String: Double] = ["longitude": userlocation.coordinate.longitude,
                                      "latitude":userlocation.coordinate.latitude,
                                      "heading": heading]
   let bodydata = try! JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        
        var request = URLRequest(url: URL(string: baseUrl)!)
            request.httpBody = bodydata
        request.allHTTPHeaderFields = headers
        request.httpMethod = "PATCH"
        let session = URLSession.shared
        
        let task = session.dataTask(with: request) { (data, resp, error) in
           // print(String(data:data!, encoding: .utf8) ?? "error my occure")
            print("here")
        }
        task.resume()
    }
    
    
}

class AuthRequestBuilder: AuthRequestBuilderProtocol {
    func requestFor(socketID: String, channelName: String) -> URLRequest? {
        
        let headers = [
            "x-User-Email":"yves@mail.com",
            "x-User-Token":"VZTWj_Lmqq9TGevp266",
            ]
        
        let baseUrl = URL(string:"http://0.0.0.0:3000/v1/sessions")
        var request = URLRequest(url: baseUrl!)
        request.httpMethod = "GET"
       
        request.allHTTPHeaderFields = headers
        return request
    }
}












