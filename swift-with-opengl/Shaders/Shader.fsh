//
//  Shader.fsh
//  swift-with-opengl
//
//  Created by tohrinagi on 2017/01/02.
//  Copyright © 2017 tohrinagi. All rights reserved.
//
#version 300 es

out mediump vec4 flagColor;

void main()
{
    //2.0では下記だが、3.0ではgl_FragColorが廃止のため
    //gl_FragColor = colorVarying;
    flagColor   = vec4(1.0, 0, 0, 1.0);
}
