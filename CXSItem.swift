//
//  CXSItem.swift
//  Jahia Watcher
//
//  Created by Serge Huber on 09.10.15.
//  Copyright © 2015 Jahia Solutions. All rights reserved.
//

import Foundation

class CXSItem {
    var itemType : String = "undefined"
    var itemId : String?
    var properties : [String:AnyObject]?
    
    init(itemType : String, itemId : String) {
        self.itemType = itemType
        self.itemId = itemId
    }
    
    init(_ dictionary : [String:AnyObject]) {
        itemType = dictionary["itemType"] as! String
        itemId = dictionary["itemId"] as? String
        properties = dictionary["properties"] as? [String:AnyObject]
    }
    
    func toDictionary() -> [String:AnyObject] {
        var dictionary = [String:AnyObject]()
        dictionary["itemType"] = itemType
        if let _ = itemId {
            dictionary["itemId"] = itemId!
        }
        if let _ = properties {
            dictionary["properties"] = properties!
        }
        return dictionary
    }
    
}