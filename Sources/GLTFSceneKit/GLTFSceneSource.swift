//
//  GLTFSceneSource.swift
//  GLTFSceneKit
//
//  Created by magicien on 2017/08/17.
//  Copyright © 2017 DarkHorse. All rights reserved.
//

import SceneKit

@objcMembers
public class GLTFSceneSource : SCNSceneSource {
    private var loader: GLTFUnarchiver?
    private var error: Error?
    
    public override init() {
        super.init()
    }
    
    public convenience init(path: String, options: [SCNSceneSource.LoadingOption : Any]? = nil, extensions: [String:Codable.Type]? = nil) throws {
        self.init()
        
        let loader = try GLTFUnarchiver(path: path, extensions: extensions)
        self.loader = loader
    }
    
    public override convenience init(url: URL, options: [SCNSceneSource.LoadingOption : Any]? = nil) {
        self.init(url: url, options: options, extensions: nil)
    }
    
    public convenience init(url: URL, options: [SCNSceneSource.LoadingOption : Any]?, extensions: [String:Codable.Type]?) {
        self.init()
        
        do {
            self.loader = try GLTFUnarchiver(url: url, extensions: extensions)
        } catch {
            self.error = error
        }
    }
    
    public override convenience init(data: Data, options: [SCNSceneSource.LoadingOption : Any]? = nil) {
        self.init()
        do {
            self.loader = try GLTFUnarchiver(data: data)
        } catch {
            self.error = error
        }
    }
    
    public convenience init(named name: String, options: [SCNSceneSource.LoadingOption : Any]? = nil, extensions: [String:Codable.Type]? = nil) throws {
        let filePath = Bundle.main.path(forResource: name, ofType: nil)
        guard let path = filePath else {
            throw URLError(.fileDoesNotExist)
        }
        try self.init(path: path, options: options, extensions: extensions)
    }
    
    public override func scene(options: [SCNSceneSource.LoadingOption : Any]? = nil) throws -> SCNScene {
        guard let loader = self.loader else {
            if let error = self.error {
                throw error
            }
            throw GLTFUnarchiveError.Unknown("loader is not initialized")
        }
        let scene = try loader.loadScene()
        #if SEEMS_TO_HAVE_SKINNER_VECTOR_TYPE_BUG
            let sceneData = NSKeyedArchiver.archivedData(withRootObject: scene)
            let source = SCNSceneSource(data: sceneData, options: nil)!
            let newScene = source.scene(options: nil)!
            return newScene
        #else
            return scene
        #endif
    }
    
    public func exportScene(scene:SCNScene, to:URL) throws {
        if to.pathExtension == "json" {
            guard let loader = self.loader else {
                if let error = self.error {
                    throw error
                }
                throw GLTFUnarchiveError.Unknown("loader is not initialized")
            }
            loader.exportScene(to:to)
            loader.exportTextures(textureDirectory:to.deletingLastPathComponent())
        } else {
            scene.write(to: to, options: [ SCNSceneSource.LoadingOption.checkConsistency.rawValue : true] as [String : Any], delegate: nil)
            if to.pathExtension == "scn" {
                loader!.exportTextures(textureDirectory:to.deletingLastPathComponent())
            }
        }
    }
    
    public static func applyAnimation(url:URL, loadedScene:SCNScene) throws {
        var animationScene:SCNScene
        
        if url.pathExtension == "glb" {
            let animationSceneSource = GLTFSceneSource.init(url: url, options: [.convertToYUp: true])
            animationScene = try animationSceneSource.scene()
        } else {
            let animationSceneSource = SCNSceneSource.init(url: url, options: [.convertToYUp: true])
            animationScene = try animationSceneSource!.scene()
        }
        
        //Remove existing animations
        loadedScene.rootNode.removeAllAnimations()
        loadedScene.rootNode.enumerateChildNodes { (child, stop) in
            child.removeAllAnimations()
        }
        let animsOnNodes = false
        if animsOnNodes {
            //Find the node in the other scene with the same name and bind the animation to it
            animationScene.rootNode.enumerateChildNodes { (child, stop) in
                if !child.animationKeys.isEmpty {
                    
                    let hopeNode = loadedScene.rootNode.childNodes[0].childNode(
                        withName: child.name!,
                        recursively: true
                    )
                    
                    if hopeNode != nil {
                        print("Found " + child.name!)
                        for animKey in child.animationKeys {
                            let animation = child.animation(forKey: animKey)!
                            hopeNode!.addAnimation(animation, forKey: animKey);
                            let animationPlayer = hopeNode!.animationPlayer(forKey:animKey)
                            animationPlayer!.play()
                        }
                    } else {
                        print("Coudn't find " + child.name!)
                    }
                }
            }
        } else {
           
            let animationGroup = CAAnimationGroup()
            var duration = 0.0
            animationScene.rootNode.enumerateChildNodes { (child, stop) in
                if !child.animationKeys.isEmpty {
                    
                    var hopeNode = loadedScene.rootNode.childNode(
                        withName: "Hips",
                        recursively: true
                    )
                    
                    if loadedScene.rootNode.name == child.name! {
                        hopeNode = loadedScene.rootNode
                    }
                    
                    if hopeNode != nil {
                        for animKey in child.animationKeys {
                            
                            let animation:CAAnimationGroup =  child.animation(forKey: animKey)! as! CAAnimationGroup
                            print("Animation for " + child.name! + String(": ") + animKey)
                            
                            //Add each animation to the Hips node - works in scn, only one anim exports
//                            hopeNode!.addAnimation(animation, forKey: animKey);
                            
                            //Make a group with the anims and add at the end - does not play
                            if animationGroup.animations == nil {
                                animationGroup.animations = [animation]
                            } else {
                                animationGroup.animations?.append(animation)
                            }
                            if animation.duration > duration {
                                duration = animation.duration
                            }
                        }
                    } else {
                        print("Coudn't find " + child.name!)
                    }
                }
            }
            //Attempt to bind the animations to a single node
            let hipsNode = loadedScene.rootNode.childNode(
                withName: "Hips",
                recursively: true
            )
            //hipsNode!.removeAllAnimations()
            loadedScene.rootNode.childNodes[0].eulerAngles = SCNVector3Make(-.pi/2,0, 0);
//            loadedScene.rootNode.childNodes[0].scale = SCNVector3Make(0.1,0.1,0.1);
            animationGroup.duration = duration
            animationGroup.repeatCount = .infinity
            hipsNode!.addAnimation(animationGroup, forKey: "HopeAnimations")
            let animationPlayer = hipsNode!.animationPlayer(forKey: "HopeAnimations")
            animationPlayer!.play()
        }
    }
}

