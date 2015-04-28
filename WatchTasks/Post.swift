//
//  Post.swift
//  Jahia Watcher
//
//  Created by Serge Huber on 24.04.15.
//  Copyright (c) 2015 Jahia Solutions. All rights reserved.
//

import Foundation

class Post {
    
    let jahiaServerServices : JahiaServerServices = JahiaServerServices.sharedInstance
    
    var identifier : String?
    var title : String?
    var author : String?
    var date : NSDate?
    var spam : Bool?
    var content : String?
    
    init(fromNSDictionary : NSDictionary) {
        identifier = fromNSDictionary["id"] as? String
        let postProperties : NSDictionary = fromNSDictionary["properties"] as! NSDictionary
        let titleProperty : NSDictionary = postProperties["jcr__title"] as! NSDictionary
        title = titleProperty["value"] as? String
        let contentProperty : NSDictionary? = postProperties["content"] as? NSDictionary
        let createdProperty  : NSDictionary? = postProperties["jcr__created"] as? NSDictionary
        let createdByProperty  : NSDictionary? = postProperties["jcr__createdBy"] as? NSDictionary
        if (contentProperty != nil) {
            var postContent : String = contentProperty!["value"] as! String
            content = jahiaServerServices.stripHTML(postContent)
        }
        if (createdProperty != nil) {
            let createdValue : NSNumber = createdProperty!["value"] as! NSNumber
            let postDateTimeInterval = NSTimeInterval(createdValue.longValue / 1000)
            date = NSDate(timeIntervalSince1970: postDateTimeInterval)
        }
        if (createdByProperty != nil) {
            author = createdByProperty!["value"] as? String
        }
        
    }
}