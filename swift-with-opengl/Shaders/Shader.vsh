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

uniform mat4 modelViewPerspectiveMatrix;

void main()
{
    vec4 v = vec4(position, 1);
    gl_Position = modelViewPerspectiveMatrix * v;
}
