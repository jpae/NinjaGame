import SpriteKit

func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func - (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
    return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
    func sqrt(a: CGFloat) -> CGFloat {
    return CGFloat(sqrtf(Float(a)))
    }
#endif

extension CGPoint {
    func length() -> CGFloat {
        return sqrt(x*x + y*y)
    }
    
    func normalized() -> CGPoint {
        if length() == 0 {
            return self
        }
        return self / length()
    }
    
    func distance(pointB : CGPoint) -> CGFloat {
        let x_diff = (x - pointB.x) * (x - pointB.x)
        let y_diff = (y - pointB.y) * (y - pointB.y)
        return sqrt(x_diff + y_diff)
    }
}

struct PhysicsCategory {
    static let None      : UInt32 = 0
    static let All       : UInt32 = UInt32.max
    static let Monster   : UInt32 = 0b1       // 1
    static let Projectile: UInt32 = 0b10      // 2
    static let Ground    : UInt32 = 0b11      // 3
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    let MAX_POWER : CGFloat = 400.0
    let MAX_DRAW : CGFloat = 200.0
    
    var controller : GameViewController!
    var ninjagame : NinjaGame!
    
    let player = SKSpriteNode(imageNamed: "player")
    
    var degreeLabel : SKLabelNode?
    var powerLabel : SKLabelNode?
    
    var touchBegan : CGPoint?
    var touchEnd : CGPoint?
    var pathToDraw : CGMutablePath?
    var lineNode : SKShapeNode?
    
    var monstersKilled : Int = 0
    
    
    override func didMoveToView(view: SKView) {
        var bgTexture = SKTexture(imageNamed: "background.png")
        ninjagame = NinjaGame()
        controller.gameUpdate(ninjagame)
        
        //var bgImage = SKSpriteNode(texture: bgTexture)
        //TODO: Parallax scrolling, larger background to show projectile flying
        // Maybe start with moving the screen so the projectile is in the center
        
        //TODO: Add a physics body to the floor of the background
        var bgImage = SKSpriteNode(texture: bgTexture, size: size)
        bgImage.position = CGPointMake(size.width/2, size.height/2)
        
        addChild(bgImage)
        
        player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.18)
        addChild(player)
        
        physicsWorld.gravity = CGVectorMake(0, -2.0)
        physicsWorld.contactDelegate = self
        
        runAction(SKAction.repeatActionForever(
            SKAction.sequence([
                SKAction.runBlock(addMonster),
                SKAction.waitForDuration(1.0)
                ])
        ))
        
        /*let square = CGSize(width: size.width, height: size.height * 0.2)
        sprite.physicsBody = SKPhysicsBody(rectangleOfSize: square)
        sprite.physicsBody.dynamic = false */
    }
    
    func random() -> CGFloat {
        return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
    }
    
    func random(#min: CGFloat, max: CGFloat) -> CGFloat {
        return random() * (max - min) + min
    }
    
    func addMonster() {
        // Create sprite
        let monster = SKSpriteNode(imageNamed: "monster")
        
        monster.physicsBody = SKPhysicsBody(rectangleOfSize: monster.size) // 1
        monster.physicsBody?.dynamic = true // 2
        monster.physicsBody?.categoryBitMask = PhysicsCategory.Monster // 3
        monster.physicsBody?.contactTestBitMask = PhysicsCategory.Projectile // 4
        monster.physicsBody?.collisionBitMask = PhysicsCategory.None // 5
        
        // Determine where to spawn the monster along the Y axis
        let actualY = random(min: size.height * 0.25 + monster.size.height/2, max: size.height - monster.size.height/2)
        
        // Position the monster slightly off-screen along the right edge,
        // and along a random position along the Y axis as calculated above
        monster.position = CGPoint(x: size.width + monster.size.width/2, y: actualY)
        
        // Add the monster to the scene
        addChild(monster)
        
        // Determine speed of the monster
        let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
        
        // Create the actions
        let actionMove = SKAction.moveTo(CGPoint(x: -monster.size.width/2, y: actualY), duration: NSTimeInterval(actualDuration))
        let actionMoveDone = SKAction.removeFromParent()
        monster.runAction(SKAction.sequence([actionMove, actionMoveDone]))
        
    }
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        let touch = touches.anyObject() as UITouch
        touchBegan = touch.locationInNode(self)
        
        powerLabel = SKLabelNode(fontNamed: "Arial")
        degreeLabel = SKLabelNode(fontNamed: "Arial")
        
        powerLabel!.fontSize = 20
        degreeLabel!.fontSize = 20
        powerLabel!.fontColor = SKColor.purpleColor()
        degreeLabel!.fontColor = SKColor.purpleColor()
        
        
        degreeLabel!.position = touchBegan!
        powerLabel!.position = touchBegan!
        
        
        pathToDraw = CGPathCreateMutable()
        CGPathMoveToPoint(pathToDraw, nil, touchBegan!.x, touchBegan!.y)
        CGPathAddLineToPoint(pathToDraw, nil, touchBegan!.x, touchBegan!.y)
        
        lineNode = SKShapeNode()
        lineNode!.path = pathToDraw
        lineNode!.strokeColor = SKColor.redColor()
        lineNode!.zPosition = 1.0

        self.addChild(lineNode!)
        self.addChild(powerLabel!)
        self.addChild(degreeLabel!)
        
    }
    
    override func touchesMoved(touches: NSSet, withEvent event: UIEvent) {
        let touch = touches.anyObject() as UITouch
        let touchCurrent = touch.locationInNode(self)
        
        let offset = touchCurrent - touchBegan!
        
        pathToDraw = CGPathCreateMutable()
        CGPathMoveToPoint(pathToDraw, nil, touchBegan!.x, touchBegan!.y)
        
        let distance = touchCurrent.distance(touchBegan!)
        
        // Fix angle so its respects to the X axis not the Y
        var angle = atan2(Double(-offset.y), Double(-offset.x))
        angle = (angle > 0 ? angle : (2*M_PI + angle)) * 360 / (2*M_PI)
        degreeLabel!.text = String(format:"%.2f", angle) + "\u{00B0}"
        
        if distance <= MAX_DRAW {
            CGPathAddLineToPoint(pathToDraw, nil, touchCurrent.x, touchCurrent.y)
            powerLabel!.text = String(format:"%.2f", Double(distance) / Double(2.0))
            powerLabel!.position = touchCurrent
        }
        else {
            let direction = offset.normalized()
            let endPoint = CGPointMake(touchBegan!.x + direction.x * MAX_DRAW, touchBegan!.y + direction.y * MAX_DRAW)
            CGPathAddLineToPoint(pathToDraw, nil, endPoint.x, endPoint.y)
            
            powerLabel!.position = endPoint
            powerLabel!.text = String(format:"%.2f", Double(100.0))
            
        }

        lineNode!.path = pathToDraw
    }

    
    override func touchesEnded(touches: NSSet, withEvent event: UIEvent) {
        // 1 - Choose one of the touches to work with
        let touch = touches.anyObject() as UITouch
        touchEnd = touch.locationInNode(self)
        
        lineNode?.removeFromParent()
        powerLabel?.removeFromParent()
        degreeLabel?.removeFromParent()
        
        // 2 - Set up initial location of projectile
        let projectile = SKSpriteNode(imageNamed: "projectile")
        
        projectile.position = player.position
        
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.Projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.Monster
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.None
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        
        // 3 - Determine offset of location to projectile
        let offset = touchBegan! - touchEnd!
    
        
        // 5 - OK to add now - you've double checked position
        addChild(projectile)
        
        // 6 - Get the direction of where to shoot
        let direction = offset.normalized()
        let distance = touchEnd!.distance(touchBegan!)
        
        var power = 0.0
        // Determine the power of the shot.
        // power / 100 = % ratio for MAX_POWER
        if distance < MAX_DRAW {
            power = Double(distance) / 100.0 * Double(MAX_POWER)
        }
        else {
            power = Double(MAX_DRAW) / 100.0 * Double(MAX_POWER)
        }

        
        projectile.physicsBody?.applyForce(CGVectorMake(CGFloat(power) * direction.x, CGFloat(power) * direction.y))
        let rotateAction = SKAction.rotateByAngle(1000.0, duration: 10)
        projectile.runAction(rotateAction)
        
    }
    
    func projectileDidCollideWithGround(projectile:SKSpriteNode, ground:SKSpriteNode) {
        projectile.removeFromParent()
    }
    
    func projectileDidCollideWithMonster(projectile:SKSpriteNode, monster:SKSpriteNode) {
        projectile.removeFromParent()
        monster.removeFromParent()
        
        ninjagame.increaseScore()
        controller.gameUpdate(ninjagame)
    }
    
    func didBeginContact(contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        if contact.bodyA.categoryBitMask > contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        // 2
        if ((firstBody.categoryBitMask & PhysicsCategory.Projectile != 0) &&
            (secondBody.categoryBitMask & PhysicsCategory.Monster != 0)) {
                projectileDidCollideWithMonster(firstBody.node as SKSpriteNode, monster: secondBody.node as SKSpriteNode)
        }
        
    }
}