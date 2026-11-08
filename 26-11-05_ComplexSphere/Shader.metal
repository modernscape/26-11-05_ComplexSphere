//
//  Shader.metal
//  26-11-05_ComplexSphere
//
//  Created by forest on 2026/11/08.
//

#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

[[visible]]
void myCustomSurfaceShader(realitykit::surface_parameters shader) {
    realitykit::surface::surface_properties ssh = shader.surface();
    // ここでMetalを使ってピクセルカラーや質感を計算
    ssh.set_base_color(half3(0.1, 0.4, 0.8));
}
