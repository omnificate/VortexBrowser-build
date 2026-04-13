#pragma once
#include <simd/simd.h>

namespace Vortex {

struct Color {
    simd_float4 vec;
    
    Color() : vec(simd_make_float4(0, 0, 0, 1)) {}
    Color(float r, float g, float b, float a = 1.0f) 
        : vec(simd_make_float4(r, g, b, a)) {}
    explicit Color(simd_float4 v) : vec(v) {}
    
    float r() const { return vec[0]; }
    float g() const { return vec[1]; }
    float b() const { return vec[2]; }
    float a() const { return vec[3]; }
    
    Color blend(const Color& other, float t) const {
        return Color(simd_mix(vec, other.vec, simd_make_float4(t, t, t, t)));
    }
};

} // namespace Vortex
