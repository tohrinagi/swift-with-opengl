//
//  Shader.fsh
//  swift-with-opengl
//
//  Created by tohrinagi on 2017/01/02.
//  Copyright © 2017 tohrinagi. All rights reserved.
//
#version 300 es

// 頂点シェーダから書き込まれた色
in lowp vec3 fragmentColor;

out mediump vec4 flagColor;

void main()
{
    flagColor   = vec4(fragmentColor,1.0);
}
