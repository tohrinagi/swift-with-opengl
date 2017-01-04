//
//  Shader.fsh
//  swift-with-opengl
//
//  Created by tohrinagi on 2017/01/02.
//  Copyright © 2017 tohrinagi. All rights reserved.
//
#version 300 es

// 頂点シェーダからの値を書き込みます
in lowp vec2 uv;

out mediump vec4 flagColor;

// すべてのメッシュで一定の値
uniform sampler2D textureSampler;

void main()
{
    flagColor = texture(textureSampler, uv);
}
