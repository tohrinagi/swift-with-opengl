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

    var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity
    var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
    var rotation: Float = 0.0

    var vertexArray: GLuint = 0
    var vertexBuffer: GLuint = 0
    var colorBuffer: GLuint = 0

    var uniformMatrix: GLint = 0
    
    var context: EAGLContext? = nil
    var effect: GLKBaseEffect? = nil

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
        
        // カラーバッファも同様に作成
        glGenBuffers(1, &colorBuffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), colorBuffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLfloat>.size * gColorBufferData.count), &gColorBufferData, GLenum(GL_STATIC_DRAW))
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
        
        // 画面サイズから射影行列を作成
        let aspect = fabsf(Float(self.view.bounds.size.width / self.view.bounds.size.height))
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0), aspect, 0.1, 100.0)
    
        let viewMatrix = GLKMatrix4MakeLookAt(4, 3, -3, 0, 0, 0, 0, 1, 0)
        
        let modelMatrix = GLKMatrix4Identity
        
        modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, viewMatrix)
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
        
        // 次の属性バッファ：色
        glEnableVertexAttribArray(1)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), colorBuffer)
        glVertexAttribPointer(
            1,                  // 属性1：1に特に理由はありません。しかし、シェーダ内のlayoutとあわせないといけません。
            3,                  // サイズ
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

// 各頂点に一つの色。これらはランダムに作られました。
var gColorBufferData: [GLfloat] = [
  0.583, 0.771, 0.014,
  0.609, 0.115, 0.436,
  0.327, 0.483, 0.844,
  0.822, 0.569, 0.201,
  0.435, 0.602, 0.223,
  0.310, 0.747, 0.185,
  0.597, 0.770, 0.761,
  0.559, 0.436, 0.730,
  0.359, 0.583, 0.152,
  0.483, 0.596, 0.789,
  0.559, 0.861, 0.639,
  0.195, 0.548, 0.859,
  0.014, 0.184, 0.576,
  0.771, 0.328, 0.970,
  0.406, 0.615, 0.116,
  0.676, 0.977, 0.133,
  0.971, 0.572, 0.833,
  0.140, 0.616, 0.489,
  0.997, 0.513, 0.064,
  0.945, 0.719, 0.592,
  0.543, 0.021, 0.978,
  0.279, 0.317, 0.505,
  0.167, 0.620, 0.077,
  0.347, 0.857, 0.137,
  0.055, 0.953, 0.042,
  0.714, 0.505, 0.345,
  0.783, 0.290, 0.734,
  0.722, 0.645, 0.174,
  0.302, 0.455, 0.848,
  0.225, 0.587, 0.040,
  0.517, 0.713, 0.338,
  0.053, 0.959, 0.120,
  0.393, 0.621, 0.362,
  0.673, 0.211, 0.457,
  0.820, 0.883, 0.371,
  0.982, 0.099, 0.879
]
