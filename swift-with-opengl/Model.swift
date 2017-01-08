//
//  ObjLoader.swift
//  swift-with-opengl
//
//  Created by tohrinagi on 2017/01/08.
//  Copyright © 2017 tohrinagi. All rights reserved.
//

import GLKit
import OpenGLES

class Model {
    var vertices: [GLfloat] = []
    var uvs: [GLfloat] = []
    var normals: [GLfloat] = []

    func loadObj(file: String) -> Bool {
        do {
            var tmp_vertices: [GLfloat] = []
            var tmp_uvs: [GLfloat]      = []
            var tmp_normals: [GLfloat]  = []
            var vertexIndices: [Int]    = []
            var uvIndices: [Int]        = []
            var normalIndices: [Int]    = []
            
            let dataURL = URL(fileURLWithPath: file)
            let data = try String(contentsOf: dataURL, encoding: String.Encoding.utf8)
            
            data.enumerateLines { (line, _ stop) -> Void in
                print(line)
                let item: [String] = line.components(separatedBy: " ")
                print(item)
                
                switch item[0] {
                case "v":
                    for i in 1...3 {
                        tmp_vertices.append(Float(item[i])!)
                    }
                    break
                case "vt":
                    for i in 1...2 {
                        tmp_uvs.append(Float(item[i])!)
                    }
                    break
                case "vn":
                    for i in 1...3 {
                        tmp_normals.append(Float(item[i])!)
                    }
                    break
                case "f":
                    for i in 1...3 {
                        
                        let value: [String] = item[i].components(separatedBy: "/")
                        if value.count != 3 {
                            print("File can't be read by our simple parser : ( Try exporting with other optionsn")
                        }
                        vertexIndices.append(Int(value[0])!)
                        uvIndices.append(Int(value[1])!)
                        normalIndices.append(Int(value[2])!)
                    }
                    break
                default:
                    break
                }
            }
            for vertexIndex in vertexIndices {
                for index in 0..<3 {
                    self.vertices.append(tmp_vertices[(vertexIndex-1)*3+index])
                }
            }
            for uvIndex in uvIndices {
                for index in 0..<2 {
                    self.uvs.append(tmp_uvs[(uvIndex-1)*2+index])
                }
            }
            for normalIndex in normalIndices {
                for index in 0..<3 {
                    self.normals.append(tmp_normals[(normalIndex-1)*3+index])
                }
            }
            return true
        } catch {
            print("Failed to read the file.")
            return false
        }
    }
}
