//
//  GameViewController.swift
//  GameSample
//
//  Created by magicien on 2017/08/17.
//  Copyright © 2017年 DarkHorse. All rights reserved.
//

import SceneKit
import QuartzCore
import GLTFSceneKit

class GameViewController: NSViewController, SCNSceneExportDelegate {
    
    @IBOutlet weak var gameView: GameView!
    @IBOutlet weak var openFileButton: NSButton!
    @IBOutlet weak var animationSelect: NSPopUpButton!
    
    var animationURLs: [URL] = []
    let defaultCameraTag: Int = 99
    
    var sceneSource: GLTFSceneSource = GLTFSceneSource()
    
    override func awakeFromNib(){
        super.awakeFromNib()
        
        self.animationURLs.append(Bundle.main.url(forResource: "Dancing Maraschino Step", withExtension: "glb")!)
        self.animationURLs.append(Bundle.main.url(forResource: "JazzDancingNoSkin", withExtension: "glb")!)
        self.animationURLs.append(Bundle.main.url(forResource: "Capoeira", withExtension: "dae")!)
        
        var scene: SCNScene
        do {
            let sceneSource = try GLTFSceneSource(named: "art.scnassets/GlassVase/Wayfair-GlassVase-BCHH2364.glb")
            scene = try sceneSource.scene()
        } catch {
            print("\(error.localizedDescription)")
            return
        }
        
        self.setScene(scene)
        
        self.gameView!.autoenablesDefaultLighting = true
        
        // allows the user to manipulate the camera
        self.gameView!.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        self.gameView!.showsStatistics = true
        
        // configure the view
        self.gameView!.backgroundColor = NSColor.gray
        
        self.gameView!.addObserver(self, forKeyPath: "pointOfView", options: [.new], context: nil)
        
        self.gameView!.delegate = self
        
    }
    
    func setScene(_ scene: SCNScene) {
        
        // set the scene to the view
        self.gameView!.scene = scene
        
        // set the camera menu
        self.animationSelect.menu?.removeAllItems()
        if self.animationURLs.count > 0 {
            self.animationSelect.removeAllItems()
            for url in self.animationURLs {
                self.animationSelect.menu?.addItem(withTitle: url.lastPathComponent, action: nil, keyEquivalent: "")
            }
        }
        
        //to give nice reflections :)
        scene.lightingEnvironment.contents = "art.scnassets/shinyRoom.jpg"
        scene.lightingEnvironment.intensity = 2;
        
        let defaultCameraItem = NSMenuItem(title: "SCNViewFreeCamera", action: nil, keyEquivalent: "")
        defaultCameraItem.tag = self.defaultCameraTag
        defaultCameraItem.isEnabled = false
        self.animationSelect.menu?.addItem(defaultCameraItem)
        
        self.animationSelect.autoenablesItems = false
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        //        if keyPath == "pointOfView", let change = change {
        //            if let cameraNode = change[.newKey] as? SCNNode {
        //                // It must use the main thread to change the UI.
        //                DispatchQueue.main.async {
        //                    if let index = self.animationURLs.index(of: cameraNode) {
        //                        self.animationSelect.selectItem(at: index)
        //                    } else {
        //                        self.animationSelect.selectItem(withTag: self.defaultCameraTag)
        //                    }
        //                }
        //            }
        //        }
    }
    
    func showSavePanel() -> URL? {
        let savePanel = NSSavePanel()
        //            savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save your 3D file"
        savePanel.message = "Choose a folder and a name to store the 3D file."
        savePanel.nameFieldLabel = "3D file name:"
        
        let response = savePanel.runModal()
        return response == .OK ? savePanel.url : nil
    }
    
    @IBAction func saveFileButtonClicked(_ sender: Any) {
        guard let url = showSavePanel() else { return }
        do {
            try self.sceneSource.exportScene(scene: self.gameView!.scene!, to: url)
        } catch {
            print("Unable to Write Image Data to Disk")
        }
        
        
    }
    
    @IBAction func openFileButtonClicked(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["gltf", "glb", "vrm"]
        openPanel.message = "Choose glTF file"
        openPanel.begin { (response) in
            if response == .OK {
                guard let url = openPanel.url else { return }
                do {
                    self.sceneSource = GLTFSceneSource.init(url: url)
                    let scene = try self.sceneSource.scene()
                    self.setScene(scene)
                } catch {
                    print("\(error.localizedDescription)")
                }
            }
        }
    }
    
    @IBAction func selectAnimation(_ sender: Any) {
        do {
            let index = self.animationSelect.indexOfSelectedItem
            var url = self.animationURLs[index]
            let loadedScene = self.gameView.scene
            
            //Load file
            try GLTFSceneSource.applyAnimation(url:url, loadedScene:loadedScene!)
        } catch {
            
        }
    }
    
}

extension GameViewController: SCNSceneRendererDelegate {
  func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
    self.gameView.scene?.rootNode.updateVRMSpringBones(time: time)
  }
}
