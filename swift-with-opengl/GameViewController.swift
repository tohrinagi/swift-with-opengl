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

let uniformModelviewprojectionMatrix = 0
let uniformNormalMatrix = 1
var uniforms = [GLint](repeating: 0, count: 2)

class GameViewController: GLKViewController {

    var program: GLuint = 0

    var modelViewProjectionMatrix: GLKMatrix4 = GLKMatrix4Identity
    var normalMatrix: GLKMatrix3 = GLKMatrix3Identity
    var rotation: Float = 0.0

    var vertexArray: GLuint = 0
    var vertexBuffer: GLuint = 0

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

        // デプスバッファ更新ON（更新しないと陰影消去できない）
        glEnable(GLenum(GL_DEPTH_TEST))

        // 下記はもともとglGenVertexArraysOESだったOES等はES2.0のベンダー名。
        // ES3.0では標準化しているので外す
        
        // n(1)個の頂点配列オブジェクトを作成しvertexArrayにハンドルを渡す
        glGenVertexArrays(1, &vertexArray)
        // 頂点配列オブジェクトをバインドし利用できるようにする
        glBindVertexArray(vertexArray)

        // n(1)個のバッファオブジェクトを作成する
        glGenBuffers(1, &vertexBuffer)
        // バッファオブジェクトをターゲットにバインドして利用できるようにする
        // 第１引数にはGL_ARRAY_BUFFER(頂点バッファ)かGL_ELEMENT_ARRAY_BUFFER(頂点インデックス)が入る
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vertexBuffer)
        // バッファオブジェクトにデータ(頂点データ)を転送する
        // GL_STATIC_DRAWの箇所はデータの使い方を指定し効率化に役立てる
        glBufferData(GLenum(GL_ARRAY_BUFFER), GLsizeiptr(MemoryLayout<GLfloat>.size * gCubeVertexData.count), &gCubeVertexData, GLenum(GL_STATIC_DRAW))

        // 指定した属性を有効にする(ここではPosition)
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
            // 属性とバッファオブジェクトを関連付ける
        glVertexAttribPointer(GLuint(GLKVertexAttrib.position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(0))
        // 指定した属性を有効にする(ここではNormal)
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.normal.rawValue))
            // 属性とバッファオブジェクトを関連付ける
        glVertexAttribPointer(GLuint(GLKVertexAttrib.normal.rawValue), 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 24, BUFFER_OFFSET(12))

        glBindVertexArray(0)
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

    // MARK: - GLKView and GLKViewController delegate methods

    func update() {
        // 画面サイズからカメラ行列を作成
        let aspect = fabsf(Float(self.view.bounds.size.width / self.view.bounds.size.height))
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0), aspect, 0.1, 100.0)

        // ローカル座標を回転させる行列
        var baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, -4.0)
        baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, rotation, 0.0, 1.0, 0.0)

        // Compute the model view matrix for the object rendered with ES2
        var modelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, 1.5)
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, rotation, 1.0, 1.0, 1.0)
        modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix)

        normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), nil)
        modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix)

        rotation += Float(self.timeSinceLastUpdate * 0.5)
    }

    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        glClearColor(0.65, 0.65, 0.65, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))

        //VertexArrayをバインド
        glBindVertexArray(vertexArray)

        // シェーダー設定
        glUseProgram(program)

        // uniform に値設定
        withUnsafePointer(to: &modelViewProjectionMatrix, {
            $0.withMemoryRebound(to: Float.self, capacity: 16, {
                glUniformMatrix4fv(uniforms[uniformModelviewprojectionMatrix], 1, 0, $0)
            })
        })
        
        withUnsafePointer(to: &normalMatrix, {
            $0.withMemoryRebound(to: Float.self, capacity: 9, {
                glUniformMatrix3fv(uniforms[uniformNormalMatrix], 1, 0, $0)
            })
        })
        
        //描画
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 36)
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

        // 属性を関連付ける
        // リンクする前に実行する必要がある
        // 3.0では廃止で、シェーダー内でレイアウトをするようになった
        //glBindAttribLocation(program, GLuint(GLKVertexAttrib.Position.rawValue), "position")
        //glBindAttribLocation(program, GLuint(GLKVertexAttrib.Normal.rawValue), "normal")

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

        // シェーダーから変数ハンドルを貰う
        uniforms[uniformModelviewprojectionMatrix] = glGetUniformLocation(program, "modelViewProjectionMatrix")
        uniforms[uniformNormalMatrix] = glGetUniformLocation(program, "normalMatrix")

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

var gCubeVertexData: [GLfloat] = [
    // Data layout for each line below is:
    // positionX, positionY, positionZ,     normalX, normalY, normalZ,
  0.5, -0.5, -0.5, 1.0, 0.0, 0.0,
  0.5, 0.5, -0.5, 1.0, 0.0, 0.0,
  0.5, -0.5, 0.5, 1.0, 0.0, 0.0,
  0.5, -0.5, 0.5, 1.0, 0.0, 0.0,
  0.5, 0.5, -0.5, 1.0, 0.0, 0.0,
  0.5, 0.5, 0.5, 1.0, 0.0, 0.0,

  0.5, 0.5, -0.5, 0.0, 1.0, 0.0,
  -0.5, 0.5, -0.5, 0.0, 1.0, 0.0,
  0.5, 0.5, 0.5, 0.0, 1.0, 0.0,
  0.5, 0.5, 0.5, 0.0, 1.0, 0.0,
  -0.5, 0.5, -0.5, 0.0, 1.0, 0.0,
  -0.5, 0.5, 0.5, 0.0, 1.0, 0.0,

  -0.5, 0.5, -0.5, -1.0, 0.0, 0.0,
  -0.5, -0.5, -0.5, -1.0, 0.0, 0.0,
  -0.5, 0.5, 0.5, -1.0, 0.0, 0.0,
  -0.5, 0.5, 0.5, -1.0, 0.0, 0.0,
  -0.5, -0.5, -0.5, -1.0, 0.0, 0.0,
  -0.5, -0.5, 0.5, -1.0, 0.0, 0.0,

  -0.5, -0.5, -0.5, 0.0, -1.0, 0.0,
  0.5, -0.5, -0.5, 0.0, -1.0, 0.0,
  -0.5, -0.5, 0.5, 0.0, -1.0, 0.0,
  -0.5, -0.5, 0.5, 0.0, -1.0, 0.0,
  0.5, -0.5, -0.5, 0.0, -1.0, 0.0,
  0.5, -0.5, 0.5, 0.0, -1.0, 0.0,

  0.5, 0.5, 0.5, 0.0, 0.0, 1.0,
  -0.5, 0.5, 0.5, 0.0, 0.0, 1.0,
  0.5, -0.5, 0.5, 0.0, 0.0, 1.0,
  0.5, -0.5, 0.5, 0.0, 0.0, 1.0,
  -0.5, 0.5, 0.5, 0.0, 0.0, 1.0,
  -0.5, -0.5, 0.5, 0.0, 0.0, 1.0,

  0.5, -0.5, -0.5, 0.0, 0.0, -1.0,
  -0.5, -0.5, -0.5, 0.0, 0.0, -1.0,
  0.5, 0.5, -0.5, 0.0, 0.0, -1.0,
  0.5, 0.5, -0.5, 0.0, 0.0, -1.0,
  -0.5, -0.5, -0.5, 0.0, 0.0, -1.0,
  -0.5, 0.5, -0.5, 0.0, 0.0, -1.0
]
