//
//  GameViewController.swift
//  swift-with-opengl
//
//  Created by tohrinagi on 2017/01/02.
//  Copyright © 2017 tohrinagi. All rights reserved.
//

import GLKit
import OpenGLES

func BUFFER_OFFSET(_ i: Int) -> UnsafeRawPointer? {
    return UnsafeRawPointer(bitPattern: i)
}

class GameViewController: GLKViewController {

    var program: GLuint = 0
    
    var camera: Camera = Camera()

    var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity
    var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
    var rotation: Float = 0.0

    var vertexArray: GLuint = 0
    var vertexBuffer: GLuint = 0
    var uvBuffer: GLuint = 0
    var textureBuffer: GLuint = 0

    var uniformMatrix: GLint = 0
    
    var context: EAGLContext? = nil
    var effect: GLKBaseEffect? = nil
    var preTouchPoint = CGPoint(x: 0, y: 0)

    deinit {
        self.tearDownGL()

        if EAGLContext.current() === self.context {
            EAGLContext.setCurrent(nil)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // EAGLContextを受取、GLKViewに渡す
        self.context = EAGLContext(api: .openGLES3)

        if !(self.context != nil) {
            print("Failed to create ES context")
        }

        let view = self.view as! GLKView
        view.context = self.context!
        // デプスバッファは24bit
        view.drawableDepthFormat = .format24

        camera.setAspect(width: Float(self.view.bounds.size.width), height: Float(self.view.bounds.size.height))
        self.setupGL()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

        if self.isViewLoaded && (self.view.window != nil) {
            self.view = nil

            self.tearDownGL()

            if EAGLContext.current() === self.context {
                EAGLContext.setCurrent(nil)
            }
            self.context = nil
        }
    }

    func setupGL() {
        EAGLContext.setCurrent(self.context)
        if !self.loadShaders() {
            print("failer load shaders")
            return
        }
        
        let bmpFilePath = Bundle.main.path(forResource: "dice", ofType: "bmp")!
        textureBuffer = self.loadBMP(bmpFilePath)
        if textureBuffer == 0 {
            print("failer textures")
            return
        }
        
        // カメラのほうを向いていない法線の三角形をカリングします。
        glEnable(GLenum(GL_CULL_FACE))
        // デプステストを有効にする
        glEnable(GLenum(GL_DEPTH_TEST))
        // 前のものよりもカメラに近ければ、フラグメントを受け入れる
        glDepthFunc(GLenum(GL_LESS))
        
        uniformMatrix = glGetUniformLocation(program, "modelViewPerspectiveMatrix")
        
        // VAOを初めに作る必要がある
        glGenVertexArrays(1, &vertexArray)
        glBindVertexArray(vertexArray)
        
        // バッファを1つ作り、vertexbufferに結果IDを入れます。
        glGenBuffers(1, &vertexBuffer)
        
        // 次のコマンドは'vertexbuffer'バッファについてです。
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        
        // 頂点をOpenGLに渡します。
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLfloat>.size * gQubeVertexData.count), &gQubeVertexData, GLenum(GL_STATIC_DRAW))
        
        // UVバッファも同様に作成
        glGenBuffers(1, &uvBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), uvBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLfloat>.size * gUVBufferData.count), &gUVBufferData, GLenum(GL_STATIC_DRAW))
    }

    func tearDownGL() {
        EAGLContext.setCurrent(self.context)

        glDeleteBuffers(1, &vertexBuffer)
        // 頂点配列オブジェクトを破棄
        glDeleteVertexArrays(1, &vertexArray)

        self.effect = nil

        if program != 0 {
            glDeleteProgram(program)
            program = 0
        }
    }

    func update() {
        camera.update()
        
        let modelMatrix = GLKMatrix4Identity
        
        modelViewProjectionMatrix = GLKMatrix4Multiply(camera.projectionMatrix, camera.viewMatrix)
        modelViewProjectionMatrix = GLKMatrix4Multiply(modelViewProjectionMatrix, modelMatrix)
    }

    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        glClearColor(0.65, 0.65, 0.65, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        
        // 最初の属性バッファ：頂点
        glEnableVertexAttribArray(0)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        glVertexAttribPointer(
            0,                  // 属性0：0に特に理由はありません。しかし、シェーダ内のlayoutとあわせないといけません。
            3,                  // サイズ
            GLenum(GL_FLOAT),           // タイプ
            GLboolean(GL_FALSE),           // 正規化？
            0,                  // ストライド
            nil            // 配列バッファオフセット
        )
        
        // 次の属性バッファ：UV
        glEnableVertexAttribArray(1)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), uvBuffer)
        glVertexAttribPointer(
            1,                  // 属性1：1に特に理由はありません。しかし、シェーダ内のlayoutとあわせないといけません。
            2,                  // サイズ
            GLenum(GL_FLOAT),           // タイプ
            GLboolean(GL_FALSE),           // 正規化？
            0,                  // ストライド
            nil            // 配列バッファオフセット
        )
        
        // シェーダー設定
        glUseProgram(program)
        
        withUnsafePointer(to: &modelViewProjectionMatrix, {
            $0.withMemoryRebound(to: Float.self, capacity: 16, {
                glUniformMatrix4fv(uniformMatrix, 1, 0, $0)
            })
        })
        
        // 三角形を描きます！
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 12*3); // 頂点0から始まります。合計3つの頂点で１つの三角形です。
        
        glDisableVertexAttribArray(0)
    }
    @IBAction func dragGesture(_ sender: UIPanGestureRecognizer) {
        // ドラッグ操作はカメラの上下左右移動に使用する
        let speed: CGFloat = 0.01
        switch sender.state {
        case .began:
            preTouchPoint = sender.translation(in: self.view)
            break
        case .changed:
            let move = sender.translation(in: self.view)
            let vec = CGPoint(x: move.x - preTouchPoint.x, y: move.y - preTouchPoint.y)
            camera.verticalAngle = camera.verticalAngle + Float(vec.y * speed)
            camera.horizontalAngle = camera.horizontalAngle + Float(vec.x * speed)
            preTouchPoint = move
            break
        default:
            break
        }
    }
    @IBAction func PinchGesture(_ sender: UIPinchGestureRecognizer) {
        let moveDistance: CGFloat = 0.2
        // ピンチ動作は、カメラからターゲットへの距離移動に使用する
        camera.distance = camera.distance - Float((sender.scale - 1.0) * moveDistance)
        print("scale: \n\(sender.scale)")
    }

    // (mark): -  OpenGL ES 2 shader compilation

    func loadShaders() -> Bool {
        var vertShader: GLuint = 0
        var fragShader: GLuint = 0
        var vertShaderPathname: String
        var fragShaderPathname: String

        // シェーダーオブジェクトに関連付ける空のIDを発行
        program = glCreateProgram()

        // シェーダーを作成、読み込みしコンパイル
        // 頂点シェーダ
        vertShaderPathname = Bundle.main.path(forResource: "Shader", ofType: "vsh")!
        if self.compileShader(&vertShader, type: GLenum(GL_VERTEX_SHADER), file: vertShaderPathname) == false {
            print("Failed to compile vertex shader")
            return false
        }

        // フラグメントシェーダ
        fragShaderPathname = Bundle.main.path(forResource: "Shader", ofType: "fsh")!
        if !self.compileShader(&fragShader, type: GLenum(GL_FRAGMENT_SHADER), file: fragShaderPathname) {
            print("Failed to compile fragment shader")
            return false
        }

        // 参照IDと頂点シェーダを紐付け
        glAttachShader(program, vertShader)

        // 参照IDとフラグメントシェーダを紐付け
        glAttachShader(program, fragShader)

        // シェーダーオブジェクトをリンク
        if !self.linkProgram(program) {
            print("Failed to link program: \(program)")

            if vertShader != 0 {
                glDeleteShader(vertShader)
                vertShader = 0
            }
            if fragShader != 0 {
                glDeleteShader(fragShader)
                fragShader = 0
            }
            if program != 0 {
                glDeleteProgram(program)
                program = 0
            }

            return false
        }

        // リンクしたシェーダーオブジェクトはこの時点で不要になるため削除
        if vertShader != 0 {
            glDetachShader(program, vertShader)
            glDeleteShader(vertShader)
        }
        if fragShader != 0 {
            glDetachShader(program, fragShader)
            glDeleteShader(fragShader)
        }

        return true
    }

    func compileShader(_ shader: inout GLuint, type: GLenum, file: String) -> Bool {
        var status: GLint = 0
        var source: UnsafePointer<Int8>
        do {
            source = try NSString(contentsOfFile: file, encoding: String.Encoding.utf8.rawValue).utf8String!
        } catch {
            print("Failed to load vertex shader")
            return false
        }
        var castSource: UnsafePointer<GLchar>? = UnsafePointer<GLchar>(source)

        shader = glCreateShader(type)
        glShaderSource(shader, 1, &castSource, nil)
        glCompileShader(shader)

        //#if defined(DEBUG)
        //        var logLength: GLint = 0
        //        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        //        if logLength > 0 {
        //            var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
        //            glGetShaderInfoLog(shader, logLength, &logLength, log)
        //            NSLog("Shader compile log: \n%s", log)
        //            free(log)
        //        }
        //#endif

        glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &status)
        if status == 0 {
            glDeleteShader(shader)
            return false
        }
        return true
    }

    func linkProgram(_ prog: GLuint) -> Bool {
        var status: GLint = 0
        glLinkProgram(prog)

        //#if defined(DEBUG)
        //        var logLength: GLint = 0
        //        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        //        if logLength > 0 {
        //            var log = UnsafeMutablePointer<GLchar>(malloc(Int(logLength)))
        //            glGetShaderInfoLog(shader, logLength, &logLength, log)
        //            NSLog("Shader compile log: \n%s", log)
        //            free(log)
        //        }
        //#endif

        glGetProgramiv(prog, GLenum(GL_LINK_STATUS), &status)
        if status == 0 {
            return false
        }

        return true
    }

    func validateProgram(_ prog: GLuint) -> Bool {
        var logLength: GLsizei = 0
        var status: GLint = 0

        glValidateProgram(prog)
        glGetProgramiv(prog, GLenum(GL_INFO_LOG_LENGTH), &logLength)
        if logLength > 0 {
            var log: [GLchar] = [GLchar](repeating: 0, count: Int(logLength))
            glGetProgramInfoLog(prog, logLength, &logLength, &log)
            print("Program validate log: \n\(log)")
        }

        glGetProgramiv(prog, GLenum(GL_VALIDATE_STATUS), &status)
        var returnVal = true
        if status == 0 {
            returnVal = false
        }
        return returnVal
    }
    
    func loadBMP(_ file: String) -> GLuint {
        do {
            let dataURL = URL(fileURLWithPath: file)
            // ファイル読み込み
            let binaryData = try Data(contentsOf: dataURL, options: [])
            
            // ヘッダバイナリ
            var header = [UInt8](repeating: 0, count: 54)
            binaryData.copyBytes(to: &header, count: 54)
            
            // BM のマジックナンバーチェック
            if header[0] != 0x42  || header[1] != 0x4d {
                print("This isnt a BMP file.")
                return 0
            }
            // 各ヘッダの値を取得
            var dataPos    = Int(header[0x0A]) | (Int(header[0x0B]) << 8)
            var imageSize  = Int(header[0x22]) | (Int(header[0x23]) << 8)
            let width      = Int(header[0x12]) | (Int(header[0x13]) << 8)
            let height     = Int(header[0x16]) | (Int(header[0x17]) << 8)
            print("dataPos:\(dataPos) imageSize:\(imageSize) width:\(width) height:\(height)")
            // エラーの値を修正
            if imageSize==0 { imageSize = width*height*3 }
            if dataPos==0 { dataPos=54 }
            
            var body = [UInt8](repeating:0, count: imageSize)
            binaryData.copyBytes(to: &body, from: 54..<54+imageSize)
            
            // ひとつのOpenGLテクスチャを作ります。
            var texture: GLuint = 0
            glGenTextures(1, &texture)
            
            // 新たに作られたテクスチャを"バインド"します。つまりここから後のテクスチャ関数はこのテクスチャを変更します。
            glBindTexture(GLenum(GL_TEXTURE_2D), texture)
            
            // OpenGLに画像を渡します。
            // BMPの並びはBGRのため、本来引数７にはGL_BGRを渡す必要があるがES3ではないっぽい
            glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGB, Int32(width), Int32(height), 0, GLenum(GL_RGB), GLenum(GL_UNSIGNED_BYTE), body)
            
            // 画像を拡大(MAGnifying)するときは線形(LINEAR)フィルタリングを使います。
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
            // 画像を縮小(MINifying)するとき、線形(LINEAR)フィルタした、二つのミップマップを線形(LINEARYLY)に混ぜたものを使います。
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR_MIPMAP_LINEAR)
            // 次のようにしてミップマップを作ります。
            glGenerateMipmap(GLenum(GL_TEXTURE_2D))
            
            return texture
            
        } catch {
            print("Failed to read the file.")
            return 0
        }
    }
}

var gQubeVertexData: [GLfloat] = [
    -1.0, -1.0, -1.0, // 三角形1:開始
    -1.0, -1.0, 1.0,
    -1.0, 1.0, 1.0, // 三角形1:終了
    1.0, 1.0, -1.0, // 三角形2:開始
    -1.0, -1.0, -1.0,
    -1.0, 1.0, -1.0, // 三角形2:終了
    1.0, -1.0, 1.0,
    -1.0, -1.0, -1.0,
    1.0, -1.0, -1.0,
    1.0, 1.0, -1.0,
    1.0, -1.0, -1.0,
    -1.0, -1.0, -1.0,
    -1.0, -1.0, -1.0,
    -1.0, 1.0, 1.0,
    -1.0, 1.0, -1.0,
    1.0, -1.0, 1.0,
    -1.0, -1.0, 1.0,
    -1.0, -1.0, -1.0,
    -1.0, 1.0, 1.0,
    -1.0, -1.0, 1.0,
    1.0, -1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, -1.0, -1.0,
    1.0, 1.0, -1.0,
    1.0, -1.0, -1.0,
    1.0, 1.0, 1.0,
    1.0, -1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, -1.0,
    -1.0, 1.0, -1.0,
    1.0, 1.0, 1.0,
    -1.0, 1.0, -1.0,
    -1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    -1.0, 1.0, 1.0,
    1.0, -1.0, 1.0
]

// UV
var gUVBufferData: [GLfloat] = [
    0.000059, 1.0-0.000004,
    0.000103, 1.0-0.336048,
    0.335973, 1.0-0.335903,
    1.000023, 1.0-0.000013,
    0.667979, 1.0-0.335851,
    0.999958, 1.0-0.336064,
    0.667979, 1.0-0.335851,
    0.336024, 1.0-0.671877,
    0.667969, 1.0-0.671889,
    1.000023, 1.0-0.000013,
    0.668104, 1.0-0.000013,
    0.667979, 1.0-0.335851,
    0.000059, 1.0-0.000004,
    0.335973, 1.0-0.335903,
    0.336098, 1.0-0.000071,
    0.667979, 1.0-0.335851,
    0.335973, 1.0-0.335903,
    0.336024, 1.0-0.671877,
    1.000004, 1.0-0.671847,
    0.999958, 1.0-0.336064,
    0.667979, 1.0-0.335851,
    0.668104, 1.0-0.000013,
    0.335973, 1.0-0.335903,
    0.667979, 1.0-0.335851,
    0.335973, 1.0-0.335903,
    0.668104, 1.0-0.000013,
    0.336098, 1.0-0.000071,
    0.000103, 1.0-0.336048,
    0.000004, 1.0-0.671870,
    0.336024, 1.0-0.671877,
    0.000103, 1.0-0.336048,
    0.336024, 1.0-0.671877,
    0.335973, 1.0-0.335903,
    0.667969, 1.0-0.671889,
    1.000004, 1.0-0.671847,
    0.667979, 1.0-0.335851
]
