//
//  NumberTileGame.swift
//  swift-2048
//
//  Created by Austin Zheng on 6/3/14.
//  Copyright (c) 2014 Austin Zheng. Released under the terms of the MIT license.
//

import UIKit

class GameBoardViewController : UIViewController, GameModelProtocol {
    let dimension: Int
    let threshold: Int

    let boardWidth: CGFloat = 375.0
    let thinPadding: CGFloat = 3.0
    let thickPadding: CGFloat = 6.0
    let viewPadding: CGFloat = 10.0
    let verticalViewOffset: CGFloat = 0.0

    var gameBoard: GameboardView?
    var gameModel: GameModel?
    var scoreView: ScoreViewProtocol?

    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    init(dimension d: Int, threshold t: Int) {
        dimension = d > 2 ? d : 2
        threshold = t > 8 ? t : 8
        super.init(nibName: nil, bundle: nil)
        gameModel = GameModel(dimension: dimension, threshold: threshold, delegate: self)
        view.backgroundColor = UIColor.white
        setupSwipeGestures()
    }

    func setupSwipeGestures() {
        let upSwipe = UISwipeGestureRecognizer(target: self, action: #selector(GameBoardViewController.swipeUp(_:)))
        upSwipe.numberOfTouchesRequired = 1
        upSwipe.direction = UISwipeGestureRecognizerDirection.up
        view.addGestureRecognizer(upSwipe)

        let downSwipe = UISwipeGestureRecognizer(target: self, action: #selector(GameBoardViewController.swipeDown(_:)))
        downSwipe.numberOfTouchesRequired = 1
        downSwipe.direction = UISwipeGestureRecognizerDirection.down
        view.addGestureRecognizer(downSwipe)

        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(GameBoardViewController.swipeLeft(_:)))
        leftSwipe.numberOfTouchesRequired = 1
        leftSwipe.direction = UISwipeGestureRecognizerDirection.left
        view.addGestureRecognizer(leftSwipe)

        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(GameBoardViewController.swipeRight(_:)))
        rightSwipe.numberOfTouchesRequired = 1
        rightSwipe.direction = UISwipeGestureRecognizerDirection.right
        view.addGestureRecognizer(rightSwipe)
    }
    
    /**
     一个尾调闭包, 居然能有这么多不同的写法, 在所有语言都在为了格式统一努力的今天, 不明白 swift 的用意.
     */
    @objc(up:)
    func swipeUp(_ r: UIGestureRecognizer!) {
        /**
         guard 在这里, 和 if 没有什么区别. 更好用的地方是
         guard let x = sth, y = sth where x > y else {
            return
         }
         如果, 上面的判断都符合的话, 才会 fallthrough 到下面的代码, 如果有一项不符合的话, 就会进入 else. 也就是说, 如果想要用 if 进行 guard 的效果, 其实是要首先定义 x, y, 然后进行 where 里面的逻辑判断.
         其实提前定义, 然后判断, 本质上来说, 也是很清晰的代码, 但是 guard 这种防卫编程专门用来做这件事, 要清晰地太多了.
         where 引入, 是在 switch case 中引入的.
         */
        guard let m = gameModel else {
            return
        }
        m.queueMove(direction: MoveDirection.up) { (changed:Bool) in
            if changed { self.followUp() }
        }
    }
    
    @objc(down:)
    func swipeDown(_ r: UIGestureRecognizer!) {
        guard let m = gameModel else {
            return
        }
        m.queueMove(direction: MoveDirection.down) { (changed) in
            if changed { self.followUp()}
        }
        
    }
    
    @objc(left:)
    func swipeLeft(_ r: UIGestureRecognizer!) {
        guard let m = gameModel else {
            return
        }
        m.queueMove(direction: MoveDirection.left, onCompletion: { (changed: Bool) -> Void in
            if changed { self.followUp() }
        })
    }
    
    @objc(right:)
    func swipeRight(_ r: UIGestureRecognizer!) {
        guard let m = gameModel else {
            return
        }
        m.queueMove(direction: MoveDirection.right,
                    onCompletion: { (changed: Bool) -> () in
                        if changed {
                            self.followUp()
                        }
        })
    }

    override func viewDidLoad()  {
        super.viewDidLoad()
        setupGame()
    }

    func setupGame() {
        
        let viewHeight = view.bounds.size.height
        let viewWidth = view.bounds.size.width
        
        // 个人其实是不太喜欢这种 nest method, 这样就让函数越写越长了, 这一点应该在重构的第二版里面有所涉及, 可以去看看那里作者怎么写的.
        // 在第一版的重构里面, 闭包的概念应该用的没有那么普遍.
        func leftPositionForCenterView(_ v: UIView) -> CGFloat {
            let viewWidth = v.bounds.size.width
            let tentativeX = 0.5*(viewWidth - viewWidth)
            return tentativeX >= 0 ? tentativeX : 0
        }
        func yPositionForViewAtPosition(_ order: Int, views: [UIView]) -> CGFloat {
            assert(views.count > 0)
            assert(order >= 0 && order < views.count)
            //      let viewHeight = views[order].bounds.size.height
            let totalHeight = CGFloat(views.count - 1)*viewPadding + views.map({ $0.bounds.size.height }).reduce(verticalViewOffset, { $0 + $1 })
            let viewsTop = 0.5*(viewHeight - totalHeight) >= 0 ? 0.5*(viewHeight - totalHeight) : 0
            
            // Not sure how to slice an array yet
            var acc: CGFloat = 0
            for i in 0..<order {
                acc += viewPadding + views[i].bounds.size.height
            }
            return viewsTop + acc
        }
        
        let scoreView = ScoreView(backgroundColor: UIColor.black,
          textColor: UIColor.white,
          font: UIFont(name: "HelveticaNeue-Bold", size: 16.0) ?? UIFont.systemFont(ofSize: 16.0),
          radius: 6)
        scoreView.score = 0

        // Create the gameboard
        let padding: CGFloat = dimension > 5 ? thinPadding : thickPadding
        let v1 = boardWidth - padding*(CGFloat(dimension + 1))
        let width: CGFloat = CGFloat(floorf(CFloat(v1)))/CGFloat(dimension)
        let gameboard = GameboardView(dimension: dimension,
          tileWidth: width,
          tilePadding: padding,
          cornerRadius: 6,
          backgroundColor: UIColor.black,
          foregroundColor: UIColor.darkGray)

        // Set up the frames
        let views = [scoreView, gameboard]

        var f = scoreView.frame
        f.origin.x = leftPositionForCenterView(scoreView)
        f.origin.y = yPositionForViewAtPosition(0, views: views)
        scoreView.frame = f

        f = gameboard.frame
        f.origin.x = leftPositionForCenterView(gameboard)
        f.origin.y = yPositionForViewAtPosition(1, views: views)
        gameboard.frame = f


        // Add to game state
        view.addSubview(gameboard)
        gameBoard = gameboard
        view.addSubview(scoreView)
        self.scoreView = scoreView

        assert(gameModel != nil)
        let m = gameModel!
        m.insertTileAtRandomLocation(withValue: 2)
        m.insertTileAtRandomLocation(withValue: 2)
    }

    // Misc
    func followUp() {
    assert(gameModel != nil)
    let m = gameModel!
    let (userWon, _) = m.userHasWon()
    if userWon {
      // TODO: alert delegate we won
      let alertView = UIAlertView()
      alertView.title = "Victory"
      alertView.message = "You won!"
      alertView.addButton(withTitle: "Cancel")
      alertView.show()
      // TODO: At this point we should stall the game until the user taps 'New Game' (which hasn't been implemented yet)
      return
    }

    // Now, insert more tiles
    let randomVal = Int(arc4random_uniform(10))
    m.insertTileAtRandomLocation(withValue: randomVal == 1 ? 4 : 2)

    // At this point, the user may lose
    if m.userHasLost() {
      // TODO: alert delegate we lost
      NSLog("You lost...")
      let alertView = UIAlertView()
      alertView.title = "Defeat"
      alertView.message = "You lost..."
      alertView.addButton(withTitle: "Cancel")
      alertView.show()
    }
    }

    // Protocol
    func scoreChanged(to score: Int) {
    if scoreView == nil {
      return
    }
    let s = scoreView!
    s.scoreChanged(to: score)
    }

    func moveOneTile(from: (Int, Int), to: (Int, Int), value: Int) {
    assert(gameBoard != nil)
    let b = gameBoard!
    b.moveOneTile(from: from, to: to, value: value)
    }

    func moveTwoTiles(from: ((Int, Int), (Int, Int)), to: (Int, Int), value: Int) {
    assert(gameBoard != nil)
    let b = gameBoard!
    b.moveTwoTiles(from: from, to: to, value: value)
    }

    func insertTile(at location: (Int, Int), withValue value: Int) {
    assert(gameBoard != nil)
    let b = gameBoard!
    b.insertTile(at: location, value: value)
        AnyObject
    }
    
}
