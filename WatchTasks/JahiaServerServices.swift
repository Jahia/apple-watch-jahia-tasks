//
//  JahiaServerServices.swift
//  Jahia Watcher
//
//  Created by Serge Huber on 08.04.15.
//  Copyright (c) 2015 Jahia Solutions. All rights reserved.
//

import Foundation

class JahiaServerServices {

    let jahiaWatcherSettings : JahiaWatcherSettings = JahiaWatcherSettings.sharedInstance
    var servicesAvailable : Bool = false
    var loggedIn : Bool = false
    var attemptedLogin : Bool = false
    static var messageDelegate : MessageDelegate?
    
    class var sharedInstance: JahiaServerServices {
        struct Static {
            static let instance: JahiaServerServices = JahiaServerServices()
        }
        return Static.instance
    }
    
    class func mprintln(message : String) {
        messageDelegate?.displayMessage(message)
    }
    
    class func hideMessages() {
        messageDelegate?.hideAllMessages()
    }
    
    func mprintln(message : String) {
        JahiaServerServices.mprintln(message)
    }
    
    func hideMessages() {
        JahiaServerServices.hideMessages()
    }
    
    func getUserName() -> String {
        return jahiaWatcherSettings.jahiaUserName
    }
    
    func writeDataToFile(filePath : String, data : NSData) -> Bool {
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true) as! [String]
        let documentDirectory = paths[0]
        let fullFilePath = documentDirectory.stringByAppendingPathComponent(filePath)
        data.writeToFile(fullFilePath, atomically: true)
        return true
    }
    
    func readDataFromFile(filePath : String) -> NSData? {
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true) as! [String]
        let documentDirectory = paths[0]
        let fullFilePath = documentDirectory.stringByAppendingPathComponent(filePath)
        let data = NSData(contentsOfFile: fullFilePath)
        return data
    }
    
    func readJSONFromFile(filePath : String) -> AnyObject? {
        let data = readDataFromFile(filePath)
        if let dataVal = data {
            var error : NSError?
            var jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(dataVal, options: NSJSONReadingOptions.MutableContainers, error: &error) as! NSDictionary
            return jsonResult
        }
        return nil
    }
    
    func httpGet(url : String, fileName : String) -> NSData? {
        let getURL : NSURL = NSURL(string: url)!
        
        let request = NSMutableURLRequest(URL: getURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error retrieving post actions!")
                writeDataToFile(fileName, data: dataVal!)
                return dataVal
            } else {
                dataVal = readDataFromFile(fileName)
                return dataVal
            }
        } else {
            mprintln("Couldn't retrieve post actions")
            dataVal = readDataFromFile(fileName)
            return dataVal
        }
    }
    
    func httpPost(url : String, body : String, fileName : String) -> NSData? {
        let postURL : NSURL = NSURL(string: url)!
        let request = NSMutableURLRequest(URL: postURL)
        let postData = NSMutableData()
        postData.appendData(body.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
        
        request.HTTPMethod = "POST"
        request.setValue(NSString(format: "%lu", postData.length) as String, forHTTPHeaderField: "Content-Length")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = postData
        request.timeoutInterval = 4
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode == 200) {
                mprintln("Post successful.")
                writeDataToFile(fileName, data: dataVal!)
                return dataVal
            } else {
                mprintln("Error during post!")
                dataVal = readDataFromFile(fileName)
                return dataVal
            }
        } else {
            mprintln("Post failed")
            dataVal = readDataFromFile(fileName)
            return dataVal
        }
    }
    
    func login() -> Bool {
        
        var result : Bool = false
        mprintln("Logging into Jahia...")
        
        let jahiaLoginURL : NSURL = NSURL(string: jahiaWatcherSettings.loginUrl())!
        let request = NSMutableURLRequest(URL: jahiaLoginURL)
        let requestString : String = "doLogin=true&restMode=true&username=\(jahiaWatcherSettings.jahiaUserName)&password=\(jahiaWatcherSettings.jahiaPassword)&redirectActive=false";
        let postData = NSMutableData()
        postData.appendData(requestString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
        
        request.HTTPMethod = "POST"
        request.setValue(NSString(format: "%lu", postData.length) as String, forHTTPHeaderField: "Content-Length")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = postData
        request.timeoutInterval = 4
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode == 200) {
                mprintln("Login successful.")
                servicesAvailable = true
                loggedIn = true
                let userPath = getUserPath()
                if let realUserPath = userPath {
                    jahiaWatcherSettings.jahiaUserPath = realUserPath
                }
                result = true
            } else {
                mprintln("Error during login!")
            }
        } else {
            mprintln("Login failed")
            loggedIn = false
        }
        hideMessages()
        return result
    }
    
    func areServicesAvailable() -> Bool {
        if (!loggedIn && !attemptedLogin) {
            attemptedLogin = true
            login()
        }
        if (!servicesAvailable) {
            mprintln("Services not available")
            return false
        }
        return true;
    }
    
    func registerDeviceToken(deviceToken : String) {
        if (!areServicesAvailable()) {
            return
        }
        mprintln("Registering device token...")
        let escapedDeviceToken : String = deviceToken.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
        
        let jahiaRegisterDeviceTokenURL : NSURL = NSURL(string: jahiaWatcherSettings.registerDeviceTokenUrl() + "?deviceToken=\(escapedDeviceToken)")!
        
        let request = NSMutableURLRequest(URL: jahiaRegisterDeviceTokenURL)
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 4
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error registering device token for current user ?")
            } else {
            }
        } else {
            mprintln("Device registration failed")
        }
        hideMessages()
    }

    func blockUser(userName : String) {
        if (!areServicesAvailable()) {
            return
        }
        mprintln("Blocking user...")
        
        let jahiaBlockUserURL : NSURL = NSURL(string: jahiaWatcherSettings.blockUserUrl() + "?userName=\(userName)")!
        
        let request = NSMutableURLRequest(URL: jahiaBlockUserURL)
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 4
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error blocking user \(userName)?")
            } else {
                mprintln("User \(userName) blocked successfully.")
            }
        } else {
            mprintln("Blocking of user \(userName) failed")
        }
        hideMessages()
    }

    func unblockUser(userName : String) {
        if (!areServicesAvailable()) {
            return
        }
        mprintln("Unblocking user...")
        
        let jahiaUnblockUserURL : NSURL = NSURL(string: jahiaWatcherSettings.unblockUserUrl() + "?userName=\(userName)")!
        
        let request = NSMutableURLRequest(URL: jahiaUnblockUserURL)
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 4
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error unblocking user \(userName)?")
            } else {
                mprintln("User \(userName) unblocked successfully.")
            }
        } else {
            mprintln("Unblocking of user \(userName) failed")
        }
        hideMessages()
    }
    
    func markAsSpam(nodeIdentifier : String) {
        if (!areServicesAvailable()) {
            return
        }
        mprintln("Marking post as spam")
        
        let jahiaMarkAsSpamURL : NSURL = NSURL(string: jahiaWatcherSettings.markAsSpamUrl() + "?nodeIdentifier=\(nodeIdentifier)")!
        
        let request = NSMutableURLRequest(URL: jahiaMarkAsSpamURL)
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 4
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error marking post as spam ?")
            } else {
                mprintln("Post marked as spam successfully.")
            }
        } else {
            mprintln("Marking post as spam failed")
        }
        hideMessages()
    }

    func unmarkAsSpam(nodeIdentifier : String) {
        if (!areServicesAvailable()) {
            return
        }
        mprintln("Unmarking post as spam")
        
        let jahiaUnmarkAsSpamURL : NSURL = NSURL(string: jahiaWatcherSettings.unmarkAsSpamUrl() + "?nodeIdentifier=\(nodeIdentifier)")!
        
        let request = NSMutableURLRequest(URL: jahiaUnmarkAsSpamURL)
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 4
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error unmarking post as spam ?")
            } else {
                mprintln("Post unmarked as spam successfully.")
            }
        } else {
            mprintln("Unmarking post as spam failed")
        }
        hideMessages()
    }
    
    func deleteNode(nodeIdentifier : String, workspace : String) {
        if (!areServicesAvailable()) {
            return
        }
        mprintln("Deleting node \(nodeIdentifier)")
        
        let jahiaDeleteNodeURL : NSURL = NSURL(string: jahiaWatcherSettings.jcrApiUrl() + "/\(workspace)/en/nodes/\(nodeIdentifier)")!
        
        let request = NSMutableURLRequest(URL: jahiaDeleteNodeURL)
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 4
        request.HTTPMethod = "DELETE"
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 204) {
                mprintln("Error deleting node \(nodeIdentifier) statusCode=\(httpResponse.statusCode)")
            } else {
                mprintln("Node \(nodeIdentifier) deleted successfully.")
            }
        } else {
            mprintln("Deleting node \(nodeIdentifier) failed.")
        }
        hideMessages()
    }
    
    func getPostActions(post : Post) -> Post {
        if (!areServicesAvailable()) {
            return post
        }
        mprintln("Retrieving post actions...")
        
        let jahiaPostActionsURL : NSURL = NSURL(string: jahiaWatcherSettings.postActionsUrl(post.path!))!
        
        let request = NSMutableURLRequest(URL: jahiaPostActionsURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error retrieving post actions!")
            } else {
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                var jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(dataVal!, options: NSJSONReadingOptions.MutableContainers, error: &error) as! NSDictionary
                
                if let viewUrl = jsonResult["view-url"] as? String {
                    post.viewUrl = viewUrl
                }
                if let possibleActions = jsonResult["possibleActions"] as? [NSDictionary] {
                    var actions = [PostAction]()
                    for possibleAction in possibleActions {
                        let postAction = PostAction()
                        postAction.displayName = possibleAction["displayName"] as? String
                        postAction.name = possibleAction["name"] as? String
                        actions.append(postAction)
                    }
                    post.actions = actions
                } else {
                    post.actions = nil
                }
            }
        } else {
            mprintln("Couldn't retrieve post actions")
        }
        
        hideMessages()
        return post
    }
    
    
    func getUserPath() -> String? {
        if (!areServicesAvailable()) {
            return ""
        }
        mprintln("Retrieving current user path...")
        let jahiaUserPathURL : NSURL = NSURL(string: jahiaWatcherSettings.userPathUrl())!
        
        let request = NSMutableURLRequest(URL: jahiaUserPathURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)!
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error retrieving current user path")
            } else {
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                hideMessages()
                return JahiaServerServices.condenseWhitespace(datastring! as String)
            }
        } else {
            mprintln("Coudln't retrieve current user path")
        }
        hideMessages()
        return nil;
    }
    
    func getWorkflowTasks() -> [Task] {
        var taskArray = [Task]()
        if (!areServicesAvailable()) {
            return taskArray
        }

        mprintln("Retrieving workflow tasks...")
        
        let jahiaWorkflowTasksURL : NSURL = NSURL(string: jahiaWatcherSettings.jcrApiUrl() + "/default/en/paths\(jahiaWatcherSettings.jahiaUserPath)/workflowTasks?includeFullChildren&resolveReferences")!
        
        let request = NSMutableURLRequest(URL: jahiaWorkflowTasksURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var openTaskCount = 0;
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error retrieving workflow tasks, probably none were ever created ?")
            } else {
                writeDataToFile("workflow-tasks.json", data: dataVal!)
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                var jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(dataVal!, options: NSJSONReadingOptions.MutableContainers, error: &error) as! NSDictionary
                
                let workflowTasksChildren = jsonResult["children"] as! NSDictionary
                
                let workflowTaskChildrenDict = workflowTasksChildren as! [String:NSDictionary]
                
                for (key,value) in workflowTaskChildrenDict {
                    let task = Task(taskName: key, fromNSDictionary: value)
                    if (task.state != "Finished") {
                        taskArray.append(task)
                    }
                }
            }
        } else {
            mprintln("Couldn't retrieve workflow tasks")
        }
        hideMessages()
        return taskArray
    }
    
    func refreshTask(task : Task) -> Task? {
        if (!areServicesAvailable()) {
            return task
        }
        
        mprintln("Refreshing task \(task.path) ...")

        let jahiaWorkflowTasksURL : NSURL = NSURL(string: jahiaWatcherSettings.jcrApiUrl() + "/default/en/paths\(task.path!)?includeFullChildren&resolveReferences")!
        
        let request = NSMutableURLRequest(URL: jahiaWorkflowTasksURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error retrieving updated task!")
            } else {
                writeDataToFile("task-\(task.identifier).json", data: dataVal!)
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                var jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(dataVal!, options: NSJSONReadingOptions.MutableContainers, error: &error) as! NSDictionary
                
                hideMessages()
                return Task(taskName: task.name!, fromNSDictionary: jsonResult)
                
            }
        } else {
            mprintln("Couldn't retrieve task")
        }
        hideMessages()
        return nil
    }
    
    func getTaskActions(task : Task) -> Task {
        if (!areServicesAvailable()) {
            return task
        }
        mprintln("Retrieving task actions...")

        let jahiaTaskActionsURL : NSURL = NSURL(string: jahiaWatcherSettings.taskActionsUrl(task.path!))!
        
        let request = NSMutableURLRequest(URL: jahiaTaskActionsURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var openTaskCount = 0;
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error retrieving task actions!")
            } else {
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                var jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(dataVal!, options: NSJSONReadingOptions.MutableContainers, error: &error) as! NSDictionary
                
                if let previewUrl = jsonResult["preview-url"] as? String {
                    task.previewUrl = previewUrl
                }
                if let possibleActions = jsonResult["possibleActions"] as? [NSDictionary] {
                    var nextActions = [TaskAction]()
                    for possibleAction in possibleActions {
                        let taskAction = TaskAction()
                        taskAction.displayName = possibleAction["displayName"] as? String
                        taskAction.name = possibleAction["name"] as? String
                        taskAction.finalOutcome = possibleAction["finalOutcome"] as? String
                        nextActions.append(taskAction)
                    }
                    task.nextActions = nextActions
                } else {
                    task.nextActions = nil
                }
            }
        } else {
            mprintln("Couldn't retrieve task actions")
        }
        
        hideMessages()
        return task
    }
    
    func performTaskAction(task: Task, actionName : String, finalOutcome : String?) -> Bool {
        var result = false
        mprintln("Sending task action \(actionName) with outcome \(finalOutcome) to Jahia server...")
        
        let jahiaTaskActionsURL : NSURL = NSURL(string: jahiaWatcherSettings.taskActionsUrl(task.path!))!
        let request = NSMutableURLRequest(URL: jahiaTaskActionsURL)
        let requestString : String = "action=\(actionName)" + ((finalOutcome != nil) ? "&finalOutcome=\(finalOutcome!)" : "");
        let postData = NSMutableData()
        postData.appendData(requestString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
        
        request.HTTPMethod = "POST"
        request.setValue(NSString(format: "%lu", postData.length) as String, forHTTPHeaderField: "Content-Length")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = postData
        request.timeoutInterval = 4
        
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode == 200) {
                mprintln("Action sent successfully.")
                result = true
            }
        } else {
            mprintln("Action sending failed")
        }
        hideMessages()
        return result
    }
    
    func getLatestPosts() -> [Post] {
        var posts = [Post]()
        if (!areServicesAvailable()) {
            return posts
        }
        mprintln("Retrieving latest posts...")
        
        let jahiaLatestPostsURL : NSURL = NSURL(string: jahiaWatcherSettings.jcrApiUrl() + "/live/en/query")!
        
        let request = NSMutableURLRequest(URL: jahiaLatestPostsURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        let requestString : String = "{\"query\" : \"select * from [jnt:post] as p order by p.[jcr:created] desc\", \"limit\": 20, \"offset\":0 }";
        let postData = NSMutableData()
        postData.appendData(requestString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
        
        request.HTTPMethod = "POST"
        request.setValue(NSString(format: "%lu", postData.length) as String, forHTTPHeaderField: "Content-Length")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = postData
        request.timeoutInterval = 10
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var openTaskCount = 0;
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error retrieving latest posts!")
            } else {
                writeDataToFile("latest-posts.json", data: dataVal!)
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                var jsonResult = NSJSONSerialization.JSONObjectWithData(dataVal!, options: NSJSONReadingOptions.MutableContainers, error: &error) as! [NSDictionary]

                for postDict in jsonResult {
                    let post = Post(fromNSDictionary: postDict)
                    posts.append(post)
                }
                
            }
        } else {
            mprintln("Couldn't retrieve latest posts!")
        }
        hideMessages()
        return posts
        
    }
    
    func refreshPost(post : Post) -> Post? {
        if (!areServicesAvailable()) {
            return post
        }
        mprintln("Refreshing post \(post.path!) ...")
        
        let jahiaGetPostURL : NSURL = NSURL(string: jahiaWatcherSettings.jcrApiUrl() + "/live/en/paths\(post.path!)?includeFullChildren&resolveReferences")!
        
        let request = NSMutableURLRequest(URL: jahiaGetPostURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData
        
        request.HTTPMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var openTaskCount = 0;
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 200) {
                mprintln("Error retrieving post \(post.path)")
            } else {
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                var jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(dataVal!, options: NSJSONReadingOptions.MutableContainers, error: &error) as! NSDictionary
                
                hideMessages()
                return Post(fromNSDictionary: jsonResult)
                
            }
        } else {
            mprintln("Couldn't retrieve update for post \(post.path)")
        }
        hideMessages()
        return nil
        
    }
    
    func jsonEscaping(input : String) -> String {
        var s : String = input
        s = s.stringByReplacingOccurrencesOfString("\"",withString:"\\\"",options:NSStringCompareOptions.CaseInsensitiveSearch, range:Range<String.Index>(start: s.startIndex, end: s.endIndex))
        s = s.stringByReplacingOccurrencesOfString("/",withString:"\\/", options:NSStringCompareOptions.CaseInsensitiveSearch, range:Range<String.Index>(start: s.startIndex, end: s.endIndex))
        s = s.stringByReplacingOccurrencesOfString("\n",withString:"\\n", options:NSStringCompareOptions.CaseInsensitiveSearch, range:Range<String.Index>(start: s.startIndex, end: s.endIndex))
        s = s.stringByReplacingOccurrencesOfString("\r",withString:"\\r", options:NSStringCompareOptions.CaseInsensitiveSearch, range:Range<String.Index>(start: s.startIndex, end: s.endIndex))
        s = s.stringByReplacingOccurrencesOfString("\t",withString:"\\t", options:NSStringCompareOptions.CaseInsensitiveSearch, range:Range<String.Index>(start: s.startIndex, end: s.endIndex))
        return s
    }
    
    func replyToPost(post : Post, title : String?, body : String?) -> Post? {
        if (!areServicesAvailable()) {
            return post
        }
        mprintln("Replying to post \(post.path!) ...")
        
        let regex = NSRegularExpression(
            pattern: "[^0-9a-zA-Z]",
            options: NSRegularExpressionOptions.CaseInsensitive,
            error: nil)!
        
        let range = NSMakeRange(0, count(title!))
        let newNodeName : String = regex.stringByReplacingMatchesInString(title!,
            options: NSMatchingOptions.allZeros,
            range:range ,
            withTemplate: "")
        
        let jahiaReplyPostURL : NSURL = NSURL(string: jahiaWatcherSettings.contextUrl() + "/modules" + post.parentUri! + "/children/" + newNodeName)!
        
        let request = NSMutableURLRequest(URL: jahiaReplyPostURL)
        request.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringLocalAndRemoteCacheData

        let requestString : String = "{\"type\" : \"jnt:post\", \"properties\": { \"jcr:title\" : { \"value\" : \"\(jsonEscaping(title!))\" }, \"content\" : { \"value\" : \"\(jsonEscaping(body!))\" } } }";
        mprintln("PUT \(jahiaReplyPostURL)")
        mprintln("payload=\(requestString)")
        let postData = NSMutableData()
        postData.appendData(requestString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!)
        
        request.HTTPMethod = "PUT"
        request.setValue(NSString(format: "%lu", postData.length) as String, forHTTPHeaderField: "Content-Length")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.HTTPBody = postData
        
        request.addValue("application/json,application/hal+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        var openTaskCount = 0;
        var response: NSURLResponse?
        var error: NSError?
        var dataVal: NSData? =  NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error:&error)
        var err: NSError
        if let httpResponse = response as? NSHTTPURLResponse {
            if (httpResponse.statusCode != 201) {
                mprintln("Error creating child post under\(post.path) statusCode=\(httpResponse.statusCode)")
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                mprintln("result=\(datastring)")
            } else {
                var datastring = NSString(data: dataVal!, encoding: NSUTF8StringEncoding)
                var jsonResult: NSDictionary = NSJSONSerialization.JSONObjectWithData(dataVal!, options: NSJSONReadingOptions.MutableContainers, error: &error) as! NSDictionary
                
                hideMessages()
                return Post(fromNSDictionary: jsonResult)
                
            }
        } else {
            mprintln("Couldn't retrieve update for post \(post.path)")
        }
        hideMessages()
        return nil
    }
    
    class func stripHTML(input : String) -> String {
        var output = input.stringByReplacingOccurrencesOfString("<[^>]+>", withString: "", options: .RegularExpressionSearch, range: nil)
        output = output.stringByReplacingOccurrencesOfString("&nbsp;", withString: " ")
        output = output.stringByReplacingOccurrencesOfString("&quote;", withString: "'")
        output = output.stringByReplacingOccurrencesOfString("&rsquo;", withString: "'")
        output = output.stringByReplacingOccurrencesOfString("&#39;", withString: "'")
        output = output.stringByReplacingOccurrencesOfString("&amp;", withString: "&")
        return output
    }
    
    class func getShortDate(date : NSDate) -> String {
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.ShortStyle
        formatter.timeStyle = .ShortStyle
        
        let dateString = formatter.stringFromDate(date)
        return dateString
    }
    
    class func getRelativeTime(date : NSDate) -> String {
        return date.relativeTime;
    }
    
    class func getStringPropertyValue(properties : NSDictionary, propertyName : String) -> String? {
        let property = properties[propertyName] as? NSDictionary
        if let realProperty = property {
            return realProperty["value"] as? String
        } else {
            return nil;
        }
    }

    class func getDatePropertyValue(properties : NSDictionary, propertyName : String) -> NSDate? {
        let property = properties[propertyName] as? NSDictionary
        if let realProperty = property {
            return realProperty["value"] as? NSDate
        } else {
            return nil;
        }
    }

    class func getStringArrayPropertyValues(properties : NSDictionary, propertyName : String) -> [String]? {
        let property = properties[propertyName] as? NSDictionary
        if let realProperty = property {
            return realProperty["value"] as? [String]
        } else {
            return nil;
        }
    }
    
    class func matchesForRegexInText(regex: String!, text: String!) -> [String] {
        
        let re = NSRegularExpression(pattern: regex, options: nil, error: nil)!
        let matches = re.matchesInString(text, options: nil, range: NSMakeRange(0, count(text)))
        
        var result = [String]()
        
        for match in matches as! [NSTextCheckingResult] {
            // range at index 0: full match
            // range at index 1: first capture group
            for groupNumber : Int in 0...match.numberOfRanges-1 {
                let substring = (text as NSString).substringWithRange(match.rangeAtIndex(groupNumber))
                result.append(substring)
            }
        }
        return result
    }
    
    class func capitalizeFirstLetter(input : String?) -> String? {
        var result = input
        if let realInput = input {
            result!.replaceRange(result!.startIndex...result!.startIndex, with: String(result![result!.startIndex]).capitalizedString)
        }
        return result
    }
    
    class func condenseWhitespace(string: String) -> String {
        let components = string.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).filter({!isEmpty($0)})
        return join(" ", components)
    }
    
}