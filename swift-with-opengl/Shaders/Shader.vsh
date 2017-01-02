//
//  Shader.vsh
//  swift-with-opengl
//
//  Created by tohrinagi on 2017/01/02.
//  Copyright © 2017 tohrinagi. All rights reserved.
//
#version 300 es

#define ATTRIB_POSITION 0
#define ATTRIB_NORMAL 1

// 2.0 では attribute だったが、3.0では廃止になった。
// またlocation も3.0からシェーダー内で書けるようになった。
layout (location = ATTRIB_POSITION) in vec4 position;
layout (location = ATTRIB_NORMAL) in vec3 normal;

// 2.0ではvaryingだったが、3.0では廃止のためoutへ
out lowp vec4 colorVarying; //varying は fsh に渡す値

uniform mat4 modelViewProjectionMatrix; // uniform はプログラムから渡すプリミティブ毎の値
uniform mat3 normalMatrix;

void main()
{
    vec3 eyeNormal = normalize(normalMatrix * normal);
    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
    vec4 diffuseColor = vec4(0.4, 0.4, 1.0, 1.0);
    
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
                 
    colorVarying = diffuseColor * nDotVP;
    
    // gl_Position はビルドインのattrivute(頂点ごとに変化する)変数。必ず値をいれること。
    gl_Position = modelViewProjectionMatrix * position;
}
