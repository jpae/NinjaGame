import UIKit
import SpriteKit

class GameViewController: UIViewController {
    
    @IBOutlet weak var totalKills: UILabel!
    
    var scene : GameScene!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        scene = GameScene(size: view.bounds.size)
        scene.controller = self

        let skView = view as SKView
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.ignoresSiblingOrder = true
        scene.scaleMode = .ResizeFill
        skView.presentScene(scene)
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func gameUpdate(ninjagame: NinjaGame) {
        totalKills.text = "\(ninjagame.score)"
    }
}