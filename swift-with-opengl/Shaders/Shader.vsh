//
//  Shader.vsh
//  swift-with-opengl
//
//  Created by tohrinagi on 2017/01/02.
//  Copyright © 2017 tohrinagi. All rights reserved.
//
#version 300 es

#define ATTRIB_POSITION 0

layout (location = ATTRIB_POSITION) in vec3 position;

void main()
{
    gl_Position.xyz = position;
    gl_Position.w = 1.0;
}
