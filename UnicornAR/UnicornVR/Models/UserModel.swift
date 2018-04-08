//
//  UserModel.swift
//  UnicornVR
//
//  Created by Yveslym on 4/6/18.
//  Copyright © 2018 UnicornVR. All rights reserved.
//

import Foundation
import CoreLocation

struct User: Codable{
    //var firstName: String
    //var lastName: String
    var email: String
    //var userName: String
    var longitude: Double
    var latitude: Double
    var heading: Double
    //var location: Location
}

struct Location: Codable{
    var longitude: Double
    var latitude: Double
    var heading: Double
    
    init(longitude: Double, latitude: Double, heading: Double = 0.0){
        self.longitude = longitude
        self.latitude = latitude
        self.heading = heading
        
    }
}


