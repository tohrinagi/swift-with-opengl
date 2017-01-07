//
//  Camera.swift
//  swift-with-opengl
//
//  Created by tohrinagi on 2017/01/07.
//  Copyright © 2017 tohrinagi. All rights reserved.
//

import GLKit
import OpenGLES

class Camera {

    var projectionMatrix: GLKMatrix4 = GLKMatrix4Identity
    var viewMatrix: GLKMatrix4 = GLKMatrix4Identity
    var aspect: Float = 0
    let fovy: Float = GLKMathDegreesToRadians(65.0)
    var distance: Float = 10
    var verticalAngle: Float = 0
    var horizontalAngle: Float = 3.14
    
    func setAspect( width: Float, height: Float) {
        aspect = fabsf(Float(width / height))
    }
    
    func update() {
        // 画面サイズから射影行列を作成
        projectionMatrix = GLKMatrix4MakePerspective(fovy, aspect, 0.1, 100.0)
        
        // 向きベクトルを作成
        let direction = GLKVector3(v: (cos(verticalAngle)*sin(horizontalAngle),
                                  sin(verticalAngle),
                                  cos(verticalAngle)*cos(horizontalAngle)))
        let position = GLKVector3(v: ( direction.x * distance,
                                       direction.y * distance,
                                       direction.z * distance))
        
        // 右方向ベクトルを作成
        let right = GLKVector3(v:
            (sin(horizontalAngle - 3.14/2.0),
            0,
            cos(horizontalAngle - 3.14/2.0)))
        
        // 上方向ベクトルを作成
        let up = GLKVector3CrossProduct(right, direction)
        
        viewMatrix = GLKMatrix4MakeLookAt(position.x, position.y, position.z, 0, 0, 0, up.x, up.y, up.z)
    }
}
